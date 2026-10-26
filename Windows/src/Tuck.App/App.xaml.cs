using System.IO;
using System.Windows;
using System.Windows.Threading;
using Tuck.App.ViewModels;
using Tuck.App.Views;

namespace Tuck.App;

public partial class App : Application
{
    private Mutex? _singleInstance;
    private bool _ownsMutex;
    private AppController? _controller;
    private TrayIcon? _tray;

    protected override void OnStartup(StartupEventArgs e)
    {
        _singleInstance = new Mutex(initiallyOwned: true, @"Local\Tuck.SingleInstance", out _ownsMutex);
        if (!_ownsMutex)
        {
            MessageBox.Show("Tuck is already running. Look for its icon in the notification area next to the clock.",
                "Tuck", MessageBoxButton.OK, MessageBoxImage.Information);
            Shutdown();
            return;
        }

        base.OnStartup(e);
        DispatcherUnhandledException += OnUnhandledException;
        Theme.FollowSystem();
        _controller = new AppController();
        _controller.Start();
        _tray = new TrayIcon(_controller);
    }

    protected override void OnExit(ExitEventArgs e)
    {
        _tray?.Dispose();
        _controller?.Dispose();
        if (_ownsMutex) _singleInstance?.ReleaseMutex();
        _singleInstance?.Dispose();
        base.OnExit(e);
    }

    /// <summary>Logs unexpected errors locally (never sent anywhere) and keeps Tuck running.</summary>
    private void OnUnhandledException(object sender, DispatcherUnhandledExceptionEventArgs e)
    {
        try
        {
            var folder = _controller?.DataFolder ?? Path.GetTempPath();
            File.AppendAllText(Path.Combine(folder, "error.log"), $"{DateTimeOffset.Now:O} {e.Exception}\n\n");
        }
        catch (IOException)
        {
        }
        e.Handled = true;
    }
}
