namespace Tuck.Core;

/// <summary>Items waiting to be pasted one at a time, oldest first.</summary>
public sealed class PasteQueue
{
    private readonly List<ClipItem> _items = [];

    public IReadOnlyList<ClipItem> Items => _items;
    public bool IsEmpty => _items.Count == 0;
    public int Count => _items.Count;

    /// <summary>Adds an item to the back. An item already queued is not added twice.</summary>
    public void Enqueue(ClipItem item)
    {
        if (_items.Any(i => i.Fingerprint == item.Fingerprint)) return;
        _items.Add(item);
    }

    /// <summary>Removes and returns the front item.</summary>
    public ClipItem? Next()
    {
        if (_items.Count == 0) return null;
        var first = _items[0];
        _items.RemoveAt(0);
        return first;
    }

    public void Remove(Guid id) => _items.RemoveAll(i => i.Id == id);

    public void Clear() => _items.Clear();

    /// <summary>1-based position of the item in the queue, matched by content.</summary>
    public int? PositionOf(ClipItem item)
    {
        var index = _items.FindIndex(i => i.Fingerprint == item.Fingerprint);
        return index < 0 ? null : index + 1;
    }
}
