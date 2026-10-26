using System.Text.Json;

namespace Tuck.Core;

public enum LoadStatus
{
    /// <summary>No file yet, or nothing to persist to.</summary>
    Empty,
    Loaded,
    /// <summary>A plain-text history file was read and rewritten encrypted.</summary>
    Migrated,
    /// <summary>The file could not be read (wrong key or damaged). It was moved aside and history starts empty.</summary>
    Unreadable,
}

/// <summary>
/// Thread-safe clipboard history with duplicate merging, pinning and a size limit.
/// Optionally persists to a file, encrypted when a cipher is given. Items with an
/// expiry time are kept in memory only.
/// </summary>
public sealed class HistoryStore
{
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);

    private readonly Lock _lock = new();
    private readonly List<ClipItem> _storage = [];
    private readonly string? _filePath;
    private readonly IHistoryCipher? _cipher;
    private int _limit;

    public LoadStatus LoadStatus { get; }
    /// <summary>Where an unreadable file was moved, when <see cref="LoadStatus"/> is Unreadable.</summary>
    public string? MovedAsidePath { get; }

    public HistoryStore(int maxItems = 200, string? filePath = null, IHistoryCipher? cipher = null)
    {
        _limit = Math.Max(1, maxItems);
        _filePath = filePath;
        _cipher = cipher;

        if (filePath is null || !File.Exists(filePath))
        {
            LoadStatus = LoadStatus.Empty;
            return;
        }

        var data = File.ReadAllBytes(filePath);
        if (cipher is not null && TryOpen(cipher, data) is { } decrypted && TryDecode(decrypted) is { } items)
        {
            _storage.AddRange(items);
            LoadStatus = LoadStatus.Loaded;
        }
        else if (TryDecode(data) is { } plainItems)
        {
            _storage.AddRange(plainItems);
            if (cipher is not null)
            {
                LoadStatus = LoadStatus.Migrated;
                lock (_lock) PersistLocked();
            }
            else
            {
                LoadStatus = LoadStatus.Loaded;
            }
        }
        else
        {
            var stamp = DateTimeOffset.Now.ToString("yyyy-MM-ddTHH-mm-ss");
            var aside = Path.Combine(
                Path.GetDirectoryName(filePath) ?? ".",
                $"{Path.GetFileNameWithoutExtension(filePath)}.unreadable-{stamp}{Path.GetExtension(filePath)}");
            try { File.Move(filePath, aside); } catch (IOException) { }
            MovedAsidePath = aside;
            LoadStatus = LoadStatus.Unreadable;
        }
    }

    /// <summary>Pinned items first, then newest first.</summary>
    public IReadOnlyList<ClipItem> Items
    {
        get { lock (_lock) return Ordered(_storage); }
    }

    public int MaxItems
    {
        get { lock (_lock) return _limit; }
    }

    /// <summary>
    /// Adds an item. A duplicate (same content) is merged into the existing entry,
    /// which keeps its id and pin state and moves to the top.
    /// </summary>
    public ClipItem Add(ClipItem item)
    {
        lock (_lock)
        {
            ClipItem stored;
            var index = _storage.FindIndex(i => i.Fingerprint == item.Fingerprint);
            if (index >= 0)
            {
                var existing = _storage[index];
                if (item.CreatedAt > existing.CreatedAt) existing.CreatedAt = item.CreatedAt;
                if (item.SourceApp is not null)
                {
                    existing.SourceApp = item.SourceApp;
                    existing.SourceAppPath = item.SourceAppPath;
                }
                existing.SecretKind = item.SecretKind;
                existing.ExpiresAt = item.ExpiresAt;
                stored = existing;
            }
            else
            {
                _storage.Add(item);
                stored = item;
            }
            TrimLocked();
            PersistLocked();
            return stored;
        }
    }

    /// <summary>Moves an existing item to the top (for example after pasting it).</summary>
    public void Touch(Guid id, DateTimeOffset? at = null)
    {
        lock (_lock)
        {
            var item = _storage.Find(i => i.Id == id);
            if (item is null) return;
            item.CreatedAt = at ?? DateTimeOffset.Now;
            PersistLocked();
        }
    }

    public void Delete(Guid id)
    {
        lock (_lock)
        {
            _storage.RemoveAll(i => i.Id == id);
            PersistLocked();
        }
    }

    /// <summary>Toggles the pin and returns the new state (false if the id is unknown).</summary>
    public bool TogglePin(Guid id)
    {
        lock (_lock)
        {
            var item = _storage.Find(i => i.Id == id);
            if (item is null) return false;
            item.IsPinned = !item.IsPinned;
            TrimLocked();
            PersistLocked();
            return item.IsPinned;
        }
    }

    public void ClearUnpinned()
    {
        lock (_lock)
        {
            _storage.RemoveAll(i => !i.IsPinned);
            PersistLocked();
        }
    }

    /// <summary>
    /// Removes items whose expiry has passed and, when <paramref name="maxAge"/> is set,
    /// unpinned items older than that. Returns true if anything was removed.
    /// </summary>
    public bool Prune(DateTimeOffset? now = null, TimeSpan? maxAge = null)
    {
        var current = now ?? DateTimeOffset.Now;
        lock (_lock)
        {
            var removed = _storage.RemoveAll(item =>
                (item.ExpiresAt is { } expires && expires <= current)
                || (maxAge is { } age && !item.IsPinned && current - item.CreatedAt > age));
            if (removed == 0) return false;
            PersistLocked();
            return true;
        }
    }

    public void SetMaxItems(int value)
    {
        lock (_lock)
        {
            _limit = Math.Max(1, value);
            TrimLocked();
            PersistLocked();
        }
    }

    private static List<ClipItem> Ordered(IEnumerable<ClipItem> items) =>
        items.OrderByDescending(i => i.IsPinned).ThenByDescending(i => i.CreatedAt).ToList();

    /// <summary>Drops the oldest unpinned items beyond the limit. Pinned items are never dropped.</summary>
    private void TrimLocked()
    {
        var doomed = _storage.Where(i => !i.IsPinned)
            .OrderByDescending(i => i.CreatedAt)
            .Skip(_limit)
            .Select(i => i.Id)
            .ToHashSet();
        if (doomed.Count > 0) _storage.RemoveAll(i => doomed.Contains(i.Id));
    }

    private void PersistLocked()
    {
        if (_filePath is null) return;
        // Expiring items (hidden secrets) never touch the disk.
        var durable = _storage.Where(i => i.ExpiresAt is null).ToList();
        var data = JsonSerializer.SerializeToUtf8Bytes(durable, Json);
        if (_cipher is not null)
        {
            try { data = _cipher.Seal(data); }
            catch (Exception) { return; } // Never fall back to writing plain text.
        }
        var temp = _filePath + ".tmp";
        try
        {
            File.WriteAllBytes(temp, data);
            File.Move(temp, _filePath, overwrite: true);
        }
        catch (IOException)
        {
            // Disk full or file locked: keep the in-memory history and try again on the next change.
        }
    }

    private static byte[]? TryOpen(IHistoryCipher cipher, byte[] data)
    {
        try { return cipher.Open(data); }
        catch (Exception) { return null; }
    }

    private static List<ClipItem>? TryDecode(byte[] data)
    {
        try { return JsonSerializer.Deserialize<List<ClipItem>>(data, Json); }
        catch (JsonException) { return null; }
    }
}
