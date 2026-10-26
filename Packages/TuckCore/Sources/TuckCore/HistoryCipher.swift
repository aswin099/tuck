import CryptoKit
import Foundation

/// Encrypts the history file. The app supplies a key kept in the Keychain.
public protocol HistoryCipher: Sendable {
    func seal(_ plaintext: Data) throws -> Data
    func open(_ ciphertext: Data) throws -> Data
}

/// AES-256-GCM. The output is nonce, ciphertext and tag in one blob, so any
/// change to the file makes `open` fail instead of returning altered history.
/// `@unchecked` because older SDKs don't mark `SymmetricKey` as Sendable; it is
/// an immutable value, so sharing it across threads is safe.
public struct AESGCMCipher: HistoryCipher, @unchecked Sendable {
    private let key: SymmetricKey

    public init(key: SymmetricKey) {
        self.key = key
    }

    public func seal(_ plaintext: Data) throws -> Data {
        guard let combined = try AES.GCM.seal(plaintext, using: key).combined else {
            throw CocoaError(.coderInvalidValue)
        }
        return combined
    }

    public func open(_ ciphertext: Data) throws -> Data {
        try AES.GCM.open(AES.GCM.SealedBox(combined: ciphertext), using: key)
    }
}
