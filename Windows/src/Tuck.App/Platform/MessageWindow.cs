using System.Windows.Interop;

namespace Tuck.App.Platform;

/// <summary>
/// Hidden message-only window that receives clipboard-change notifications and
/// global hotkeys. Windows sends both as window messages.
/// </summary>
internal sealed class MessageWindow : IDisposable
{
    private readonly HwndSource _source;

    public event Action? ClipboardChanged;
    public event Action<int>? HotkeyPressed;

    public IntPtr Handle => _source.Handle;

    public MessageWindow()
    {
        _source = new HwndSource(new HwndSourceParameters("TuckMessages") { ParentWindow = Native.HWND_MESSAGE });
        _source.AddHook(WndProc);
        Native.AddClipboardFormatListener(_source.Handle);
    }

    private IntPtr WndProc(IntPtr hwnd, int msg, IntPtr wParam, IntPtr lParam, ref bool handled)
    {
        switch (msg)
        {
            case Native.WM_CLIPBOARDUPDATE:
                ClipboardChanged?.Invoke();
                handled = true;
                break;
            case Native.WM_HOTKEY:
                HotkeyPressed?.Invoke(wParam.ToInt32());
                handled = true;
                break;
        }
        return IntPtr.Zero;
    }

    public void Dispose()
    {
        Native.RemoveClipboardFormatListener(_source.Handle);
        _source.RemoveHook(WndProc);
        _source.Dispose();
    }
}
