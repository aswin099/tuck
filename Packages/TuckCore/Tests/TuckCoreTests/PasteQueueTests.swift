import XCTest
@testable import TuckCore

final class PasteQueueTests: XCTestCase {
    func testFirstInFirstOut() {
        var queue = PasteQueue()
        queue.enqueue(ClipItem(kind: .text, text: "a"))
        queue.enqueue(ClipItem(kind: .text, text: "b"))
        XCTAssertEqual(queue.next()?.text, "a")
        XCTAssertEqual(queue.next()?.text, "b")
        XCTAssertNil(queue.next())
    }

    func testSameContentIsQueuedOnce() {
        var queue = PasteQueue()
        queue.enqueue(ClipItem(kind: .text, text: "a"))
        queue.enqueue(ClipItem(kind: .text, text: "a"))
        XCTAssertEqual(queue.count, 1)
    }

    func testPositionAndRemove() {
        var queue = PasteQueue()
        let a = ClipItem(kind: .text, text: "a")
        let b = ClipItem(kind: .text, text: "b")
        queue.enqueue(a)
        queue.enqueue(b)
        XCTAssertEqual(queue.position(of: b), 2)
        queue.remove(a.id)
        XCTAssertEqual(queue.position(of: b), 1)
        XCTAssertNil(queue.position(of: a))
    }
}
