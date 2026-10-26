using System.ComponentModel;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Interop;
using Tuck.App.Platform;
using Tuck.App.ViewModels;
using Forms = System.Windows.Forms;

namespace Tuck.App.Views;

/// <summary>
/// Tuck's icon in the notification area by the clock. Left-click opens the popup;
/// right-click shows the menu (the Windows twin of the macOS menu bar item).
/// </summary>
internal sealed class TrayIcon : IDisposable
{
    private readonly AppController _controller;
    private readonly Forms.NotifyIcon _icon;
    private readonly System.Drawing.Icon _normal = TrayArt.Icon(paused: false);
    private readonly System.Drawing.Icon _paused = TrayArt.Icon(paused: true);

    public TrayIcon(AppController controller)
    {
        _controller = controller;
        _icon = new Forms.NotifyIcon { Icon = _normal, Text = "Tuck", Visible = true };
        _icon.MouseClick += (_, e) =>
        {
            if (e.Button == Forms.MouseButtons.Left) _controller.TogglePopup();
            else if (e.Button == Forms.MouseButtons.Right) ShowMenu();
        };
        _controller.QueueChanged += Update;
        _controller.PropertyChanged += OnControllerChanged;
        Update();
    }

    private void OnControllerChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName is nameof(AppController.IsPaused) or nameof(AppController.StatusText)) Update();
    }

    private void Update()
    {
        _icon.Icon = _controller.IsPaused ? _paused : _normal;
        _icon.Text = _controller.StatusText;
    }

    private void ShowMenu()
    {
        var c = _controller;
        var menu = new ContextMenu { Placement = PlacementMode.MousePoint };

        menu.Items.Add(Item("Open Tuck", c.ShowPopup, gesture: c.Settings.PopupHotkey));
        menu.Items.Add(Check("Pause Recording", c.IsPaused, v => c.IsPaused = v));
        menu.Items.Add(new Separator());
        menu.Items.Add(new MenuItem { Header = "Paste Queue", IsEnabled = false });
        menu.Items.Add(Check("Collect New Copies", c.IsCollecting, v => c.IsCollecting = v));
        menu.Items.Add(Item(c.Queue.IsEmpty ? "Paste Next" : $"Paste Next ({c.QueueCount} left)", c.PasteNextInQueue,
            enabled: !c.Queue.IsEmpty, gesture: c.Settings.PasteNextHotkey));
        menu.Items.Add(Item("Clear Queue", c.ClearQueue, enabled: !c.Queue.IsEmpty || c.IsCollecting));
        menu.Items.Add(new Separator());
        menu.Items.Add(Item("Settings…", c.OpenSettings));
        menu.Items.Add(Item("Clear History…", () => c.ConfirmClearHistory()));
        menu.Items.Add(new Separator());
        menu.Items.Add(Item("Quit Tuck", () => Application.Current.Shutdown()));

        menu.IsOpen = true;
        // A tray menu only closes on an outside click if its window is in the foreground.
        if (PresentationSource.FromVisual(menu) is HwndSource source) Native.SetForegroundWindow(source.Handle);
    }

    private static MenuItem Item(string header, Action action, bool enabled = true, string? gesture = null)
    {
        var item = new MenuItem { Header = header, IsEnabled = enabled, InputGestureText = gesture ?? "" };
        item.Click += (_, _) => action();
        return item;
    }

    private static MenuItem Check(string header, bool isChecked, Action<bool> set)
    {
        var item = new MenuItem { Header = header, IsCheckable = true, IsChecked = isChecked };
        item.Click += (_, _) => set(item.IsChecked);
        return item;
    }

    public void Dispose()
    {
        _controller.QueueChanged -= Update;
        _controller.PropertyChanged -= OnControllerChanged;
        _icon.Visible = false;
        _icon.Dispose();
        _normal.Dispose();
        _paused.Dispose();
    }
}
