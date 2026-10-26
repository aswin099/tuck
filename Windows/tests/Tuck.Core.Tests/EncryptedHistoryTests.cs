using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace Tuck.Core.Tests;

/// <summary>Stand-in for DPAPI (which only exists on Windows): AES-GCM with a fixed key.</summary>
internal sealed class TestCipher(byte[] key) : IHistoryCipher
{
    public static TestCipher Random() => new(RandomNumberGenerator.GetBytes(32));

    public byte[] Seal(byte[] plaintext)
    {
        using var aes = new AesGcm(key, 16);
        var nonce = RandomNumberGenerator.GetBytes(12);
        var cipher = new byte[plaintext.Length];
        var tag = new byte[16];
        aes.Encrypt(nonce, plaintext, cipher, tag);
        return [.. nonce, .. tag, .. cipher];
    }

    public byte[] Open(byte[] data)
    {
        using var aes = new AesGcm(key, 16);
        var plain = new byte[data.Length - 28];
        aes.Decrypt(data.AsSpan(0, 12), data.AsSpan(28), data.AsSpan(12, 16), plain);
        return plain;
    }
}

public class EncryptedHistoryTests
{
    [Fact]
    public void FileIsEncryptedAndReadsBackWithSameKey()
    {
        using var dir = new TempDir();
        var path = dir.File("history.tuck");
        var cipher = TestCipher.Random();
        new HistoryStore(filePath: path, cipher: cipher).Add(ClipItem.Create(ClipKind.Text, "my home address"));

        var raw = File.ReadAllBytes(path);
        Assert.DoesNotContain("home address", Encoding.UTF8.GetString(raw));
        Assert.ThrowsAny<JsonException>(() => JsonSerializer.Deserialize<List<ClipItem>>(raw));

        var reopened = new HistoryStore(filePath: path, cipher: cipher);
        Assert.Equal(LoadStatus.Loaded, reopened.LoadStatus);
        Assert.Equal(["my home address"], reopened.Items.Select(i => i.Text));
    }

    [Fact]
    public void ExpiringItemsStayInMemoryOnly()
    {
        using var dir = new TempDir();
        var path = dir.File("history.tuck");
        var cipher = TestCipher.Random();
        var store = new HistoryStore(filePath: path, cipher: cipher);
        store.Add(ClipItem.Create(ClipKind.Text, "keep"));
        store.Add(ClipItem.Create(ClipKind.Text, "secret", secretKind: SecretKind.GitHubToken,
            expiresAt: DateTimeOffset.Now.AddMinutes(5)));
        Assert.Equal(2, store.Items.Count);

        var reopened = new HistoryStore(filePath: path, cipher: cipher);
        Assert.Equal(["keep"], reopened.Items.Select(i => i.Text));
    }

    [Fact]
    public void PlainTextHistoryIsMigrated()
    {
        using var dir = new TempDir();
        var path = dir.File("history.tuck");
        new HistoryStore(filePath: path).Add(ClipItem.Create(ClipKind.Text, "old item"));

        var cipher = TestCipher.Random();
        var migrated = new HistoryStore(filePath: path, cipher: cipher);
        Assert.Equal(LoadStatus.Migrated, migrated.LoadStatus);
        Assert.Equal(["old item"], migrated.Items.Select(i => i.Text));
        Assert.DoesNotContain("old item", Encoding.UTF8.GetString(File.ReadAllBytes(path)));
        Assert.Equal(["old item"], new HistoryStore(filePath: path, cipher: cipher).Items.Select(i => i.Text));
    }

    [Fact]
    public void WrongKeyMovesFileAsideInsteadOfOverwriting()
    {
        using var dir = new TempDir();
        var path = dir.File("history.tuck");
        new HistoryStore(filePath: path, cipher: TestCipher.Random()).Add(ClipItem.Create(ClipKind.Text, "precious"));
        var original = File.ReadAllBytes(path);

        var other = new HistoryStore(filePath: path, cipher: TestCipher.Random());
        Assert.Equal(LoadStatus.Unreadable, other.LoadStatus);
        Assert.Empty(other.Items);
        Assert.NotNull(other.MovedAsidePath);
        Assert.Equal(original, File.ReadAllBytes(other.MovedAsidePath!));
        Assert.False(File.Exists(path));
    }
}
