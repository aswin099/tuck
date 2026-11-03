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

    /// A history file as v0.1 wrote it, with a throwaway key. If this fails, the file format
    /// changed and an update would lose people's history: add a migration, don't edit this.
    func testHistorySavedByV01StillLoads() throws {
        let saved = "2CNjDe+ICZLeeeQNUeBHOmV4YPN7a1CkNsngrsCI78BgiczG3AaaUViRywUKxotKT1F2QXtRLQGkB4r+7wmfJ8iUdWnMhA0auJKiJy02sVYx127Nl3dUzdqNoEzfT2Tz8FEeX6QENOt91ykAseUplDptM+Eg39+TEAFSqsTHgxgtk/DosMP5KMRLP8QEGhfpfMQEjifTbp7VyzaBQWHC5aKssUoywDulqQByTH7luGBiirWz/2Tu8l8YlVUnIidOMg5a0e6CUCKm+IVfErAf4XWAaN0ivT6Sj0JEscIVIVcdOhx5t66FEZxwoglaNNx170hLRBQuxSpomwP5UuLYlptfxRF1bdMuJ8etZPahbHQLGJYzPKL6fn61nQt9R1GOZj33OKM0VbGcAdmx73oms5GvPEmpHhphfPO8JWfo/FnMxqjQfOVJzQtRqMiwJM/HCnTbMlyoppg9aOgNkXsynVF1s3WCoiHVlCSUy256oSRF5FwYVdsUBNudhj6/ZfNwQrPxNvYMS0AB++HWfbgZDBtfv6e4UlOhvcMh1VJPhSZ8lE+BJOZOhzCvmN+Zp5etRnzqBT9YMrqi4XtQaC0jc6DQ+oZcEaVRB5+95MZvpbS+w96hBnm26G2RFQqFNP/eoQENvpRnF8Jd9tF+nsAHfGEAGKI9Y7/99R4zLx7EFRzCHCL3FWvOYvHcI9cc1hf1xKYORfszATBpyhn/KgxbRM7Vt9J7S1H5LYUSUbO8O0Yii8jMZzhFvK6PODycObVPEMos/Yns2yZOy51eOBp9N3dhN8zGvyOwJ8uMl8UbvDAjrVQFYiZzy/f7NlswT2gWD9vOqUHgbCvP5kzXFGYWo1c3bF2EeQpj8NnnUDo8nxcmk7LUVZGPWJwIA3n6jXdDW52xrO7ii/sC0RcwVCZnS9oAZFKp8vbV8JDvKpEhPUAOtacyekpLlmySp7CkJoRuivy+wo5K7yywkf+ZEqvoQcknGWCHblSHJsU1QJNyfUwfpVnYkpTVxbPhuCm+znUHq0TOpFtrmpavihU1H5TtwzvrM8NUgrO9y5cV8G/9YPkoYSQJ8jzZg+N/GXPftNdx27ic5FgICK7+gcG/4LrcE75XmFVFDIK7UV5AZKYsc0vY8+VdIsXO"
        try XCTUnwrap(Data(base64Encoded: saved)).write(to: fileURL)

        let key = SymmetricKey(data: Data(repeating: 0x54, count: 32))
        let store = HistoryStore(fileURL: fileURL, cipher: cipher(key))

        XCTAssertEqual(store.loadResult, .loaded)
        XCTAssertEqual(store.items.map(\.kind), [.text, .text, .file, .image, .link])
        XCTAssertEqual(store.items.first?.text, "pinned note")
        XCTAssertEqual(store.items.first?.isPinned, true)
        XCTAssertEqual(store.items.first?.sourceApp, "com.apple.Notes")
        XCTAssertEqual(store.items[1].secretKind, .randomToken)
        XCTAssertEqual(store.items[3].data, Data([1, 2, 3]))
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
