using System.Diagnostics;
using System.IO;
using System.Windows;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using Tuck.Core;

namespace Tuck.App.Platform;

/// <summary>Display name and icon of an app, looked up from its executable and cached.</summary>
internal static class AppInfo
{
    public sealed record Entry(string Name, ImageSource? Icon);

    private static readonly Dictionary<string, Entry> Cache = new(StringComparer.OrdinalIgnoreCase);

    public static Entry Lookup(string? exeName, string? exePath)
    {
        var key = exePath ?? exeName ?? "";
        if (Cache.TryGetValue(key, out var cached)) return cached;

        var name = exeName is null ? "Unknown app" : Path.GetFileNameWithoutExtension(exeName);
        ImageSource? icon = null;
        if (exePath is not null && File.Exists(exePath))
        {
            try
            {
                var info = FileVersionInfo.GetVersionInfo(exePath);
                if (!string.IsNullOrWhiteSpace(info.FileDescription)) name = info.FileDescription;
                else if (!string.IsNullOrWhiteSpace(info.ProductName)) name = info.ProductName;

                using var extracted = System.Drawing.Icon.ExtractAssociatedIcon(exePath);
                if (extracted is not null)
                {
                    var source = Imaging.CreateBitmapSourceFromHIcon(extracted.Handle, Int32Rect.Empty, BitmapSizeOptions.FromEmptyOptions());
                    source.Freeze();
                    icon = source;
                }
            }
            catch (Exception e) when (e is IOException or UnauthorizedAccessException or ArgumentException or System.ComponentModel.Win32Exception)
            {
                // Keep the executable name and no icon.
            }
        }
        var entry = new Entry(name, icon);
        Cache[key] = entry;
        return entry;
    }
}

/// <summary>Decoded images keyed by item id, so rows and the preview don't decode on every render.</summary>
internal static class ImageCache
{
    private static readonly Dictionary<(Guid, int), BitmapSource> Cache = [];

    /// <param name="decodeWidth">Pixel width to decode at, or 0 for full size.</param>
    public static BitmapSource? For(ClipItem item, int decodeWidth = 0)
    {
        if (item.Data is null) return null;
        if (Cache.TryGetValue((item.Id, decodeWidth), out var cached)) return cached;
        if (Cache.Count > 120) Cache.Clear();
        try
        {
            var image = new BitmapImage();
            image.BeginInit();
            image.CacheOption = BitmapCacheOption.OnLoad;
            image.StreamSource = new MemoryStream(item.Data);
            if (decodeWidth > 0) image.DecodePixelWidth = decodeWidth;
            image.EndInit();
            image.Freeze();
            Cache[(item.Id, decodeWidth)] = image;
            return image;
        }
        catch (Exception e) when (e is NotSupportedException or IOException or ArgumentException)
        {
            return null;
        }
    }

    /// <summary>Pixel size of the full image, without keeping a full decode around.</summary>
    public static (int Width, int Height)? PixelSize(ClipItem item)
    {
        if (item.Data is null) return null;
        try
        {
            var frame = BitmapFrame.Create(new MemoryStream(item.Data), BitmapCreateOptions.DelayCreation, BitmapCacheOption.None);
            return (frame.PixelWidth, frame.PixelHeight);
        }
        catch (Exception e) when (e is NotSupportedException or IOException or ArgumentException)
        {
            return null;
        }
    }
}
