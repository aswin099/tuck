import XCTest
@testable import TuckCore

final class SecretDetectorTests: XCTestCase {
    func testKnownTokenFormats() {
        XCTAssertEqual(SecretDetector.detect(FakeSecrets.awsKey), .awsKey)
        XCTAssertEqual(SecretDetector.detect("ghp_" + String(repeating: "a1B2", count: 9)), .githubToken)
        XCTAssertEqual(SecretDetector.detect(FakeSecrets.slackToken), .slackToken)
        XCTAssertEqual(SecretDetector.detect("sk_live_" + String(repeating: "x9", count: 12)), .stripeKey)
        XCTAssertEqual(SecretDetector.detect("sk-ant-" + String(repeating: "Ab3_", count: 10)), .aiApiKey)
        XCTAssertEqual(SecretDetector.detect("AIza" + String(repeating: "B", count: 35)), .googleApiKey)
        XCTAssertEqual(SecretDetector.detect(FakeSecrets.jwt), .jwt)
        XCTAssertEqual(SecretDetector.detect(FakeSecrets.privateKeyHeader), .privateKey)
    }

    func testTokenInsideLongerTextIsFound() {
        XCTAssertEqual(SecretDetector.detect("export AWS_KEY=" + FakeSecrets.awsKey), .awsKey)
    }

    func testCardNumberNeedsValidLuhn() {
        XCTAssertEqual(SecretDetector.detect("4111 1111 1111 1111"), .cardNumber)
        XCTAssertEqual(SecretDetector.detect("4111-1111-1111-1111"), .cardNumber)
        XCTAssertNil(SecretDetector.detect("4111 1111 1111 1112"))
        XCTAssertNil(SecretDetector.detect("12345"))
    }

    func testGeneratedPasswordIsFlagged() {
        XCTAssertEqual(SecretDetector.detect(FakeSecrets.randomPasswordWithSymbols), .randomToken)
        XCTAssertEqual(SecretDetector.detect(FakeSecrets.randomPassword), .randomToken)
        XCTAssertNil(SecretDetector.detect(FakeSecrets.randomPasswordWithSymbols, includeRandomTokens: false))
    }

    func testOrdinaryTextIsNotFlagged() {
        let samples = [
            "Hello, see you at 5pm",
            "https://example.com/Path/To/Page?id=42",
            "/Users/someone/Documents/Report.pdf",
            "Report-Q3-2024-Final",
            "NSPasteboardTypeString",
            "fetchUserName2",
            "3F2504E0-4F89-11D3-9A0C-0305E82C3301",
            "da39a3ee5e6b4b0d3255bfef95601890afd80709",
            "someone@example.com",
            "IMG_2024_0315.jpg",
            "+1 (555) 010-9999",
        ]
        for sample in samples {
            XCTAssertNil(SecretDetector.detect(sample), sample)
        }
    }
}
