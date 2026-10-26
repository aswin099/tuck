using System.Collections.ObjectModel;
using System.ComponentModel;
using System.IO;
using System.Windows;
using System.Windows.Threading;
using Tuck.App.Platform;
using Tuck.App.Views;
using Tuck.Core;

namespace Tuck.App.ViewModels;

public enum StorageStatus
{
    Encrypted,
    /// <summary>The previous file could not be decrypted and was set aside.</summary>
    Recovered,
    /// <summary>Encryption was unavailable, so history is not saved to disk.</summary>
    MemoryOnly,
}

/// <summary>App state and actions: history, popup, paste queue and settings. The Windows twin of AppModel on macOS.</summary>
public sealed class AppController : ObservableObject, IDisposable
{
    public const double ListWidth = 380;
    public const double PreviewWidth = 320;

    private readonly HistoryStore _store;
    private readonly MessageWindow _messages = new();
    private readonly HotkeyManager _hotkeys;
    private readonly DispatcherTimer _pruneTimer = new() { Interval = TimeSpan.FromSeconds(15) };
    private readonly DispatcherTimer _saveTimer = new() { Interval = TimeSpan.FromMilliseconds(400) };
    private readonly string _ownExe = Environment.ProcessPath ?? "";
    private PopupWindow? _popup;
    private SettingsWindow? _settingsWindow;
    private IntPtr _previousWindow;
    private uint _ignoreUpToSequence;

    private string _query = "";
    private ItemViewModel? _selected;
    private bool _isPaused;
    private bool _isCollecting;
    private bool _popupHotkeyOk = true;
    private bool _pasteNextHotkeyOk = true;
    private bool _toggleCollectingHotkeyOk = true;

    public TuckSettings Settings { get; }
    public string DataFolder { get; }
    public string HistoryPath { get; }
    private string SettingsPath => Path.Combine(DataFolder, "settings.json");
    public StorageStatus StorageStatus { get; }
    public string? StorageDetail { get; }

    public ObservableCollection<ItemViewModel> VisibleItems { get; } = [];
    public PasteQueue Queue { get; } = new();

    public AppController()
    {
        DataFolder = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Tuck");
        Directory.CreateDirectory(DataFolder);
        HistoryPath = Path.Combine(DataFolder, "history.tuck");
        Settings = TuckSettings.Load(SettingsPath);

        try
        {
            var cipher = new DpapiCipher();
            cipher.Open(cipher.Seal([1])); // Fails early if DPAPI is unavailable for this account.
            _store = new HistoryStore(Settings.HistoryLimit, HistoryPath, cipher);
            StorageStatus = _store.LoadStatus == LoadStatus.Unreadable ? StorageStatus.Recovered : StorageStatus.Encrypted;
            StorageDetail = _store.MovedAsidePath is { } moved ? Path.GetFileName(moved) : null;
        }
        catch (Exception e) when (e is System.Security.Cryptography.CryptographicException or PlatformNotSupportedException)
        {
            // Without encryption, never fall back to writing plain text.
            _store = new HistoryStore(Settings.HistoryLimit);
            StorageStatus = StorageStatus.MemoryOnly;
            StorageDetail = e.Message;
        }

        _hotkeys = new HotkeyManager(_messages);
    }

    public void Start()
    {
        _messages.ClipboardChanged += () =>
            Application.Current.Dispatcher.BeginInvoke(OnClipboardChanged, DispatcherPriority.Background);
        _messages.HotkeyPressed += OnHotkey;
        RegisterHotkeys();
        Settings.PropertyChanged += OnSettingChanged;
        Settings.IgnoredApps.CollectionChanged += (_, _) => _saveTimer.Start();
        _saveTimer.Tick += (_, _) =>
        {
            _saveTimer.Stop();
            Settings.Save(SettingsPath);
        };
        _pruneTimer.Tick += (_, _) => Prune();
        _pruneTimer.Start();
        Prune();
        Refresh();
    }

    // MARK: State

    public string Query
    {
        get => _query;
        set
        {
            if (!Set(ref _query, value)) return;
            Raise(nameof(HasQuery));
            Refresh();
        }
    }

    public bool HasQuery => !string.IsNullOrEmpty(Query);

