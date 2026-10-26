import Foundation

/// Spots copied text that looks like a credential, so the app can skip it, hide it
/// or let it expire. Runs fully on device; nothing is sent anywhere.
public enum SecretDetector {
    public enum Kind: String, Codable, Sendable, CaseIterable {
        case privateKey
        case awsKey
        case githubToken
        case slackToken
        case stripeKey
        case aiApiKey
        case googleApiKey
        case jwt
        case cardNumber
        case randomToken

        public var label: String {
            switch self {
            case .privateKey: return "Private key"
            case .awsKey: return "AWS access key"
            case .githubToken: return "GitHub token"
            case .slackToken: return "Slack token"
            case .stripeKey: return "Stripe key"
            case .aiApiKey: return "API key"
            case .googleApiKey: return "Google API key"
            case .jwt: return "Access token"
            case .cardNumber: return "Card number"
            case .randomToken: return "Password or token"
            }
        }
    }

    private static let patterns: [(Kind, NSRegularExpression)] = [
        (.privateKey, #"-----BEGIN (?:[A-Z]+ )*PRIVATE KEY-----"#),
        (.awsKey, #"\b(?:AKIA|ASIA)[0-9A-Z]{16}\b"#),
        (.githubToken, #"\b(?:gh[pousr]_[A-Za-z0-9]{36,}|github_pat_[A-Za-z0-9_]{60,})\b"#),
        (.slackToken, #"\bxox[abprs]-[A-Za-z0-9-]{10,}\b"#),
        (.stripeKey, #"\b(?:sk|rk)_live_[A-Za-z0-9]{20,}\b"#),
        (.aiApiKey, #"\bsk-(?:ant-|proj-)?[A-Za-z0-9_-]{32,}\b"#),
        (.googleApiKey, #"\bAIza[0-9A-Za-z_-]{35}\b"#),
        (.jwt, #"\beyJ[A-Za-z0-9_-]{8,}\.eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\b"#),
    ].map { kind, pattern in
        // The patterns are constants, so a failure here is a programming error.
        (kind, try! NSRegularExpression(pattern: pattern))
    }

    /// Returns what the text looks like, or `nil` if it looks like ordinary text.
    /// `includeRandomTokens` also flags single random-looking strings (generated
    /// passwords, unlabelled keys); it is stricter about length and mix to avoid
    /// flagging hashes, UUIDs and URLs.
    public static func detect(_ text: String, includeRandomTokens: Bool = true) -> Kind? {
        let range = NSRange(text.startIndex..., in: text)
        for (kind, regex) in patterns where regex.firstMatch(in: text, range: range) != nil {
            return kind
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if isCardNumber(trimmed) { return .cardNumber }
        if includeRandomTokens, isRandomToken(trimmed) { return .randomToken }
        return nil
    }

    /// 13–19 digits (spaces or dashes allowed between groups) passing the Luhn check.
    static func isCardNumber(_ text: String) -> Bool {
        guard text.count <= 23,
              text.allSatisfy({ $0.isNumber || $0 == " " || $0 == "-" }) else { return false }
        let digits = text.compactMap(\.wholeNumberValue)
        guard (13...19).contains(digits.count) else { return false }
        var sum = 0
        for (offset, digit) in digits.reversed().enumerated() {
            if offset.isMultiple(of: 2) {
                sum += digit
            } else {
                let doubled = digit * 2
                sum += doubled > 9 ? doubled - 9 : doubled
            }
        }
        return sum.isMultiple(of: 10)
    }

    /// A single 16–128 character string with no spaces that mixes upper case,
    /// lower case and digits (or symbols) and has high character entropy.
    static func isRandomToken(_ text: String) -> Bool {
        guard (16...128).contains(text.count),
              !text.contains(where: \.isWhitespace),
              !text.contains("://"), !text.hasPrefix("/"), !text.hasPrefix("~"),
              !text.contains("@") else { return false }
        if UUID(uuidString: text) != nil { return false }

        let hasUpper = text.contains(where: \.isUppercase)
        let hasLower = text.contains(where: \.isLowercase)
        let hasDigit = text.contains(where: \.isNumber)
        let hasSymbol = text.contains { !$0.isLetter && !$0.isNumber }
        guard hasUpper, hasLower, hasDigit || hasSymbol else { return false }
        // Names made of plain words and numbers joined by separators are not secrets.
        let segments = text.split(whereSeparator: { "-_.".contains($0) })
        if segments.count > 1, segments.allSatisfy(isPlainSegment) { return false }
        // Words and identifiers ("Report-Q3-2024-Final", "fetchUserName2") keep the same
        // character class for several characters in a row; random strings switch often.
        return classSwitchRatio(text) >= 0.45 && entropy(of: text) >= 3.5
    }

    /// A word ("final", "Final", "FINAL"), a number, or a short code like "Q3".
    private static func isPlainSegment(_ segment: Substring) -> Bool {
        if segment.count <= 2 { return true }
        if segment.allSatisfy(\.isNumber) { return true }
        guard segment.allSatisfy(\.isLetter) else { return false }
        let rest = segment.dropFirst()
        return rest.allSatisfy(\.isLowercase) || segment.allSatisfy(\.isUppercase)
    }

    /// Share of adjacent character pairs that change class (upper, lower, digit, other).
    static func classSwitchRatio(_ text: String) -> Double {
        func charClass(_ c: Character) -> Int {
            if c.isUppercase { return 0 }
            if c.isLowercase { return 1 }
            if c.isNumber { return 2 }
            return 3
        }
        let classes = text.map(charClass)
        guard classes.count > 1 else { return 0 }
        let switches = zip(classes, classes.dropFirst()).filter { $0 != $1 }.count
        return Double(switches) / Double(classes.count - 1)
    }

    /// Shannon entropy in bits per character.
    static func entropy(of text: String) -> Double {
        var counts: [Character: Int] = [:]
        for character in text { counts[character, default: 0] += 1 }
        let total = Double(text.count)
        return counts.values.reduce(0) { sum, count in
            let p = Double(count) / total
            return sum - p * log2(p)
        }
    }
}
