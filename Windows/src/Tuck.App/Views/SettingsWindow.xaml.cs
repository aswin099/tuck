using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Windows;
using Microsoft.Win32;
using Tuck.App.ViewModels;

namespace Tuck.App.Views;

public partial class SettingsWindow : Window
{
    private readonly AppController _controller;

    public SettingsWindow(AppController controller)
    {
        _controller = controller;
        DataContext = controller;
        InitializeComponent();
        AppIcon.Source = AppIcons.Large();
        var version = Assembly.GetExecutingAssembly().GetName().Version;
        VersionText.Text = version is null ? "" : $"Version {version.Major}.{version.Minor}.{version.Build}";
        ShowStorageStatus();
    }

    private void ShowStorageStatus()
    {
        switch (_controller.StorageStatus)
        {
            case StorageStatus.Encrypted:
                StorageGlyph.Text = "";
                StorageLabel.Text = "Encrypted";
                StorageFootnote.Text = "History is encrypted with Windows DPAPI, using a key tied to your Windows account. Hidden secrets are never written to disk.";
                break;
            case StorageStatus.Recovered:
                StorageGlyph.Text = "";
                StorageLabel.Text = "Encrypted, started fresh";
                StorageFootnote.Text = $"The previous history file couldn't be decrypted, so it was kept as {_controller.StorageDetail} and a new one was started.";
                break;
            case StorageStatus.MemoryOnly:
                StorageGlyph.Text = "";
                StorageLabel.Text = "Not saved to disk";
                StorageFootnote.Text = $"Tuck couldn't use Windows encryption ({_controller.StorageDetail}), so history is kept only until Tuck quits.";
                break;
        }
        if (_controller.StorageStatus != StorageStatus.Encrypted)
        {
            StorageGlyph.SetResourceReference(ForegroundProperty, "Tuck.Warning");
            StorageLabel.SetResourceReference(ForegroundProperty, "Tuck.Warning");
        }
    }

    private void OnRecordingChanged(bool recording)
    {
        if (recording) _controller.SuspendHotkeys();
        else _controller.ResumeHotkeys();
    }

    private void OnOpenDataFolder(object sender, RoutedEventArgs e) =>
        Process.Start(new ProcessStartInfo { FileName = _controller.DataFolder, UseShellExecute = true });

    private void OnClearHistory(object sender, RoutedEventArgs e) => _controller.ConfirmClearHistory(this);

    private void OnAddIgnoredApp(object sender, RoutedEventArgs e)
    {
        var dialog = new OpenFileDialog
        {
            Title = "Choose apps to ignore",
            Filter = "Apps (*.exe)|*.exe",
            Multiselect = true,
            InitialDirectory = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles),
        };
        if (dialog.ShowDialog(this) != true) return;
        foreach (var path in dialog.FileNames)
        {
            var exe = Path.GetFileName(path);
            if (!_controller.Settings.IgnoredApps.Contains(exe, StringComparer.OrdinalIgnoreCase))
            {
                _controller.Settings.IgnoredApps.Add(exe);
            }
        }
    }

    private void OnRemoveIgnoredApp(object sender, RoutedEventArgs e)
    {
        if (IgnoredList.SelectedItem is string exe) _controller.Settings.IgnoredApps.Remove(exe);
    }
}
