namespace Tuck.Core;

/// <summary>Decides whether a clipboard change should be skipped.</summary>
public sealed record IgnoreRules
{
    /// <summary>
    /// Clipboard formats that mark content as secret or not for history. Password
    /// managers such as KeePass, 1Password and Bitwarden set these when copying a password.
    /// </summary>
    public static readonly IReadOnlySet<string> DefaultFormats = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
    {
        "ExcludeClipboardContentFromMonitorProcessing",
        "Clipboard Viewer Ignore",
    };

    public IReadOnlySet<string> IgnoredFormats { get; init; } = DefaultFormats;
    /// <summary>Executable names (such as "KeePass.exe") whose copies are never recorded.</summary>
    public IReadOnlySet<string> IgnoredApps { get; init; } = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
    /// <summary>Kinds of content that are recorded. Everything else is skipped.</summary>
    public IReadOnlySet<ClipKind> RecordedKinds { get; init; } = new HashSet<ClipKind>(Enum.GetValues<ClipKind>());
    /// <summary>Honor the Windows "CanIncludeInClipboardHistory = 0" opt-out set by the source app.</summary>
    public bool HonorHistoryOptOut { get; init; } = true;

    /// <param name="formats">Names of the formats on the clipboard.</param>
    /// <param name="sourceApp">Executable name of the app that copied, if known.</param>
    /// <param name="historyOptOut">True when the clipboard has CanIncludeInClipboardHistory set to 0.</param>
    public bool ShouldIgnore(IEnumerable<string> formats, string? sourceApp, bool historyOptOut = false)
    {
        if (sourceApp is not null && IgnoredApps.Contains(sourceApp)) return true;
        if (HonorHistoryOptOut && historyOptOut) return true;
        return formats.Any(IgnoredFormats.Contains);
    }

    public bool ShouldRecord(ClipKind kind) => RecordedKinds.Contains(kind);
}
