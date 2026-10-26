using System.Text.Json.Serialization;
using System.Text.RegularExpressions;

namespace Tuck.Core;

[JsonConverter(typeof(JsonStringEnumConverter<SecretKind>))]
public enum SecretKind
{
    PrivateKey,
    AwsKey,
    GitHubToken,
    SlackToken,
    StripeKey,
    AiApiKey,
    GoogleApiKey,
    Jwt,
    CardNumber,
    RandomToken,
}

public static class SecretKindExtensions
{
    public static string Label(this SecretKind kind) => kind switch
    {
        SecretKind.PrivateKey => "Private key",
        SecretKind.AwsKey => "AWS access key",
        SecretKind.GitHubToken => "GitHub token",
        SecretKind.SlackToken => "Slack token",
        SecretKind.StripeKey => "Stripe key",
        SecretKind.AiApiKey => "API key",
        SecretKind.GoogleApiKey => "Google API key",
        SecretKind.Jwt => "Access token",
        SecretKind.CardNumber => "Card number",
        SecretKind.RandomToken => "Password or token",
        _ => "Secret",
    };
}

/// <summary>
/// Spots copied text that looks like a credential, so the app can skip it, hide it
/// or let it expire. Runs fully on device; nothing is sent anywhere.
/// </summary>
public static class SecretDetector
{
    private static readonly (SecretKind Kind, Regex Pattern)[] Patterns =
    [
        (SecretKind.PrivateKey, new(@"-----BEGIN (?:[A-Z]+ )*PRIVATE KEY-----", RegexOptions.Compiled)),
        (SecretKind.AwsKey, new(@"\b(?:AKIA|ASIA)[0-9A-Z]{16}\b", RegexOptions.Compiled)),
        (SecretKind.GitHubToken, new(@"\b(?:gh[pousr]_[A-Za-z0-9]{36,}|github_pat_[A-Za-z0-9_]{60,})\b", RegexOptions.Compiled)),
        (SecretKind.SlackToken, new(@"\bxox[abprs]-[A-Za-z0-9-]{10,}\b", RegexOptions.Compiled)),
        (SecretKind.StripeKey, new(@"\b(?:sk|rk)_live_[A-Za-z0-9]{20,}\b", RegexOptions.Compiled)),
        (SecretKind.AiApiKey, new(@"\bsk-(?:ant-|proj-)?[A-Za-z0-9_-]{32,}\b", RegexOptions.Compiled)),
        (SecretKind.GoogleApiKey, new(@"\bAIza[0-9A-Za-z_-]{35}\b", RegexOptions.Compiled)),
        (SecretKind.Jwt, new(@"\beyJ[A-Za-z0-9_-]{8,}\.eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\b", RegexOptions.Compiled)),
    ];

    /// <summary>
    /// Returns what the text looks like, or null if it looks like ordinary text.
    /// <paramref name="includeRandomTokens"/> also flags single random-looking strings
    /// (generated passwords, unlabelled keys); it is strict about length and mix to
    /// avoid flagging hashes, GUIDs and URLs.
    /// </summary>
    public static SecretKind? Detect(string text, bool includeRandomTokens = true)
    {
        foreach (var (kind, pattern) in Patterns)
        {
            if (pattern.IsMatch(text)) return kind;
        }
        var trimmed = text.Trim();
        if (IsCardNumber(trimmed)) return SecretKind.CardNumber;
        if (includeRandomTokens && IsRandomToken(trimmed)) return SecretKind.RandomToken;
        return null;
    }

    /// <summary>13–19 digits (spaces or dashes allowed between groups) passing the Luhn check.</summary>
    internal static bool IsCardNumber(string text)
    {
        if (text.Length > 23 || !text.All(c => char.IsDigit(c) || c == ' ' || c == '-')) return false;
        var digits = text.Where(char.IsDigit).Select(c => c - '0').ToArray();
        if (digits.Length is < 13 or > 19) return false;
        var sum = 0;
        for (var offset = 0; offset < digits.Length; offset++)
        {
            var digit = digits[digits.Length - 1 - offset];
            if (offset % 2 == 0)
            {
                sum += digit;
            }
            else
            {
                var doubled = digit * 2;
                sum += doubled > 9 ? doubled - 9 : doubled;
            }
        }
        return sum % 10 == 0;
    }

    /// <summary>
    /// A single 16–128 character string with no spaces that mixes upper case,
    /// lower case and digits (or symbols) and has high character entropy.
    /// </summary>
    internal static bool IsRandomToken(string text)
    {
        if (text.Length is < 16 or > 128
            || text.Any(char.IsWhiteSpace)
            || text.Contains("://") || text.StartsWith('/') || text.StartsWith('~') || text.StartsWith('\\')
            || (text.Length > 2 && text[1] == ':' && text[2] == '\\')
            || text.Contains('@'))
        {
            return false;
        }
        if (Guid.TryParseExact(text, "D", out _)) return false;

        var hasUpper = text.Any(char.IsUpper);
        var hasLower = text.Any(char.IsLower);
        var hasDigit = text.Any(char.IsDigit);
        var hasSymbol = text.Any(c => !char.IsLetterOrDigit(c));
        if (!hasUpper || !hasLower || !(hasDigit || hasSymbol)) return false;

        // Names made of plain words and numbers joined by separators are not secrets.
        var segments = text.Split(['-', '_', '.'], StringSplitOptions.RemoveEmptyEntries);
        if (segments.Length > 1 && segments.All(IsPlainSegment)) return false;

        // Words and identifiers ("Report-Q3-2024-Final", "fetchUserName2") keep the same
        // character class for several characters in a row; random strings switch often.
        return ClassSwitchRatio(text) >= 0.45 && Entropy(text) >= 3.5;
    }

    /// <summary>A word ("final", "Final", "FINAL"), a number, or a short code like "Q3".</summary>
    private static bool IsPlainSegment(string segment)
    {
        if (segment.Length <= 2) return true;
        if (segment.All(char.IsDigit)) return true;
        if (!segment.All(char.IsLetter)) return false;
        return segment.Skip(1).All(char.IsLower) || segment.All(char.IsUpper);
    }

    /// <summary>Share of adjacent character pairs that change class (upper, lower, digit, other).</summary>
    internal static double ClassSwitchRatio(string text)
    {
        static int CharClass(char c) =>
            char.IsUpper(c) ? 0 : char.IsLower(c) ? 1 : char.IsDigit(c) ? 2 : 3;

        if (text.Length < 2) return 0;
        var switches = 0;
        for (var i = 1; i < text.Length; i++)
        {
            if (CharClass(text[i]) != CharClass(text[i - 1])) switches++;
        }
        return (double)switches / (text.Length - 1);
    }

    /// <summary>Shannon entropy in bits per character.</summary>
    internal static double Entropy(string text)
    {
        var total = (double)text.Length;
        return text.GroupBy(c => c)
            .Select(g => g.Count() / total)
            .Sum(p => -p * Math.Log2(p));
    }
}
