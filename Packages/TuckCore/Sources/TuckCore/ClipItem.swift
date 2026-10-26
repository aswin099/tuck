import Foundation

public enum ClipKind: String, Codable, Sendable, CaseIterable {
    case text
    case link
    case image
    case file
}

/// One entry in the clipboard history.
public struct ClipItem: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var kind: ClipKind
    /// Plain text (or newline-separated file paths for `.file`). Used for search and paste.
    public var text: String?
    /// Raw payload for images.
    public var data: Data?
    /// Bundle identifier of the app the item was copied from, when known.
    public var sourceApp: String?
    public var createdAt: Date
    public var isPinned: Bool
    /// Set when the text looks like a password, key or token.
    public var secretKind: SecretDetector.Kind?
    /// When set, the item is removed from history after this date (even if pinned).
    public var expiresAt: Date?
    /// Content hash used to merge duplicates. Not a security hash.
    public let fingerprint: String

    public init(
        id: UUID = UUID(),
        kind: ClipKind,
        text: String? = nil,
        data: Data? = nil,
        sourceApp: String? = nil,
        createdAt: Date = Date(),
        isPinned: Bool = false,
        secretKind: SecretDetector.Kind? = nil,
        expiresAt: Date? = nil
    ) {
        self.id = id
        self.kind = kind
        self.text = text
        self.data = data
        self.sourceApp = sourceApp
        self.createdAt = createdAt
        self.isPinned = isPinned
        self.secretKind = secretKind
        self.expiresAt = expiresAt
        self.fingerprint = Fingerprint.make(kind: kind, text: text, data: data)
    }

    public var isSecret: Bool { secretKind != nil }

    /// Short single-line description for list rows.
    public var preview: String {
        if kind == .image { return "Image" }
        let trimmed = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let lines = trimmed.split(whereSeparator: \.isNewline).prefix(2).joined(separator: " ")
        return lines.isEmpty ? "(empty)" : String(lines.prefix(300))
    }
}

enum Fingerprint {
    /// FNV-1a 64-bit over kind, text and data.
    static func make(kind: ClipKind, text: String?, data: Data?) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        let prime: UInt64 = 0x0000_0100_0000_01b3

        func mix(_ byte: UInt8) {
            hash ^= UInt64(byte)
            hash = hash &* prime
        }

        for byte in kind.rawValue.utf8 { mix(byte) }
        mix(0)
        if let text { for byte in text.utf8 { mix(byte) } }
        mix(0)
        if let data { for byte in data { mix(byte) } }
        return String(hash, radix: 16)
    }
}
