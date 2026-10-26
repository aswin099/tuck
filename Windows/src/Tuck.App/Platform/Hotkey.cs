using System.Windows.Input;

namespace Tuck.App.Platform;

/// <summary>A key plus modifiers, stored as text such as "Ctrl+Shift+V".</summary>
public readonly record struct Hotkey(ModifierKeys Modifiers, Key Key)
{
    public static Hotkey? Parse(string? text)
    {
        if (string.IsNullOrWhiteSpace(text)) return null;
        var modifiers = ModifierKeys.None;
        Key? key = null;
        foreach (var part in text.Split('+', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
        {
            switch (part.ToLowerInvariant())
            {
                case "ctrl": modifiers |= ModifierKeys.Control; break;
                case "alt": modifiers |= ModifierKeys.Alt; break;
                case "shift": modifiers |= ModifierKeys.Shift; break;
                case "win": modifiers |= ModifierKeys.Windows; break;
                default:
                    if (Enum.TryParse<Key>(part, ignoreCase: true, out var parsed)) key = parsed;
                    else if (part.Length == 1 && char.IsDigit(part[0])) key = Key.D0 + (part[0] - '0');
                    else if (part == "`") key = Key.Oem3;
                    break;
            }
        }
        return key is { } k && modifiers != ModifierKeys.None ? new Hotkey(modifiers, k) : null;
    }

    public static bool IsModifierKey(Key key) => key is Key.LeftCtrl or Key.RightCtrl or Key.LeftAlt or Key.RightAlt
        or Key.LeftShift or Key.RightShift or Key.LWin or Key.RWin or Key.System;

    public override string ToString()
    {
        var parts = new List<string>();
        if (Modifiers.HasFlag(ModifierKeys.Control)) parts.Add("Ctrl");
        if (Modifiers.HasFlag(ModifierKeys.Alt)) parts.Add("Alt");
        if (Modifiers.HasFlag(ModifierKeys.Shift)) parts.Add("Shift");
        if (Modifiers.HasFlag(ModifierKeys.Windows)) parts.Add("Win");
        parts.Add(Key switch
        {
            >= Key.D0 and <= Key.D9 => ((char)('0' + (Key - Key.D0))).ToString(),
            Key.Oem3 => "`",
            Key.Space => "Space",
            _ => Key.ToString(),
        });
        return string.Join("+", parts);
    }

    public uint NativeModifiers
    {
        get
        {
            uint mods = Native.MOD_NOREPEAT;
            if (Modifiers.HasFlag(ModifierKeys.Alt)) mods |= Native.MOD_ALT;
            if (Modifiers.HasFlag(ModifierKeys.Control)) mods |= Native.MOD_CONTROL;
            if (Modifiers.HasFlag(ModifierKeys.Shift)) mods |= Native.MOD_SHIFT;
            if (Modifiers.HasFlag(ModifierKeys.Windows)) mods |= Native.MOD_WIN;
            return mods;
        }
    }

    public uint VirtualKey => (uint)KeyInterop.VirtualKeyFromKey(Key);
}

public enum HotkeyAction
{
    TogglePopup = 1,
    PasteNextInQueue = 2,
    ToggleCollecting = 3,
}

/// <summary>Registers system-wide hotkeys and reports which ones another app already uses.</summary>
internal sealed class HotkeyManager(MessageWindow window) : IDisposable
{
    private readonly HashSet<int> _registered = [];

    /// <summary>Replaces the hotkey for an action. Returns false if Windows refused it (usually because another app uses it).</summary>
    public bool Register(HotkeyAction action, string? text)
    {
        var id = (int)action;
        if (_registered.Remove(id)) Native.UnregisterHotKey(window.Handle, id);
        if (Hotkey.Parse(text) is not { } hotkey) return true;
        if (!Native.RegisterHotKey(window.Handle, id, hotkey.NativeModifiers, hotkey.VirtualKey)) return false;
        _registered.Add(id);
        return true;
    }

    public void Dispose()
    {
        foreach (var id in _registered) Native.UnregisterHotKey(window.Handle, id);
        _registered.Clear();
    }
}
