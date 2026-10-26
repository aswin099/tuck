/// Fake credentials for testing the secret detector. They are assembled at run time
/// so the source never contains a string that secret scanners (GitHub, GitGuardian)
/// report as a leaked credential. None of them is a real key or token.
enum FakeSecrets {
    /// AWS's own documentation example key ID.
    static let awsKey = "AKIA" + "IOSFODNN7" + "EXAMPLE"

    static let slackToken = "xox" + "b-" + "1234567890-abcdefghij"

    static let privateKeyHeader = "-----BEGIN " + "OPENSSH PRIVATE KEY" + "-----\nabc\n"

    /// Header {"alg":"HS256"}, payload {"sub":"1234567890"}, made-up signature.
    static let jwt = [
        "eyJ" + "hbGciOiJIUzI1NiJ9",
        "eyJ" + "zdWIiOiIxMjM0NTY3ODkwIn0",
        "fake" + "Signature" + "ForTests",
    ].joined(separator: ".")

    /// A generated-looking password: lower, upper and digit in turn (24 characters).
    static let randomPassword = (0..<8).map { i in
        letter("a", offset: i * 3 % 26) + letter("B", offset: i * 5 % 25) + String((i * 7 + 3) % 10)
    }.joined()

    /// Like `randomPassword` but with symbols (16 characters).
    static let randomPasswordWithSymbols = (0..<4).map { i in
        letter("X", offset: -i * 5) + letter("k", offset: i * 3) + String((i * 3 + 9) % 10)
            + String(Array("#$%&")[i])
    }.joined()

    private static func letter(_ base: Character, offset: Int) -> String {
        String(UnicodeScalar(UInt8(Int(base.asciiValue!) + offset)))
    }
}
