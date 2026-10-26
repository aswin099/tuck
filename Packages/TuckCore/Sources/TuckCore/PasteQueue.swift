import Foundation

/// Items waiting to be pasted one at a time, oldest first.
public struct PasteQueue: Equatable, Sendable {
    public private(set) var items: [ClipItem] = []

    public init(items: [ClipItem] = []) {
        self.items = items
    }

    public var isEmpty: Bool { items.isEmpty }
    public var count: Int { items.count }

    /// Adds an item to the back. An item already queued is not added twice.
    public mutating func enqueue(_ item: ClipItem) {
        guard !items.contains(where: { $0.fingerprint == item.fingerprint }) else { return }
        items.append(item)
    }

    /// Removes and returns the front item.
    public mutating func next() -> ClipItem? {
        items.isEmpty ? nil : items.removeFirst()
    }

    public mutating func remove(_ id: UUID) {
        items.removeAll { $0.id == id }
    }

    public mutating func clear() {
        items.removeAll()
    }

    /// 1-based position of the item in the queue, matched by content.
    public func position(of item: ClipItem) -> Int? {
        items.firstIndex { $0.fingerprint == item.fingerprint }.map { $0 + 1 }
    }
}
