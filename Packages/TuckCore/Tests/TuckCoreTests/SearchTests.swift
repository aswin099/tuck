import XCTest
@testable import TuckCore

final class SearchTests: XCTestCase {
    private let items = [
        ClipItem(kind: .text, text: "Résumé draft for Monday", sourceApp: "com.apple.Pages"),
        ClipItem(kind: .link, text: "https://example.com/docs", sourceApp: "com.apple.Safari"),
        ClipItem(kind: .text, text: "ssh admin@server", sourceApp: "com.apple.Terminal"),
    ]

    func testEmptyQueryReturnsAll() {
        XCTAssertEqual(Search.filter(items, query: "").count, 3)
    }

    func testCaseAndDiacriticInsensitive() {
        let result = Search.filter(items, query: "RESUME")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.text, "Résumé draft for Monday")
    }

    func testAllTokensMustMatch() {
        XCTAssertEqual(Search.filter(items, query: "draft monday").count, 1)
        XCTAssertEqual(Search.filter(items, query: "draft server").count, 0)
    }

    func testKindFilter() {
        let result = Search.filter(items, query: "", kind: .link)
        XCTAssertEqual(result.map(\.kind), [.link])
    }

    func testSourceAppFilterAndQuery() {
        let result = Search.filter(items, query: "ssh", sourceApp: "com.apple.Terminal")
        XCTAssertEqual(result.count, 1)
    }

    func testSourceAppIsSearchable() {
        XCTAssertEqual(Search.filter(items, query: "safari").count, 1)
    }
}
