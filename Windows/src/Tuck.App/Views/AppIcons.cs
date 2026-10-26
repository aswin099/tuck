using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using Forms = System.Windows.Forms;

namespace Tuck.App.Views;

/// <summary>
/// Tuck's icons, embedded from Assets/*.ico. They are drawn by tools/render-icon.swift
/// from the same artwork as the macOS icons.
/// </summary>
internal static class AppIcons
{
    private static Uri Pack(string name) => new($"pack://application:,,,/Assets/{name}");

    /// <summary>Notification-area icon at the size Windows uses for the current display scaling.</summary>
    public static System.Drawing.Icon Tray(bool paused)
    {
        var resource = Application.GetResourceStream(Pack(paused ? "TrayIconPaused.ico" : "TrayIcon.ico"))
            ?? throw new InvalidOperationException("Tray icon resource is missing.");
        using var stream = resource.Stream;
        return new System.Drawing.Icon(stream, Forms.SystemInformation.SmallIconSize);
    }

    /// <summary>The largest image in Tuck.ico, for the About tab.</summary>
    public static ImageSource Large()
    {
        var decoder = BitmapDecoder.Create(Pack("Tuck.ico"), BitmapCreateOptions.None, BitmapCacheOption.OnLoad);
        return decoder.Frames.OrderByDescending(frame => frame.PixelWidth).First();
    }
}
