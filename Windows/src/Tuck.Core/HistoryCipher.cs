namespace Tuck.Core;

/// <summary>Encrypts the history file. On Windows the app uses DPAPI, tied to the user's account.</summary>
public interface IHistoryCipher
{
    byte[] Seal(byte[] plaintext);
    byte[] Open(byte[] ciphertext);
}
