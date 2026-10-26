using System.Security.Cryptography;
using System.Text;
using Tuck.Core;

namespace Tuck.App.Platform;

/// <summary>
/// Encrypts history with Windows DPAPI, using a key tied to the signed-in Windows
/// account. Other users on the PC, and copies of the file on another PC, can't read it.
/// </summary>
internal sealed class DpapiCipher : IHistoryCipher
{
    private static readonly byte[] Entropy = Encoding.UTF8.GetBytes("Tuck.History.v1");

    public byte[] Seal(byte[] plaintext) =>
        ProtectedData.Protect(plaintext, Entropy, DataProtectionScope.CurrentUser);

    public byte[] Open(byte[] ciphertext) =>
        ProtectedData.Unprotect(ciphertext, Entropy, DataProtectionScope.CurrentUser);
}