    public ItemViewModel? Selected
    {
        get => _selected;
        set => Set(ref _selected, value);
    }

    public bool IsPaused
    {
        get => _isPaused;
        set
        {
            if (Set(ref _isPaused, value)) Raise(nameof(StatusText));
        }
    }

    /// <summary>When on, every new copy is also added to the paste queue.</summary>
    public bool IsCollecting
    {
        get => _isCollecting;
        set
        {
            if (!Set(ref _isCollecting, value)) return;
            RaiseQueue();
        }
    }

    public bool ShowQueueBanner => !Queue.IsEmpty || IsCollecting;
    public int QueueCount => Queue.Count;
    public string QueueTitle
    {
        get
        {
            var items = Queue.Count == 1 ? "1 item" : $"{Queue.Count} items";
            return IsCollecting ? $"Collecting copies · {items} queued" : $"{items} in paste queue";
        }
    }
    public string QueueHint => $"{Settings.PasteNextHotkey} pastes the next one";
    public string StatusText => IsPaused ? "Tuck (paused)" : Queue.IsEmpty ? "Tuck" : $"Tuck · {Queue.Count} queued";

    public bool IsEmpty => VisibleItems.Count == 0;
    public string EmptyTitle => string.IsNullOrEmpty(Query) ? "Nothing copied yet" : "No matches";
    public string EmptyHint => string.IsNullOrEmpty(Query) ? "Copy something and it will show up here." : "";

    public int TotalCount => _store.Items.Count;
    public int PinnedCount => _store.Items.Count(i => i.IsPinned);
    public string SavedItemsText => PinnedCount > 0 ? $"{TotalCount} ({PinnedCount} pinned)" : $"{TotalCount}";

    public bool PopupHotkeyOk { get => _popupHotkeyOk; private set => Set(ref _popupHotkeyOk, value); }
    public bool PasteNextHotkeyOk { get => _pasteNextHotkeyOk; private set => Set(ref _pasteNextHotkeyOk, value); }
    public bool ToggleCollectingHotkeyOk { get => _toggleCollectingHotkeyOk; private set => Set(ref _toggleCollectingHotkeyOk, value); }

    public bool LaunchAtLogin
    {
        get => StartupRegistration.IsEnabled;
        set
        {
            StartupRegistration.Set(value);
            Raise();
        }
    }

    public event Action? QueueChanged;

    // MARK: Recording

    private void OnClipboardChanged()
    {
        var sequence = Native.GetClipboardSequenceNumber();
        if (sequence <= _ignoreUpToSequence || IsPaused) return;

        var path = Native.ProcessPathForWindow(Native.GetClipboardOwner())
            ?? Native.ProcessPathForWindow(Native.GetForegroundWindow());
        if (path is not null && string.Equals(path, _ownExe, StringComparison.OrdinalIgnoreCase)) return;
        var exe = path is null ? null : Path.GetFileName(path);

        var rules = Settings.IgnoreRules;
        if (ClipboardAccess.Read(exe, path) is not { Item: { } item } snapshot) return;
        if (rules.ShouldIgnore(snapshot.Formats, exe, snapshot.HistoryOptOut) || !rules.ShouldRecord(item.Kind)) return;
        Ingest(item);
    }

    private void Ingest(ClipItem item)
    {
        if (item.Kind is ClipKind.Text or ClipKind.Link
            && item.Text is { } text
            && SecretDetector.Detect(text, Settings.DetectRandomTokens) is { } kind)
        {
            switch (Settings.SecretHandling)
            {
                case SecretHandling.Skip:
                    return;
                case SecretHandling.Hide:
                    item.SecretKind = kind;
                    if (Settings.SecretLifetimeMinutes > 0)
                    {
                        item.ExpiresAt = DateTimeOffset.Now.AddMinutes(Settings.SecretLifetimeMinutes);
                    }
                    break;
            }
        }
        var stored = _store.Add(item);
        if (IsCollecting)
        {
            Queue.Enqueue(stored);
            RaiseQueue();
        }
        Refresh();
    }

    private void Prune()
    {
        var maxAge = Settings.RetentionDays > 0 ? TimeSpan.FromDays(Settings.RetentionDays) : (TimeSpan?)null;
        if (_store.Prune(maxAge: maxAge)) Refresh();
    }

