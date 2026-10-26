using System.IO;
using System.Windows.Media;
using Tuck.App.Platform;
using Tuck.Core;

namespace Tuck.App.ViewModels;

/// <summary>One row in the popup list, and the data the preview pane shows for it.</summary>
public sealed class ItemViewModel(ClipItem item, int index, int? queuePosition) : ObservableObject
{
    private bool _revealSecret;

    public ClipItem Item { get; } = item;
    public Guid Id => Item.Id;
    public int Index { get; } = index;

    public string DisplayText => Item.DisplayPreview;
    public bool IsPinned => Item.IsPinned;
    public bool IsSecret => Item.IsSecret;
    public bool IsImage => Item.Kind == ClipKind.Image;
    public bool IsFile => Item.Kind == ClipKind.File;
    public bool IsTextLike => Item.Kind is ClipKind.Text or ClipKind.Link;

    public int? QueuePosition { get; } = queuePosition;
    public bool IsQueued => QueuePosition is not null;
    public string ShortcutHint => Index < 9 ? $"Ctrl+{Index + 1}" : "";
    public string AccessibleName => $"{(IsPinned ? "Pinned. " : "")}{(IsQueued ? $"Queue position {QueuePosition}. " : "")}{DisplayText}";

    public ImageSource? Thumbnail => IsImage ? ImageCache.For(Item, decodeWidth: 96) : null;
    public ImageSource? PreviewImage => IsImage ? ImageCache.For(Item) : null;

    private AppInfo.Entry Source => AppInfo.Lookup(Item.SourceApp, Item.SourceAppPath);
    public bool HasSource => Item.SourceApp is not null;
    public string SourceName => Source.Name;
    public ImageSource? SourceIcon => HasSource ? Source.Icon : null;
    public string CopiedAgo => RelativeTime.Short(Item.CreatedAt);
    public string MetaText => HasSource ? $"{SourceName} · {CopiedAgo}" : CopiedAgo;

    // Preview pane

    public string KindLabel => Item.SecretKind?.Label() ?? Item.Kind switch
    {
        ClipKind.Text => "Text",
        ClipKind.Link => "Link",
        ClipKind.Image => "Image",
        ClipKind.File => Item.FilePaths.Count == 1 ? "File" : "Files",
        _ => "",
    };

    /// <summary>Segoe Fluent Icons glyph for the item kind.</summary>
    public string KindGlyph => IsSecret ? "" : Item.Kind switch
    {
        ClipKind.Link => "",
        ClipKind.Image => "",
        ClipKind.File => "",
        _ => "",
    };

    public bool RevealSecret
    {
        get => _revealSecret;
        set
        {
            if (Set(ref _revealSecret, value))
            {
                Raise(nameof(ShowSecretMask));
                Raise(nameof(ShowFullText));
            }
        }
    }

    public bool ShowSecretMask => IsSecret && !RevealSecret;
    public bool ShowFullText => IsTextLike && !ShowSecretMask;
    public string FullText => Item.Text ?? "";
    public bool UseMonospace => LooksLikeCode(Item.Text);

    public IReadOnlyList<FileEntry> Files => IsFile
        ? Item.FilePaths.Select(p => new FileEntry(Path.GetFileName(p), Path.GetDirectoryName(p) ?? "", FileIcons.For(p))).ToList()
        : [];

    public string CopiedLong => RelativeTime.Long(Item.CreatedAt);
    public string? ExpiresText => Item.ExpiresAt is { } at ? RelativeTime.Until(at) : null;
    public bool HasExpiry => Item.ExpiresAt is not null;

    public string SizeText
    {
        get
        {
            switch (Item.Kind)
            {
                case ClipKind.Image:
                    var bytes = FormatBytes(Item.Data?.Length ?? 0);
                    return ImageCache.PixelSize(Item) is { } size ? $"{size.Width} × {size.Height} px · {bytes}" : bytes;
                case ClipKind.File:
                    return Item.FilePaths.Count == 1 ? "1 item" : $"{Item.FilePaths.Count} items";
                default:
                    var text = Item.Text ?? "";
                    var words = text.Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries).Length;
                    var lines = text.Split('\n', StringSplitOptions.RemoveEmptyEntries).Length;
                    var parts = new List<string> { $"{text.Length} characters" };
                    if (words > 1) parts.Add($"{words} words");
                    if (lines > 1) parts.Add($"{lines} lines");
                    return string.Join(" · ", parts);
            }
        }
    }

    private static bool LooksLikeCode(string? text)
    {
        if (text is null) return false;
        string[] markers = ["{", "}", ";", "=>", "function ", "def ", "const ", "</", "#include", "import ", "using "];
        return markers.Count(text.Contains) >= 2;
    }

    private static string FormatBytes(long bytes) => bytes switch
    {
        < 1024 => $"{bytes} bytes",
        < 1024 * 1024 => $"{bytes / 1024.0:0.#} KB",
        _ => $"{bytes / (1024.0 * 1024):0.#} MB",
    };
}

public sealed record FileEntry(string Name, string Folder, ImageSource? Icon);

internal static class FileIcons
{
    private static readonly Dictionary<string, ImageSource?> Cache = new(StringComparer.OrdinalIgnoreCase);

    public static ImageSource? For(string path)
    {
        var key = Directory.Exists(path) ? "<folder>" : Path.GetExtension(path);
        if (key is ".exe" or ".lnk" or ".ico") key = path;
        if (Cache.TryGetValue(key, out var cached)) return cached;
        ImageSource? icon = null;
        try
        {
            if (File.Exists(path) && System.Drawing.Icon.ExtractAssociatedIcon(path) is { } extracted)
            {
                using (extracted)
                {
                    var source = System.Windows.Interop.Imaging.CreateBitmapSourceFromHIcon(
                        extracted.Handle, System.Windows.Int32Rect.Empty,
                        System.Windows.Media.Imaging.BitmapSizeOptions.FromEmptyOptions());
                    source.Freeze();
                    icon = source;
                }
            }
        }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException or ArgumentException)
        {
            // Show the file without an icon.
        }
        Cache[key] = icon;
        return icon;
    }
}

internal static class RelativeTime
{
    public static string Short(DateTimeOffset date)
    {
        var span = DateTimeOffset.Now - date;
        return span.TotalSeconds switch
        {
            < 60 => "now",
            < 3600 => $"{(int)span.TotalMinutes} min ago",
            < 86400 => $"{(int)span.TotalHours} hr ago",
            _ => $"{(int)span.TotalDays} d ago",
        };
    }

    public static string Long(DateTimeOffset date)
    {
        var span = DateTimeOffset.Now - date;
        static string Plural(int n, string unit) => n == 1 ? $"1 {unit} ago" : $"{n} {unit}s ago";
        return span.TotalSeconds switch
        {
            < 60 => "Just now",
            < 3600 => Plural((int)span.TotalMinutes, "minute"),
            < 86400 => Plural((int)span.TotalHours, "hour"),
            < 172800 => "Yesterday",
            _ => date.LocalDateTime.ToString("d MMM yyyy, HH:mm"),
        };
    }

    public static string Until(DateTimeOffset date)
    {
        var minutes = (int)Math.Ceiling((date - DateTimeOffset.Now).TotalMinutes);
        return minutes <= 1 ? "in under a minute" : minutes < 60 ? $"in {minutes} minutes" : $"in {minutes / 60} hr";
    }
}
