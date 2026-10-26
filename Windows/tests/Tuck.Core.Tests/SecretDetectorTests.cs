namespace Tuck.Core.Tests;

public class SecretDetectorTests
{
    [Fact]
    public void KnownTokenFormats()
    {
        Assert.Equal(SecretKind.AwsKey, SecretDetector.Detect(FakeSecrets.AwsKey));
        Assert.Equal(SecretKind.SlackToken, SecretDetector.Detect(FakeSecrets.SlackToken));
        Assert.Equal(SecretKind.Jwt, SecretDetector.Detect(FakeSecrets.Jwt));
        Assert.Equal(SecretKind.PrivateKey, SecretDetector.Detect(FakeSecrets.PrivateKeyHeader));
    }

    [Fact]
    public void GeneratedTokenFormats()
    {
        Assert.Equal(SecretKind.GitHubToken, SecretDetector.Detect("ghp_" + string.Concat(Enumerable.Repeat("a1B2", 9))));
        Assert.Equal(SecretKind.StripeKey, SecretDetector.Detect("sk_live_" + string.Concat(Enumerable.Repeat("x9", 12))));
        Assert.Equal(SecretKind.AiApiKey, SecretDetector.Detect("sk-ant-" + string.Concat(Enumerable.Repeat("Ab3_", 10))));
        Assert.Equal(SecretKind.GoogleApiKey, SecretDetector.Detect("AIza" + new string('B', 35)));
    }

    [Fact]
    public void TokenInsideLongerTextIsFound() =>
        Assert.Equal(SecretKind.AwsKey, SecretDetector.Detect("set AWS_KEY=" + FakeSecrets.AwsKey));

    [Fact]
    public void CardNumberNeedsValidLuhn()
    {
        Assert.Equal(SecretKind.CardNumber, SecretDetector.Detect("4111 1111 1111 1111"));
        Assert.Equal(SecretKind.CardNumber, SecretDetector.Detect("4111-1111-1111-1111"));
        Assert.Null(SecretDetector.Detect("4111 1111 1111 1112"));
        Assert.Null(SecretDetector.Detect("12345"));
    }

    [Fact]
    public void GeneratedPasswordIsFlagged()
    {
        Assert.Equal(SecretKind.RandomToken, SecretDetector.Detect(FakeSecrets.RandomPasswordWithSymbols));
        Assert.Equal(SecretKind.RandomToken, SecretDetector.Detect(FakeSecrets.RandomPassword));
        Assert.Null(SecretDetector.Detect(FakeSecrets.RandomPasswordWithSymbols, includeRandomTokens: false));
    }

    [Theory]
    [InlineData("Hello, see you at 5pm")]
    [InlineData("https://example.com/Path/To/Page?id=42")]
    [InlineData("/Users/someone/Documents/Report.pdf")]
    [InlineData(@"C:\Users\someone\Documents\Report2024.pdf")]
    [InlineData("Report-Q3-2024-Final")]
    [InlineData("NSPasteboardTypeString")]
    [InlineData("fetchUserName2")]
    [InlineData("3F2504E0-4F89-11D3-9A0C-0305E82C3301")]
    [InlineData("da39a3ee5e6b4b0d3255bfef95601890afd80709")]
    [InlineData("someone@example.com")]
    [InlineData("IMG_2024_0315.jpg")]
    [InlineData("+1 (555) 010-9999")]
    public void OrdinaryTextIsNotFlagged(string text) => Assert.Null(SecretDetector.Detect(text));
}