    // MARK: Popup

    public double PopupWidth => Settings.ShowPreview ? ListWidth + PreviewWidth + 1 : ListWidth;

    public void TogglePopup()
    {
        if (_popup?.IsVisible == true) HidePopup();
        else ShowPopup();
    }

    public void ShowPopup()
    {
        var foreground = Native.GetForegroundWindow();
        if (_popup is null || foreground != _popup.Handle) _previousWindow = foreground;
        _query = "";
        Raise(nameof(Query));
        Raise(nameof(HasQuery));
        Refresh();
        _popup ??= new PopupWindow(this);
        _popup.ShowAtPreferredPosition(Settings.PopupPosition == PopupPosition.Center);
    }

    public void HidePopup() => _popup?.Hide();

    public void OpenSettings()
    {
        HidePopup();
        if (_settingsWindow is { IsLoaded: true })
        {
            _settingsWindow.Activate();
            return;
        }
        Raise(nameof(SavedItemsText));
        _settingsWindow = new SettingsWindow(this);
        _settingsWindow.Show();
        _settingsWindow.Activate();
    }

    // MARK: Actions

    public void Refresh()
    {
        var keep = Selected?.Id;
        var items = Search.Filter(_store.Items, Query);
        VisibleItems.Clear();
        for (var i = 0; i < items.Count; i++)
        {
            VisibleItems.Add(new ItemViewModel(items[i], i, Queue.PositionOf(items[i])));
        }
        Selected = VisibleItems.FirstOrDefault(v => v.Id == keep) ?? VisibleItems.FirstOrDefault();
        Raise(nameof(IsEmpty));
        Raise(nameof(EmptyTitle));
        Raise(nameof(EmptyHint));
        Raise(nameof(SavedItemsText));
        Raise(nameof(TotalCount));
        Raise(nameof(PinnedCount));
    }

    public void Move(int delta)
    {
        if (VisibleItems.Count == 0) return;
        var current = Selected is null ? 0 : VisibleItems.IndexOf(Selected);
        Selected = VisibleItems[Math.Clamp(current + delta, 0, VisibleItems.Count - 1)];
    }

    public void PasteSelected()
    {
        if (Selected is not null) Paste(Selected.Item);
    }

    public void PasteAt(int index)
    {
        if (index >= 0 && index < VisibleItems.Count) Paste(VisibleItems[index].Item);
    }

    public void Paste(ClipItem item)
    {
        HidePopup();
        if (_previousWindow != IntPtr.Zero && Native.IsWindow(_previousWindow))
        {
            Native.SetForegroundWindow(_previousWindow);
        }
        _ = DeliverAsync(item);
        _store.Touch(item.Id);
        Refresh();
    }

    /// <summary>Puts the item on the clipboard and, if enabled, sends Ctrl+V to the foreground app.</summary>
    private async Task DeliverAsync(ClipItem item)
    {
        if (!ClipboardAccess.Write(item)) return;
        var sequence = Native.GetClipboardSequenceNumber();
        _ignoreUpToSequence = sequence;

        if (Settings.AutoPaste)
        {
            // Keys still held from a shortcut (Ctrl+Alt+V, Ctrl+1) would turn Ctrl+V into
            // a different shortcut, so wait for them to be released first.
            var waited = 0;
            while (Native.AnyModifierDown() && waited < 1000)
            {
                await Task.Delay(20);
                waited += 20;
            }
            await Task.Delay(60);
            Native.SendCtrlV();
        }

        if (item.IsSecret && Settings.ClearAfterSecretPaste)
        {
            // Give the target app time to read the clipboard, then clear it unless
            // something else was copied in the meantime.
            await Task.Delay(1500);
            if (Native.GetClipboardSequenceNumber() == sequence)
            {
                ClipboardAccess.Clear();
                _ignoreUpToSequence = Native.GetClipboardSequenceNumber();
            }
        }
    }

    public void DeleteSelected()
    {
        if (Selected is not { } selected) return;
        var index = VisibleItems.IndexOf(selected);
        _store.Delete(selected.Id);
        Queue.Remove(selected.Id);
        RaiseQueue();
        Refresh();
        if (VisibleItems.Count > 0) Selected = VisibleItems[Math.Min(index, VisibleItems.Count - 1)];
    }

