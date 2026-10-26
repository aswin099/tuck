import XCTest
@testable import TuckCore

final class IgnoreRulesTests: XCTestCase {
    func testConcealedTypeIsIgnored() {
        let rules = IgnoreRules()
        XCTAssertTrue(rules.shouldIgnore(
            pasteboardTypes: ["public.utf8-plain-text", "org.nspasteboard.ConcealedType"],
            sourceApp: "com.example.vault"
        ))
    }

    func testTransientTypeIsIgnored() {
        let rules = IgnoreRules()
        XCTAssertTrue(rules.shouldIgnore(
            pasteboardTypes: ["org.nspasteboard.TransientType"],
            sourceApp: nil
        ))
    }

    func testIgnoredAppIsIgnored() {
        let rules = IgnoreRules(ignoredApps: ["com.example.secret"])
        XCTAssertTrue(rules.shouldIgnore(
            pasteboardTypes: ["public.utf8-plain-text"],
            sourceApp: "com.example.secret"
        ))
    }

    func testOrdinaryCopyIsAllowed() {
        let rules = IgnoreRules(ignoredApps: ["com.example.secret"])
        XCTAssertFalse(rules.shouldIgnore(
            pasteboardTypes: ["public.utf8-plain-text"],
            sourceApp: "com.apple.Safari"
        ))
    }

    func testCustomTypeCanBeAdded() {
        var rules = IgnoreRules()
        rules.ignoredPasteboardTypes.insert("com.myapp.CustomType")
        XCTAssertTrue(rules.shouldIgnore(pasteboardTypes: ["com.myapp.CustomType"], sourceApp: nil))
    }
}

final class RecordedKindsTests: XCTestCase {
    func testAllKindsRecordedByDefault() {
        XCTAssertTrue(ClipKind.allCases.allSatisfy(IgnoreRules().shouldRecord))
    }

    func testDisabledKindIsSkipped() {
        let rules = IgnoreRules(recordedKinds: [.text, .link])
        XCTAssertFalse(rules.shouldRecord(.image))
        XCTAssertTrue(rules.shouldRecord(.link))
    }
}
