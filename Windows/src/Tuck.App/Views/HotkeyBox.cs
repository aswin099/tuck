using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using Tuck.App.Platform;

namespace Tuck.App.Views;

/// <summary>Click, then press a shortcut to record it. Backspace or Delete clears it.</summary>
public sealed class HotkeyBox : TextBox
{
    public static readonly DependencyProperty HotkeyProperty = DependencyProperty.Register(
        nameof(Hotkey), typeof(string), typeof(HotkeyBox),
        new FrameworkPropertyMetadata("", FrameworkPropertyMetadataOptions.BindsTwoWayByDefault, (d, _) => ((HotkeyBox)d).UpdateText()));

    /// <summary>Raised when recording starts or stops, so global hotkeys can be paused meanwhile.</summary>
    public event Action<bool>? RecordingChanged;

    public HotkeyBox()
    {
        IsReadOnly = true;
        IsReadOnlyCaretVisible = false;
        Cursor = Cursors.Hand;
        MinWidth = 170;
        TextAlignment = TextAlignment.Center;
        UpdateText();
    }

    public string Hotkey
    {
        get => (string)GetValue(HotkeyProperty);
        set => SetValue(HotkeyProperty, value);
    }

    protected override void OnGotKeyboardFocus(KeyboardFocusChangedEventArgs e)
    {
        base.OnGotKeyboardFocus(e);
        RecordingChanged?.Invoke(true);
        UpdateText();
    }

    protected override void OnLostKeyboardFocus(KeyboardFocusChangedEventArgs e)
    {
        base.OnLostKeyboardFocus(e);
        RecordingChanged?.Invoke(false);
        UpdateText();
    }

    protected override void OnPreviewKeyDown(KeyEventArgs e)
    {
        var key = e.Key == Key.System ? e.SystemKey : e.Key;
        var mods = Keyboard.Modifiers;
        if (key == Key.Tab && mods is ModifierKeys.None or ModifierKeys.Shift)
        {
            return; // Let Tab move focus as usual.
        }
        e.Handled = true;
        if (mods == ModifierKeys.None && key is Key.Back or Key.Delete)
        {
            Hotkey = "";
        }
        else if (mods == ModifierKeys.None && key == Key.Escape)
        {
            Keyboard.ClearFocus();
        }
        else if (mods != ModifierKeys.None && !Platform.Hotkey.IsModifierKey(key))
        {
            Hotkey = new Platform.Hotkey(mods, key).ToString();
            Keyboard.ClearFocus();
        }
    }

    private void UpdateText() =>
        Text = IsKeyboardFocused ? "Press a shortcut…" : string.IsNullOrEmpty(Hotkey) ? "None" : Hotkey;
}
