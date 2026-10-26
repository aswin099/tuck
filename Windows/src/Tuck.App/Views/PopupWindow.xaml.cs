using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Interop;
using Tuck.App.Platform;
using Tuck.App.ViewModels;

namespace Tuck.App.Views;

/// <summary>The clipboard popup. Opens near the mouse pointer (or centered) and hides when it loses focus.</summary>
public partial class PopupWindow : Window
{
    private const double ShadowMargin = 16;
    private readonly AppController _controller;

    public PopupWindow(AppController controller)
    {
        _controller = controller;
        DataContext = controller;
        InitializeComponent();
        Deactivated += (_, _) => Hide();
        SizeChanged += (_, _) => ClampToScreen();
        PreviewKeyDown += OnPreviewKeyDown;
    }

    public IntPtr Handle => new WindowInteropHelper(this).Handle;

    public void ShowAtPreferredPosition(bool center)
    {
        var hwnd = new WindowInteropHelper(this).EnsureHandle();
        Native.GetCursorPos(out var cursor);
        var scale = Native.ScaleAt(cursor);
        var work = System.Windows.Forms.Screen.FromPoint(new System.Drawing.Point(cursor.X, cursor.Y)).WorkingArea;

        var width = (int)Math.Ceiling((_controller.PopupWidth + 2 + ShadowMargin * 2) * scale);
        var height = (int)Math.Ceiling((460 + 2 + ShadowMargin * 2) * scale);
        int x, y;
        if (center)
        {
            x = work.Left + (work.Width - width) / 2;
            y = work.Top + (work.Height - height) / 2;
        }
        else
        {
            x = cursor.X - (int)((AppController.ListWidth / 2 + ShadowMargin) * scale);
            y = cursor.Y - (int)(ShadowMargin * scale) + 4;
            // Open above the pointer when there isn't room below it.
            if (y + height > work.Bottom) y = cursor.Y - height + (int)(ShadowMargin * scale);
        }
        x = Math.Clamp(x, work.Left, Math.Max(work.Left, work.Right - width));
        y = Math.Clamp(y, work.Top, Math.Max(work.Top, work.Bottom - height));
        Native.SetWindowPos(hwnd, IntPtr.Zero, x, y, 0, 0, Native.SWP_NOSIZE | Native.SWP_NOZORDER | Native.SWP_NOACTIVATE);

        Show();
        Activate();
        Native.SetForegroundWindow(hwnd);
        SearchBox.Focus();
        Keyboard.Focus(SearchBox);
        if (_controller.Selected is { } selected) ItemsList.ScrollIntoView(selected);
    }

    /// <summary>Keeps the whole popup on screen, for example after the preview pane makes it wider.</summary>
    private void ClampToScreen()
    {
        if (!IsVisible || !Native.GetWindowRect(Handle, out var rect)) return;
        var work = System.Windows.Forms.Screen.FromHandle(Handle).WorkingArea;
        var width = rect.Right - rect.Left;
        var height = rect.Bottom - rect.Top;
        var x = Math.Clamp(rect.Left, work.Left, Math.Max(work.Left, work.Right - width));
        var y = Math.Clamp(rect.Top, work.Top, Math.Max(work.Top, work.Bottom - height));
        if (x != rect.Left || y != rect.Top)
        {
            Native.SetWindowPos(Handle, IntPtr.Zero, x, y, 0, 0, Native.SWP_NOSIZE | Native.SWP_NOZORDER | Native.SWP_NOACTIVATE);
        }
    }

    private void OnPreviewKeyDown(object sender, KeyEventArgs e)
    {
        var key = e.Key == Key.System ? e.SystemKey : e.Key;
        var mods = Keyboard.Modifiers;
        e.Handled = true;

        switch (key)
        {
            case Key.Down when mods == ModifierKeys.None: _controller.Move(1); break;
            case Key.Up when mods == ModifierKeys.None: _controller.Move(-1); break;
            case Key.PageDown when mods == ModifierKeys.None: _controller.Move(8); break;
            case Key.PageUp when mods == ModifierKeys.None: _controller.Move(-8); break;
            case Key.Enter when mods == ModifierKeys.None: _controller.PasteSelected(); break;
            case Key.Escape: _controller.HidePopup(); break;
            case Key.Tab when mods == ModifierKeys.None: _controller.ToggleQueuedSelected(); break;
            case >= Key.D1 and <= Key.D9 when mods == ModifierKeys.Control: _controller.PasteAt(key - Key.D1); break;
            case >= Key.NumPad1 and <= Key.NumPad9 when mods == ModifierKeys.Control: _controller.PasteAt(key - Key.NumPad1); break;
            case Key.P when mods == ModifierKeys.Control: _controller.TogglePinSelected(); break;
            case Key.P when mods == ModifierKeys.Alt: _controller.Settings.ShowPreview = !_controller.Settings.ShowPreview; break;
            case Key.Delete when mods == ModifierKeys.Shift: _controller.DeleteSelected(); break;
            case Key.OemComma when mods == ModifierKeys.Control: _controller.OpenSettings(); break;
            default: e.Handled = false; break;
        }
    }

    private void OnSelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (ItemsList.SelectedItem is { } item) ItemsList.ScrollIntoView(item);
        // Keep typing in the search box after a click on a row.
        if (IsVisible && !SearchBox.IsKeyboardFocused) SearchBox.Focus();
    }

    private void OnItemDoubleClick(object sender, MouseButtonEventArgs e)
    {
        if (sender is ListBoxItem { DataContext: ItemViewModel item }) _controller.Paste(item.Item);
    }

    private void OnClearSearch(object sender, RoutedEventArgs e)
    {
        _controller.Query = "";
        SearchBox.Focus();
    }

    private void OnToggleCollecting(object sender, RoutedEventArgs e) => _controller.IsCollecting = !_controller.IsCollecting;

    private void OnClearQueue(object sender, RoutedEventArgs e) => _controller.ClearQueue();
}
