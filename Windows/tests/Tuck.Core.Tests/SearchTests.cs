namespace Tuck.Core.Tests;

public class SearchTests
{
    private static readonly ClipItem[] Items =
    [
        ClipItem.Create(ClipKind.Text, "Hello World", sourceApp: "notepad.exe"),
        ClipItem.Create(ClipKind.Link, "https://example.com/café", sourceApp: "chrome.exe"),
        ClipItem.Create(ClipKind.Text, "Shopping list: eggs, milk", sourceApp: "chrome.exe"),
    ];

    [Fact]
    public void EmptyQueryReturnsAll() => Assert.Equal(3, Search.Filter(Items, "").Count);

    [Fact]
    public void AllTokensMustMatch()
    {
        Assert.Single(Search.Filter(Items, "hello world"));
        Assert.Empty(Search.Filter(Items, "hello milk"));
    }

    [Fact]
    public void CaseAndAccentInsensitive()
    {
        Assert.Single(Search.Filter(Items, "HELLO"));
        Assert.Single(Search.Filter(Items, "cafe"));
    }

    [Fact]
    public void KindFilter() => Assert.Single(Search.Filter(Items, "", kind: ClipKind.Link));

    [Fact]
    public void SourceAppIsSearchable() => Assert.Equal(2, Search.Filter(Items, "chrome").Count);

    [Fact]
    public void SourceAppFilterAndQuery() =>
        Assert.Single(Search.Filter(Items, "eggs", sourceApp: "CHROME.exe"));

    [Fact]
    public void SecretContentIsNotSearchable()
    {
        var secret = ClipItem.Create(ClipKind.Text, "hunter2-Xk9#mQ2$vL7p", secretKind: SecretKind.RandomToken);
        Assert.Empty(Search.Filter([secret], "hunter2"));
        Assert.Single(Search.Filter([secret], "password"));
    }
}
