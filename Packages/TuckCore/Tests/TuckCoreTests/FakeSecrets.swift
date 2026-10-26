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

    // Built in plain loops: older Swift compilers time out type-checking these as one chained expression.

    /// A generated-looking password: lower, upper and digit in turn (24 characters).
    static let randomPassword: String = {
        var result = ""
        for i in 0..<8 {
            result += letter("a", offset: i * 3 % 26)
            result += letter("B", offset: i * 5 % 25)
            result += String((i * 7 + 3) % 10)
        }
        return result
    }()

    /// Like `randomPassword` but with symbols (16 characters).
    static let randomPasswordWithSymbols: String = {
        let symbols: [Character] = ["#", "$", "%", "&"]
        var result = ""
        for i in 0..<4 {
            result += letter("X", offset: -5 * i)
            result += letter("k", offset: 3 * i)
            result += String((3 * i + 9) % 10)
            result.append(symbols[i])
        }
        return result
    }()

    private static func letter(_ base: Character, offset: Int) -> String {
        String(UnicodeScalar(UInt8(Int(base.asciiValue!) + offset)))
    }
}
