namespace Tuck.Core.Tests;

public class PasteQueueTests
{
    [Fact]
    public void FirstInFirstOut()
    {
        var queue = new PasteQueue();
        queue.Enqueue(ClipItem.Create(ClipKind.Text, "a"));
        queue.Enqueue(ClipItem.Create(ClipKind.Text, "b"));
        Assert.Equal("a", queue.Next()?.Text);
        Assert.Equal("b", queue.Next()?.Text);
        Assert.Null(queue.Next());
    }

    [Fact]
    public void SameContentIsQueuedOnce()
    {
        var queue = new PasteQueue();
        queue.Enqueue(ClipItem.Create(ClipKind.Text, "a"));
        queue.Enqueue(ClipItem.Create(ClipKind.Text, "a"));
        Assert.Equal(1, queue.Count);
    }

    [Fact]
    public void PositionAndRemove()
    {
        var queue = new PasteQueue();
        var a = ClipItem.Create(ClipKind.Text, "a");
        var b = ClipItem.Create(ClipKind.Text, "b");
        queue.Enqueue(a);
        queue.Enqueue(b);
        Assert.Equal(2, queue.PositionOf(b));
        queue.Remove(a.Id);
        Assert.Equal(1, queue.PositionOf(b));
        Assert.Null(queue.PositionOf(a));
    }
}