    public void TogglePinSelected()
    {
        if (Selected is null) return;
        _store.TogglePin(Selected.Id);
        Refresh();
    }

    public void ClearHistory()
    {
        _store.ClearUnpinned();
        Refresh();
    }

    /// <summary>Asks before clearing, as it can't be undone.</summary>
    public void ConfirmClearHistory(Window? owner = null)
    {
        const string message = "All items except pinned ones will be deleted. This can't be undone.";
        var result = owner is null
            ? MessageBox.Show(message, "Clear clipboard history?", MessageBoxButton.OKCancel, MessageBoxImage.Warning, MessageBoxResult.Cancel)
            : MessageBox.Show(owner, message, "Clear clipboard history?", MessageBoxButton.OKCancel, MessageBoxImage.Warning, MessageBoxResult.Cancel);
        if (result == MessageBoxResult.OK) ClearHistory();
    }

    // MARK: Paste queue

    public void ToggleQueuedSelected()
    {
        if (Selected is not { } selected) return;
        if (Queue.PositionOf(selected.Item) is not null) Queue.Remove(selected.Id);
        else Queue.Enqueue(selected.Item);
        RaiseQueue();
        Refresh();
    }

    /// <summary>Pastes the front of the queue into the foreground app and removes it.</summary>
    public void PasteNextInQueue()
    {
        if (Queue.Next() is not { } item)
        {
            System.Media.SystemSounds.Beep.Play();
            return;
        }
        RaiseQueue();
        _ = DeliverAsync(item);
        _store.Touch(item.Id);
        Refresh();
    }

    public void ClearQueue()
    {
        Queue.Clear();
        IsCollecting = false;
        RaiseQueue();
        Refresh();
    }

    private void RaiseQueue()
    {
        Raise(nameof(ShowQueueBanner));
        Raise(nameof(QueueCount));
        Raise(nameof(QueueTitle));
        Raise(nameof(StatusText));
        QueueChanged?.Invoke();
    }

    // MARK: Hotkeys and settings

    private void OnHotkey(int id)
    {
        switch ((HotkeyAction)id)
        {
            case HotkeyAction.TogglePopup: TogglePopup(); break;
            case HotkeyAction.PasteNextInQueue: PasteNextInQueue(); break;
            case HotkeyAction.ToggleCollecting: IsCollecting = !IsCollecting; break;
        }
    }

    /// <summary>Pauses global hotkeys while a shortcut is being recorded in Settings.</summary>
    public void SuspendHotkeys() => _hotkeys.Dispose();

    public void ResumeHotkeys() => RegisterHotkeys();

    private void RegisterHotkeys()
    {
        PopupHotkeyOk = _hotkeys.Register(HotkeyAction.TogglePopup, Settings.PopupHotkey);
        PasteNextHotkeyOk = _hotkeys.Register(HotkeyAction.PasteNextInQueue, Settings.PasteNextHotkey);
        ToggleCollectingHotkeyOk = _hotkeys.Register(HotkeyAction.ToggleCollecting, Settings.ToggleCollectingHotkey);
    }

    private void OnSettingChanged(object? sender, PropertyChangedEventArgs e)
    {
        switch (e.PropertyName)
        {
            case nameof(TuckSettings.PopupHotkey):
            case nameof(TuckSettings.PasteNextHotkey):
            case nameof(TuckSettings.ToggleCollectingHotkey):
                RegisterHotkeys();
                Raise(nameof(QueueHint));
                break;
            case nameof(TuckSettings.HistoryLimit):
                _store.SetMaxItems(Settings.HistoryLimit);
                Refresh();
                break;
            case nameof(TuckSettings.RetentionDays):
                Prune();
                break;
            case nameof(TuckSettings.ShowPreview):
                Raise(nameof(PopupWidth));
                break;
        }
        _saveTimer.Stop();
        _saveTimer.Start();
    }

    public void Dispose()
    {
        _pruneTimer.Stop();
        if (_saveTimer.IsEnabled)
        {
            _saveTimer.Stop();
            Settings.Save(SettingsPath);
        }
        _hotkeys.Dispose();
        _messages.Dispose();
    }
}
