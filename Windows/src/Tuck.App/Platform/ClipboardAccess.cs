using System.Collections.Specialized;
using System.IO;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Media.Imaging;
using Tuck.Core;

namespace Tuck.App.Platform;

/// <summary>Reads clipboard contents into ClipItems and writes them back.</summary>
internal static class ClipboardAccess
{
    private const string HistoryOptOutFormat = "CanIncludeInClipboardHistory";
    private const string CloudOptOutFormat = "CanUploadToCloudClipboard";

    /// <summary>What is on the clipboard now, plus the details the ignore rules need.</summary>
    public sealed record Snapshot(ClipItem? Item, IReadOnlyList<string> Formats, bool HistoryOptOut);

    /// <summary>Another app may still hold the clipboard open, so a failed read is retried briefly.</summary>
    public static Snapshot? Read(string? sourceApp, string? sourceAppPath)
    {
        for (var attempt = 0; attempt < 5; attempt++)
        {
            try
            {
                return ReadOnce(sourceApp, sourceAppPath);
            }
            catch (ExternalException)
            {
                Thread.Sleep(40);
            }
        }
        return null;
    }

    private static Snapshot? ReadOnce(string? sourceApp, string? sourceAppPath)
    {
        var data = Clipboard.GetDataObject();
        if (data is null) return null;
        var formats = data.GetFormats(autoConvert: false) ?? [];
        var optOut = data.GetDataPresent(HistoryOptOutFormat)
            && data.GetData(HistoryOptOutFormat) is MemoryStream stream
            && stream.Length >= 4
            && BitConverter.ToInt32(stream.ToArray(), 0) == 0;

        ClipItem? item = null;
        if (data.GetDataPresent(DataFormats.FileDrop) && data.GetData(DataFormats.FileDrop) is string[] { Length: > 0 } files)
        {
            item = ClipItem.Create(ClipKind.File, string.Join("\n", files), sourceApp: sourceApp);
        }
        else if (data.GetDataPresent(DataFormats.UnicodeText) && data.GetData(DataFormats.UnicodeText) is string { Length: > 0 } text)
        {
            var trimmed = text.Trim();
            var isLink = !trimmed.Contains(' ') && !trimmed.Contains('\n')
                && (trimmed.StartsWith("http://", StringComparison.OrdinalIgnoreCase)
                    || trimmed.StartsWith("https://", StringComparison.OrdinalIgnoreCase));
            item = ClipItem.Create(isLink ? ClipKind.Link : ClipKind.Text, text, sourceApp: sourceApp);
        }
        else if (Clipboard.ContainsImage() && Clipboard.GetImage() is { } image)
        {
            var encoder = new PngBitmapEncoder();
            encoder.Frames.Add(BitmapFrame.Create(image));
            using var png = new MemoryStream();
            encoder.Save(png);
            item = ClipItem.Create(ClipKind.Image, data: png.ToArray(), sourceApp: sourceApp);
        }

        if (item is not null) item.SourceAppPath = sourceAppPath;
        return new Snapshot(item, formats, optOut);
    }

    /// <summary>
    /// Puts an item on the clipboard. Secrets are marked so Windows clipboard history
    /// (Win+V) and cloud clipboard sync don't keep them.
    /// </summary>
    public static bool Write(ClipItem item)
    {
        var data = new DataObject();
        switch (item.Kind)
        {
            case ClipKind.Image when item.Data is { } bytes:
                var bitmap = new BitmapImage();
                bitmap.BeginInit();
                bitmap.CacheOption = BitmapCacheOption.OnLoad;
                bitmap.StreamSource = new MemoryStream(bytes);
                bitmap.EndInit();
                bitmap.Freeze();
                data.SetImage(bitmap);
                data.SetData("PNG", new MemoryStream(bytes));
                break;
            case ClipKind.File:
                var paths = new StringCollection();
                paths.AddRange([.. item.FilePaths]);
                data.SetFileDropList(paths);
                break;
            default:
                data.SetText(item.Text ?? "", TextDataFormat.UnicodeText);
                break;
        }
        if (item.IsSecret)
        {
            data.SetData(HistoryOptOutFormat, new MemoryStream(BitConverter.GetBytes(0)));
            data.SetData(CloudOptOutFormat, new MemoryStream(BitConverter.GetBytes(0)));
        }

        for (var attempt = 0; attempt < 5; attempt++)
        {
            try
            {
                Clipboard.SetDataObject(data, copy: true);
                return true;
            }
            catch (ExternalException)
            {
                Thread.Sleep(40);
            }
        }
        return false;
    }

    public static void Clear()
    {
        try { Clipboard.Clear(); }
        catch (ExternalException) { }
    }
}
