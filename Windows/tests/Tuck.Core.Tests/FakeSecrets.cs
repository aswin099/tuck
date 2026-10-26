namespace Tuck.Core.Tests;

/// <summary>
/// Fake credentials for testing the secret detector. They are assembled at run time
/// so the source never contains a string that secret scanners (GitHub, GitGuardian)
/// report as a leaked credential. None of them is a real key or token.
/// </summary>
internal static class FakeSecrets
{
    /// <summary>AWS's own documentation example key ID.</summary>
    public static readonly string AwsKey = "AKIA" + "IOSFODNN7" + "EXAMPLE";

    public static readonly string SlackToken = "xox" + "b-" + "1234567890-abcdefghij";

    public static readonly string PrivateKeyHeader = "-----BEGIN " + "OPENSSH PRIVATE KEY" + "-----\nabc\n";

    /// <summary>Header {"alg":"HS256"}, payload {"sub":"1234567890"}, made-up signature.</summary>
    public static readonly string Jwt = string.Join(".",
        "eyJ" + "hbGciOiJIUzI1NiJ9",
        "eyJ" + "zdWIiOiIxMjM0NTY3ODkwIn0",
        "fake" + "Signature" + "ForTests");

    /// <summary>A generated-looking password: lower, upper and digit in turn (24 characters).</summary>
    public static readonly string RandomPassword = string.Concat(Enumerable.Range(0, 8).Select(i =>
        $"{(char)('a' + i * 3 % 26)}{(char)('B' + i * 5 % 25)}{(i * 7 + 3) % 10}"));

    /// <summary>Like <see cref="RandomPassword"/> but with symbols (16 characters).</summary>
    public static readonly string RandomPasswordWithSymbols = string.Concat(Enumerable.Range(0, 4).Select(i =>
        $"{(char)('X' - i * 5)}{(char)('k' + i * 3)}{(i * 3 + 9) % 10}{"#$%&"[i]}"));
}
