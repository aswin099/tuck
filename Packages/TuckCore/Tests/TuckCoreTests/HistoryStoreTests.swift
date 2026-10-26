import XCTest
@testable import TuckCore

final class HistoryStoreTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_000)

    private func text(_ value: String, at offset: TimeInterval = 0) -> ClipItem {
        ClipItem(kind: .text, text: value, createdAt: t0.addingTimeInterval(offset))
    }

    func testNewestFirst() {
        let store = HistoryStore()
        store.add(text("a", at: 0))
        store.add(text("b", at: 1))
        XCTAssertEqual(store.items.map(\.text), ["b", "a"])
    }

    func testDuplicateIsMergedAndMovesToTop() {
        let store = HistoryStore()
        let first = store.add(text("a", at: 0))
        store.add(text("b", at: 1))
        let again = store.add(text("a", at: 2))
        XCTAssertEqual(store.items.count, 2)
        XCTAssertEqual(store.items.first?.text, "a")
        XCTAssertEqual(again.id, first.id)
    }

    func testPinnedItemsStayOnTop() {
        let store = HistoryStore()
        let a = store.add(text("a", at: 0))
        store.add(text("b", at: 1))
        store.togglePin(a.id)
        store.add(text("c", at: 2))
        XCTAssertEqual(store.items.map(\.text), ["a", "c", "b"])
    }

    func testTrimDropsOldestUnpinnedOnly() {
        let store = HistoryStore(maxItems: 2)
        let pinned = store.add(text("p", at: 0))
        store.togglePin(pinned.id)
        store.add(text("x", at: 1))
        store.add(text("y", at: 2))
        store.add(text("z", at: 3))
        XCTAssertEqual(store.items.map(\.text), ["p", "z", "y"])
    }

    func testClearUnpinnedKeepsPins() {
        let store = HistoryStore()
        let a = store.add(text("a", at: 0))
        store.add(text("b", at: 1))
        store.togglePin(a.id)
        store.clearUnpinned()
        XCTAssertEqual(store.items.map(\.text), ["a"])
    }

    func testDeleteRemovesItem() {
        let store = HistoryStore()
        let a = store.add(text("a", at: 0))
        store.add(text("b", at: 1))
        store.delete(a.id)
        XCTAssertEqual(store.items.map(\.text), ["b"])
    }

    func testTouchMovesItemToTop() {
        let store = HistoryStore()
        let a = store.add(text("a", at: 0))
        store.add(text("b", at: 1))
        store.touch(a.id, at: t0.addingTimeInterval(5))
        XCTAssertEqual(store.items.first?.text, "a")
    }

    func testPersistenceRoundTrip() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: url) }

        let first = HistoryStore(fileURL: url)
        first.add(text("hello", at: 0))

        let second = HistoryStore(fileURL: url)
        XCTAssertEqual(second.items.map(\.text), ["hello"])
    }

    func testImageFingerprintDiffersByData() {
        let a = ClipItem(kind: .image, data: Data([1, 2, 3]))
        let b = ClipItem(kind: .image, data: Data([1, 2, 4]))
        XCTAssertNotEqual(a.fingerprint, b.fingerprint)
    }
}

final class HistoryStorePruneTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 10_000)

    func testExpiredItemsAreRemovedEvenIfPinned() {
        let store = HistoryStore()
        let secret = store.add(ClipItem(kind: .text, text: "s", createdAt: now, expiresAt: now.addingTimeInterval(60)))
        store.togglePin(secret.id)
        store.add(ClipItem(kind: .text, text: "keep", createdAt: now))

        XCTAssertFalse(store.prune(now: now.addingTimeInterval(30)))
        XCTAssertTrue(store.prune(now: now.addingTimeInterval(61)))
        XCTAssertEqual(store.items.map(\.text), ["keep"])
    }

    func testMaxAgeSparesPinnedItems() {
        let store = HistoryStore()
        let old = store.add(ClipItem(kind: .text, text: "old pinned", createdAt: now.addingTimeInterval(-500)))
        store.togglePin(old.id)
        store.add(ClipItem(kind: .text, text: "old", createdAt: now.addingTimeInterval(-500)))
        store.add(ClipItem(kind: .text, text: "new", createdAt: now.addingTimeInterval(-10)))

        store.prune(now: now, maxAge: 100)
        XCTAssertEqual(store.items.map(\.text), ["old pinned", "new"])
    }

    func testOldHistoryWithoutNewFieldsStillLoads() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: url) }
        let legacy = """
        [{"id":"\(UUID().uuidString)","kind":"text","text":"hi","createdAt":0,"isPinned":false,"fingerprint":"x"}]
        """
        try Data(legacy.utf8).write(to: url)
        let store = HistoryStore(fileURL: url)
        XCTAssertEqual(store.items.first?.text, "hi")
        XCTAssertNil(store.items.first?.secretKind)
    }
}
