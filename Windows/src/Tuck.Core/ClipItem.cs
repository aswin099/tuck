using System.Text.Json.Serialization;

namespace Tuck.Core;

[JsonConverter(typeof(JsonStringEnumConverter<ClipKind>))]
public enum ClipKind
{
    Text,
    Link,
    Image,
    File,
}

/// <summary>One entry in the clipboard history.</summary>
public sealed record ClipItem
{
    public Guid Id { get; init; } = Guid.NewGuid();
    public required ClipKind Kind { get; init; }
    /// <summary>Plain text (or newline-separated file paths for <see cref="ClipKind.File"/>). Used for search and paste.</summary>
    public string? Text { get; init; }
    /// <summary>PNG bytes for images.</summary>
    public byte[]? Data { get; init; }
    /// <summary>Executable name of the app the item was copied from, such as "chrome.exe".</summary>
    public string? SourceApp { get; set; }
    /// <summary>Full path of that executable, used for its icon and display name.</summary>
    public string? SourceAppPath { get; set; }
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.Now;
    public bool IsPinned { get; set; }
    /// <summary>Set when the text looks like a password, key or token.</summary>
    public SecretKind? SecretKind { get; set; }
    /// <summary>When set, the item is removed after this time (even if pinned) and is never saved to disk.</summary>
    public DateTimeOffset? ExpiresAt { get; set; }
    /// <summary>Content hash used to merge duplicates. Not a security hash.</summary>
    public string Fingerprint { get; init; } = "";

    [JsonIgnore]
    public bool IsSecret => SecretKind is not null;

    /// <summary>Creates an item and computes its fingerprint.</summary>
    public static ClipItem Create(
        ClipKind kind,
        string? text = null,
        byte[]? data = null,
        string? sourceApp = null,
        DateTimeOffset? createdAt = null,
        bool isPinned = false,
        SecretKind? secretKind = null,
        DateTimeOffset? expiresAt = null) => new()
    {
        Kind = kind,
        Text = text,
        Data = data,
        SourceApp = sourceApp,
        CreatedAt = createdAt ?? DateTimeOffset.Now,
        IsPinned = isPinned,
        SecretKind = secretKind,
        ExpiresAt = expiresAt,
        Fingerprint = Core.Fingerprint.Make(kind, text, data),
    };

    /// <summary>Short single-line description for list rows.</summary>
    [JsonIgnore]
    public string Preview
    {
        get
        {
            if (Kind == ClipKind.Image) return "Image";
            var lines = (Text ?? "").Trim()
                .Split(['\r', '\n'], StringSplitOptions.RemoveEmptyEntries)
                .Take(2);
            var joined = string.Join(" ", lines);
            if (joined.Length == 0) return "(empty)";
            return joined.Length > 300 ? joined[..300] : joined;
        }
    }

    /// <summary>Row text, with secrets replaced by dots and their kind.</summary>
    [JsonIgnore]
    public string DisplayPreview => SecretKind is { } kind ? $"•••••••••••• {kind.Label()}" : Preview;

    [JsonIgnore]
    public IReadOnlyList<string> FilePaths =>
        (Text ?? "").Split('\n', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
}

internal static class Fingerprint
{
    /// <summary>FNV-1a 64-bit over kind, text and data (same scheme as the macOS app).</summary>
    public static string Make(ClipKind kind, string? text, byte[]? data)
    {
        ulong hash = 0xcbf2_9ce4_8422_2325;
        const ulong prime = 0x0000_0100_0000_01b3;

        void Mix(byte b)
        {
            hash ^= b;
            hash *= prime;
        }

        foreach (var b in System.Text.Encoding.UTF8.GetBytes(kind.ToString().ToLowerInvariant())) Mix(b);
        Mix(0);
        if (text is not null) foreach (var b in System.Text.Encoding.UTF8.GetBytes(text)) Mix(b);
        Mix(0);
        if (data is not null) foreach (var b in data) Mix(b);
        return hash.ToString("x");
    }
}
