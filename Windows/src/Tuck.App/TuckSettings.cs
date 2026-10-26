using System.Collections.ObjectModel;
using System.IO;
using System.Text.Json;
using System.Text.Json.Serialization;
using Tuck.App.ViewModels;
using Tuck.Core;

namespace Tuck.App;

[JsonConverter(typeof(JsonStringEnumConverter<PopupPosition>))]
public enum PopupPosition
{
    Cursor,
    Center,
}

[JsonConverter(typeof(JsonStringEnumConverter<SecretHandling>))]
public enum SecretHandling
{
    Keep,
    Hide,
    Skip,
}

/// <summary>User preferences, saved as JSON in %LOCALAPPDATA%\Tuck\settings.json.</summary>
public sealed class TuckSettings : ObservableObject
{
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web) { WriteIndented = true };

    private string _popupHotkey = "Ctrl+Shift+V";
    private string _pasteNextHotkey = "Ctrl+Alt+V";
    private string _toggleCollectingHotkey = "";
    private bool _autoPaste = true;
    private int _historyLimit = 200;
    private int _retentionDays;
    private bool _recordText = true;
    private bool _recordLinks = true;
    private bool _recordImages = true;
    private bool _recordFiles = true;
    private bool _skipConcealed = true;
    private PopupPosition _popupPosition = PopupPosition.Cursor;
    private bool _showPreview;
    private bool _showMetadata = true;
    private int _rowLines = 2;
    private bool _showKeyHints = true;
    private SecretHandling _secretHandling = SecretHandling.Hide;
    private int _secretLifetimeMinutes = 5;
    private bool _detectRandomTokens = true;
    private bool _clearAfterSecretPaste = true;

    public string PopupHotkey { get => _popupHotkey; set => Set(ref _popupHotkey, value); }
    public string PasteNextHotkey { get => _pasteNextHotkey; set => Set(ref _pasteNextHotkey, value); }
    public string ToggleCollectingHotkey { get => _toggleCollectingHotkey; set => Set(ref _toggleCollectingHotkey, value); }
    public bool AutoPaste { get => _autoPaste; set => Set(ref _autoPaste, value); }
    public int HistoryLimit { get => _historyLimit; set => Set(ref _historyLimit, Math.Max(1, value)); }
    public int RetentionDays { get => _retentionDays; set => Set(ref _retentionDays, Math.Max(0, value)); }
    public bool RecordText { get => _recordText; set => Set(ref _recordText, value); }
    public bool RecordLinks { get => _recordLinks; set => Set(ref _recordLinks, value); }
    public bool RecordImages { get => _recordImages; set => Set(ref _recordImages, value); }
    public bool RecordFiles { get => _recordFiles; set => Set(ref _recordFiles, value); }
    public bool SkipConcealed { get => _skipConcealed; set => Set(ref _skipConcealed, value); }
    public PopupPosition PopupPosition { get => _popupPosition; set => Set(ref _popupPosition, value); }
    public bool ShowPreview { get => _showPreview; set => Set(ref _showPreview, value); }
    public bool ShowMetadata { get => _showMetadata; set => Set(ref _showMetadata, value); }
    public int RowLines { get => _rowLines; set => Set(ref _rowLines, Math.Clamp(value, 1, 3)); }
    public bool ShowKeyHints { get => _showKeyHints; set => Set(ref _showKeyHints, value); }
    public SecretHandling SecretHandling
    {
        get => _secretHandling;
        set
        {
            if (!Set(ref _secretHandling, value)) return;
            Raise(nameof(IsHidingSecrets));
            Raise(nameof(DetectsSecrets));
        }
    }

    [JsonIgnore]
    public bool IsHidingSecrets => SecretHandling == SecretHandling.Hide;
    [JsonIgnore]
    public bool DetectsSecrets => SecretHandling != SecretHandling.Keep;
    public int SecretLifetimeMinutes { get => _secretLifetimeMinutes; set => Set(ref _secretLifetimeMinutes, Math.Max(0, value)); }
    public bool DetectRandomTokens { get => _detectRandomTokens; set => Set(ref _detectRandomTokens, value); }
    public bool ClearAfterSecretPaste { get => _clearAfterSecretPaste; set => Set(ref _clearAfterSecretPaste, value); }

    /// <summary>Executable names, such as "KeePass.exe", whose copies are never saved.</summary>
    public ObservableCollection<string> IgnoredApps { get; set; } = [];

    [JsonIgnore]
    public IgnoreRules IgnoreRules
    {
        get
        {
            var kinds = new HashSet<ClipKind>();
            if (RecordText) kinds.Add(ClipKind.Text);
            if (RecordLinks) kinds.Add(ClipKind.Link);
            if (RecordImages) kinds.Add(ClipKind.Image);
            if (RecordFiles) kinds.Add(ClipKind.File);
            return new IgnoreRules
            {
                IgnoredFormats = SkipConcealed ? IgnoreRules.DefaultFormats : new HashSet<string>(),
                HonorHistoryOptOut = SkipConcealed,
                IgnoredApps = new HashSet<string>(IgnoredApps, StringComparer.OrdinalIgnoreCase),
                RecordedKinds = kinds,
            };
        }
    }

    public static TuckSettings Load(string path)
    {
        try
        {
            if (File.Exists(path) && JsonSerializer.Deserialize<TuckSettings>(File.ReadAllText(path), Json) is { } loaded)
            {
                return loaded;
            }
        }
        catch (Exception e) when (e is IOException or JsonException or UnauthorizedAccessException)
        {
            // Start with defaults; the broken file is replaced on the next save.
        }
        return new TuckSettings();
    }

    public void Save(string path)
    {
        try
        {
            File.WriteAllText(path, JsonSerializer.Serialize(this, Json));
        }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException)
        {
            // Settings stay in memory; they are saved again on the next change.
        }
    }
}
