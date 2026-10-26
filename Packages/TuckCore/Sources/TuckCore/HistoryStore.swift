import Foundation

/// Thread-safe clipboard history with duplicate merging, pinning and a size limit.
/// Optionally persists to a file readable only by the current user, encrypted
/// when a cipher is given. Items with an expiry date are kept in memory only.
public final class HistoryStore: @unchecked Sendable {
    public enum LoadResult: Equatable, Sendable {
        /// No file yet, or nothing to persist to.
        case empty
        case loaded
        /// A plain-text history file was read and rewritten encrypted.
        case migrated
        /// The file could not be read (wrong key or damaged). It was moved to
        /// `movedTo` and history starts empty, so nothing is overwritten.
        case unreadable(movedTo: URL)
    }

    private let lock = NSLock()
    private var storage: [ClipItem] = []
    private var limit: Int
    private let fileURL: URL?
    private let cipher: HistoryCipher?
    public let loadResult: LoadResult

    public init(maxItems: Int = 200, fileURL: URL? = nil, cipher: HistoryCipher? = nil) {
        self.limit = max(1, maxItems)
        self.fileURL = fileURL
        self.cipher = cipher

        guard let fileURL, let data = try? Data(contentsOf: fileURL) else {
            loadResult = .empty
            return
        }
        let decoder = JSONDecoder()
        if let cipher, let plaintext = try? cipher.open(data),
           let decoded = try? decoder.decode([ClipItem].self, from: plaintext) {
            storage = decoded
            loadResult = .loaded
        } else if let decoded = try? decoder.decode([ClipItem].self, from: data) {
            storage = decoded
            if cipher != nil {
                loadResult = .migrated
                lock.withLock { persistLocked() }
            } else {
                loadResult = .loaded
            }
        } else {
            let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
            let aside = fileURL.deletingPathExtension()
                .appendingPathExtension("unreadable-\(stamp)")
                .appendingPathExtension(fileURL.pathExtension)
            try? FileManager.default.moveItem(at: fileURL, to: aside)
            loadResult = .unreadable(movedTo: aside)
        }
    }

    /// Pinned items first, then newest first.
    public var items: [ClipItem] {
        lock.withLock { Self.ordered(storage) }
    }

    public var maxItems: Int {
        lock.withLock { limit }
    }

    /// Adds an item. A duplicate (same content) is merged into the existing entry,
    /// which keeps its id and pin state and moves to the top.
    @discardableResult
    public func add(_ item: ClipItem) -> ClipItem {
        lock.withLock {
            let stored: ClipItem
            if let index = storage.firstIndex(where: { $0.fingerprint == item.fingerprint }) {
                var existing = storage[index]
                existing.createdAt = max(existing.createdAt, item.createdAt)
                if let app = item.sourceApp { existing.sourceApp = app }
                existing.secretKind = item.secretKind
                existing.expiresAt = item.expiresAt
                storage[index] = existing
                stored = existing
            } else {
                storage.append(item)
                stored = item
            }
            trimLocked()
            persistLocked()
            return stored
        }
    }

    /// Moves an existing item to the top (for example after pasting it).
    public func touch(_ id: UUID, at date: Date = Date()) {
        lock.withLock {
            guard let index = storage.firstIndex(where: { $0.id == id }) else { return }
            storage[index].createdAt = date
            persistLocked()
        }
    }

    public func delete(_ id: UUID) {
        lock.withLock {
            storage.removeAll { $0.id == id }
            persistLocked()
        }
    }

    /// Toggles the pin and returns the new state (`false` if the id is unknown).
    @discardableResult
    public func togglePin(_ id: UUID) -> Bool {
        lock.withLock {
            guard let index = storage.firstIndex(where: { $0.id == id }) else { return false }
            storage[index].isPinned.toggle()
            let pinned = storage[index].isPinned
            trimLocked()
            persistLocked()
            return pinned
        }
    }

    public func clearUnpinned() {
        lock.withLock {
            storage.removeAll { !$0.isPinned }
            persistLocked()
        }
    }

    /// Removes items whose `expiresAt` has passed and, when `maxAge` is set,
    /// unpinned items older than that. Returns `true` if anything was removed.
    @discardableResult
    public func prune(now: Date = Date(), maxAge: TimeInterval? = nil) -> Bool {
        lock.withLock {
            let before = storage.count
            storage.removeAll { item in
                if let expiresAt = item.expiresAt, expiresAt <= now { return true }
                if let maxAge, !item.isPinned, now.timeIntervalSince(item.createdAt) > maxAge { return true }
                return false
            }
            guard storage.count != before else { return false }
            persistLocked()
            return true
        }
    }

    public func setMaxItems(_ value: Int) {
        lock.withLock {
            limit = max(1, value)
            trimLocked()
            persistLocked()
        }
    }

    // MARK: - Private

    private static func ordered(_ items: [ClipItem]) -> [ClipItem] {
        items.sorted { a, b in
            if a.isPinned != b.isPinned { return a.isPinned }
            return a.createdAt > b.createdAt
        }
    }

    /// Drops the oldest unpinned items beyond the limit. Pinned items are never dropped.
    private func trimLocked() {
        let unpinned = storage.filter { !$0.isPinned }.sorted { $0.createdAt > $1.createdAt }
        guard unpinned.count > limit else { return }
        let doomed = Set(unpinned.dropFirst(limit).map(\.id))
        storage.removeAll { doomed.contains($0.id) }
    }

    private func persistLocked() {
        guard let fileURL else { return }
        // Expiring items (hidden secrets) never touch the disk.
        let durable = storage.filter { $0.expiresAt == nil }
        guard var data = try? JSONEncoder().encode(durable) else { return }
        if let cipher {
            guard let sealed = try? cipher.seal(data) else { return }
            data = sealed
        }
        try? data.write(to: fileURL, options: .atomic)
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: fileURL.path
        )
    }
}
