namespace Tuck.Core.Tests;

public class IgnoreRulesTests
{
    [Fact]
    public void PasswordManagerFormatIsIgnored() =>
        Assert.True(new IgnoreRules().ShouldIgnore(["CF_UNICODETEXT", "ExcludeClipboardContentFromMonitorProcessing"], "KeePass.exe"));

    [Fact]
    public void ClipboardViewerIgnoreIsIgnored() =>
        Assert.True(new IgnoreRules().ShouldIgnore(["Clipboard Viewer Ignore"], null));

    [Fact]
    public void HistoryOptOutIsHonored()
    {
        Assert.True(new IgnoreRules().ShouldIgnore(["CF_UNICODETEXT"], null, historyOptOut: true));
        Assert.False(new IgnoreRules { HonorHistoryOptOut = false }.ShouldIgnore(["CF_UNICODETEXT"], null, historyOptOut: true));
    }

    [Fact]
    public void IgnoredAppIsIgnoredCaseInsensitively()
    {
        var rules = new IgnoreRules { IgnoredApps = new HashSet<string>(["secret.exe"], StringComparer.OrdinalIgnoreCase) };
        Assert.True(rules.ShouldIgnore(["CF_UNICODETEXT"], "Secret.EXE"));
    }

    [Fact]
    public void OrdinaryCopyIsAllowed()
    {
        var rules = new IgnoreRules { IgnoredApps = new HashSet<string>(["secret.exe"], StringComparer.OrdinalIgnoreCase) };
        Assert.False(rules.ShouldIgnore(["CF_UNICODETEXT"], "chrome.exe"));
    }

    [Fact]
    public void AllKindsRecordedByDefault() =>
        Assert.All(Enum.GetValues<ClipKind>(), kind => Assert.True(new IgnoreRules().ShouldRecord(kind)));

    [Fact]
    public void DisabledKindIsSkipped()
    {
        var rules = new IgnoreRules { RecordedKinds = new HashSet<ClipKind>([ClipKind.Text, ClipKind.Link]) };
        Assert.False(rules.ShouldRecord(ClipKind.Image));
        Assert.True(rules.ShouldRecord(ClipKind.Link));
    }
}
