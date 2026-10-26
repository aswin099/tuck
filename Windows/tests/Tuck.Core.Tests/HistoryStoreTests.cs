namespace Tuck.Core.Tests;

public class HistoryStoreTests
{
    private static readonly DateTimeOffset T0 = DateTimeOffset.FromUnixTimeSeconds(1_000);

    private static ClipItem Text(string value, double offset = 0) =>
        ClipItem.Create(ClipKind.Text, value, createdAt: T0.AddSeconds(offset));

    [Fact]
    public void NewestFirst()
    {
        var store = new HistoryStore();
        store.Add(Text("a", 0));
        store.Add(Text("b", 1));
        Assert.Equal(["b", "a"], store.Items.Select(i => i.Text));
    }

    [Fact]
    public void DuplicateIsMergedAndMovesToTop()
    {
        var store = new HistoryStore();
        var first = store.Add(Text("a", 0));
        store.Add(Text("b", 1));
        var again = store.Add(Text("a", 2));
        Assert.Equal(2, store.Items.Count);
        Assert.Equal("a", store.Items[0].Text);
        Assert.Equal(first.Id, again.Id);
    }

    [Fact]
    public void PinnedItemsStayOnTop()
    {
        var store = new HistoryStore();
        var a = store.Add(Text("a", 0));
        store.Add(Text("b", 1));
        store.TogglePin(a.Id);
        store.Add(Text("c", 2));
        Assert.Equal(["a", "c", "b"], store.Items.Select(i => i.Text));
    }

    [Fact]
    public void TrimDropsOldestUnpinnedOnly()
    {
        var store = new HistoryStore(maxItems: 2);
        var pinned = store.Add(Text("p", 0));
        store.TogglePin(pinned.Id);
        store.Add(Text("a", 1));
        store.Add(Text("b", 2));
        store.Add(Text("c", 3));
        Assert.Equal(["p", "c", "b"], store.Items.Select(i => i.Text));
    }

    [Fact]
    public void TouchMovesItemToTop()
    {
        var store = new HistoryStore();
        var a = store.Add(Text("a", 0));
        store.Add(Text("b", 1));
        store.Touch(a.Id, T0.AddSeconds(5));
        Assert.Equal("a", store.Items[0].Text);
    }

    [Fact]
    public void DeleteRemovesItem()
    {
        var store = new HistoryStore();
        var a = store.Add(Text("a"));
        store.Delete(a.Id);
        Assert.Empty(store.Items);
    }

    [Fact]
    public void ClearUnpinnedKeepsPins()
    {
        var store = new HistoryStore();
        var a = store.Add(Text("a", 0));
        store.Add(Text("b", 1));
        store.TogglePin(a.Id);
        store.ClearUnpinned();
        Assert.Equal(["a"], store.Items.Select(i => i.Text));
    }

    [Fact]
    public void ImageFingerprintDiffersByData()
    {
        var one = ClipItem.Create(ClipKind.Image, data: [1, 2, 3]);
        var two = ClipItem.Create(ClipKind.Image, data: [1, 2, 4]);
        Assert.NotEqual(one.Fingerprint, two.Fingerprint);
    }

    [Fact]
    public void PersistenceRoundTrip()
    {
        using var dir = new TempDir();
        var path = dir.File("history.json");
        var store = new HistoryStore(filePath: path);
        var a = store.Add(Text("a", 0));
        store.TogglePin(a.Id);
        store.Add(Text("b", 1));

        var reopened = new HistoryStore(filePath: path);
        Assert.Equal(["a", "b"], reopened.Items.Select(i => i.Text));
        Assert.True(reopened.Items[0].IsPinned);
    }
}

public class HistoryStorePruneTests
{
    private static readonly DateTimeOffset Now = DateTimeOffset.FromUnixTimeSeconds(10_000);

    [Fact]
    public void ExpiredItemsAreRemovedEvenIfPinned()
    {
        var store = new HistoryStore();
        var secret = store.Add(ClipItem.Create(ClipKind.Text, "s", createdAt: Now, expiresAt: Now.AddSeconds(60)));
        store.TogglePin(secret.Id);
        store.Add(ClipItem.Create(ClipKind.Text, "keep", createdAt: Now));

        Assert.False(store.Prune(Now.AddSeconds(30)));
        Assert.True(store.Prune(Now.AddSeconds(61)));
        Assert.Equal(["keep"], store.Items.Select(i => i.Text));
    }

    [Fact]
    public void MaxAgeSparesPinnedItems()
    {
        var store = new HistoryStore();
        var old = store.Add(ClipItem.Create(ClipKind.Text, "old pinned", createdAt: Now.AddSeconds(-500)));
        store.TogglePin(old.Id);
        store.Add(ClipItem.Create(ClipKind.Text, "old", createdAt: Now.AddSeconds(-500)));
        store.Add(ClipItem.Create(ClipKind.Text, "new", createdAt: Now.AddSeconds(-10)));

        store.Prune(Now, TimeSpan.FromSeconds(100));
        Assert.Equal(["old pinned", "new"], store.Items.Select(i => i.Text));
    }
}

internal sealed class TempDir : IDisposable
{
    public string Path { get; } = System.IO.Path.Combine(System.IO.Path.GetTempPath(), Guid.NewGuid().ToString());

    public TempDir() => Directory.CreateDirectory(Path);

    public string File(string name) => System.IO.Path.Combine(Path, name);

    public void Dispose()
    {
        try { Directory.Delete(Path, recursive: true); } catch (IOException) { }
    }
}
