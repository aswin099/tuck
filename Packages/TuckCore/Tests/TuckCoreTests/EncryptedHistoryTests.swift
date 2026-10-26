import CryptoKit
import XCTest
@testable import TuckCore

final class EncryptedHistoryTests: XCTestCase {
    private var dir: URL!
    private var fileURL: URL { dir.appendingPathComponent("history.tuck") }

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    private func cipher(_ key: SymmetricKey) -> AESGCMCipher { AESGCMCipher(key: key) }

    func testFileIsEncryptedAndReadsBackWithSameKey() throws {
        let key = SymmetricKey(size: .bits256)
        let store = HistoryStore(fileURL: fileURL, cipher: cipher(key))
        store.add(ClipItem(kind: .text, text: "my home address"))

        let raw = try Data(contentsOf: fileURL)
        XCTAssertNil(String(data: raw, encoding: .utf8).flatMap { $0.contains("home address") ? $0 : nil })
        XCTAssertThrowsError(try JSONDecoder().decode([ClipItem].self, from: raw))

        let reopened = HistoryStore(fileURL: fileURL, cipher: cipher(key))
        XCTAssertEqual(reopened.loadResult, .loaded)
        XCTAssertEqual(reopened.items.map(\.text), ["my home address"])
    }

    func testExpiringItemsStayInMemoryOnly() throws {
        let key = SymmetricKey(size: .bits256)
        let store = HistoryStore(fileURL: fileURL, cipher: cipher(key))
        store.add(ClipItem(kind: .text, text: "keep"))
        store.add(ClipItem(kind: .text, text: "secret", secretKind: .githubToken, expiresAt: Date().addingTimeInterval(300)))
        XCTAssertEqual(store.items.count, 2)

        let reopened = HistoryStore(fileURL: fileURL, cipher: cipher(key))
        XCTAssertEqual(reopened.items.map(\.text), ["keep"])
    }

    func testPlainTextHistoryIsMigrated() throws {
        let plain = HistoryStore(fileURL: fileURL)
        plain.add(ClipItem(kind: .text, text: "old item"))
        XCTAssertNoThrow(try JSONDecoder().decode([ClipItem].self, from: Data(contentsOf: fileURL)))

        let key = SymmetricKey(size: .bits256)
        let migrated = HistoryStore(fileURL: fileURL, cipher: cipher(key))
        XCTAssertEqual(migrated.loadResult, .migrated)
        XCTAssertEqual(migrated.items.map(\.text), ["old item"])
        XCTAssertThrowsError(try JSONDecoder().decode([ClipItem].self, from: Data(contentsOf: fileURL)))
        XCTAssertEqual(HistoryStore(fileURL: fileURL, cipher: cipher(key)).items.map(\.text), ["old item"])
    }

    func testWrongKeyMovesFileAsideInsteadOfOverwriting() throws {
        let store = HistoryStore(fileURL: fileURL, cipher: cipher(SymmetricKey(size: .bits256)))
        store.add(ClipItem(kind: .text, text: "precious"))
        let original = try Data(contentsOf: fileURL)

        let other = HistoryStore(fileURL: fileURL, cipher: cipher(SymmetricKey(size: .bits256)))
        guard case .unreadable(let aside) = other.loadResult else {
            return XCTFail("expected unreadable, got \(other.loadResult)")
        }
        XCTAssertTrue(other.items.isEmpty)
        XCTAssertEqual(try Data(contentsOf: aside), original)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }
}
