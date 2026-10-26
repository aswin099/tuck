# Tuck for Windows (preview)

The Windows version of [Tuck](../README.md), written in C# with WPF on .NET 10. It mirrors the macOS app feature for feature.

> **Status: not tested on Windows yet.** It compiles, and the core logic passes its unit tests on macOS and in CI, but nobody has run the app on a Windows PC yet. Expect bugs, and please [open an issue](https://github.com/aswin099/tuck/issues) with what you see.

## Requirements

- Windows 10 or Windows 11, 64-bit (x64 or ARM64)
- Nothing else: the release download includes the .NET runtime

## Install

1. Download `Tuck-Windows-x64.zip` (most PCs) or `Tuck-Windows-arm64.zip` (Windows on ARM) from the [Releases page](https://github.com/aswin099/tuck/releases).
2. Unzip it and move **Tuck.exe** to a permanent folder, for example `C:\Users\<you>\Tuck\`.
3. Double-click **Tuck.exe**.
4. If Windows shows *"Windows protected your PC"*, click **More info**, then **Run anyway**. This appears because Tuck isn't signed with a paid code-signing certificate. You only need to do it once per version.

## Using Tuck

| Action | Keys |
|---|---|
| Open or close the popup | **Ctrl+Shift+V** (change in Settings) |
| Move through items | ↑ ↓, Page Up, Page Down |
| Paste the selected item | **Enter**, or double-click |
| Paste item 1–9 | **Ctrl+1** … **Ctrl+9** |
| Add to or remove from the paste queue | **Tab** |
| Paste the next queued item, anywhere | **Ctrl+Alt+V** (change in Settings) |
| Show or hide the preview pane | **Alt+P** |
| Pin or unpin | **Ctrl+P** |
| Delete | **Shift+Delete** |
| Open Settings | **Ctrl+,** |
| Close | **Esc** |

- Tuck lives in the **notification area** next to the clock. If you can't see it, click the **^** arrow and drag Tuck onto the taskbar.
- **Left-click** the icon to open the popup. **Right-click** for Pause Recording, Paste Queue, Settings, Clear History and Quit.
- Unlike on the Mac, pasting needs **no special permission**.

Ctrl+Shift+V replaces "paste as plain text" in browsers and some other apps. Tuck always pastes plain text, so you lose nothing. If you prefer to keep it, pick another shortcut in **Settings → General**.

## Privacy

- History is saved in `%LOCALAPPDATA%\Tuck\history.tuck`, encrypted with Windows DPAPI. The key is tied to your Windows account, so other users on the PC, and copies of the file on another PC, can't read it.
- Items Tuck hides as secrets are kept in memory only and never written to disk.
- Tuck skips copies that password managers mark as private (`ExcludeClipboardContentFromMonitorProcessing`, or `CanIncludeInClipboardHistory = 0`).
- When Tuck pastes a secret, it marks it so Windows clipboard history (Win+V) and cloud clipboard sync don't keep it.
- No network code, no telemetry. Errors are logged only to `%LOCALAPPDATA%\Tuck\error.log`.

## Uninstall

1. Right-click the Tuck icon → **Quit Tuck**. If **Settings → General → Open Tuck when you sign in** is on, turn it off first.
2. Delete **Tuck.exe**.
3. To remove your history and settings, delete the folder `%LOCALAPPDATA%\Tuck`. Paste that path into File Explorer's address bar to find it.

## Build from source

You need the [.NET 10 SDK](https://dotnet.microsoft.com/download).

```powershell
git clone https://github.com/aswin099/tuck.git
cd tuck\Windows
dotnet test tests\Tuck.Core.Tests      # core unit tests
dotnet run --project src\Tuck.App      # build and start Tuck
```

To make a single `Tuck.exe` like the release download:

```powershell
dotnet publish src\Tuck.App -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true -p:EnableCompressionInSingleFile=true -o publish
```

The core library and its tests also build and run on macOS and Linux. The app builds there too, thanks to `EnableWindowsTargeting`, but runs only on Windows.

## Layout

| Path | Purpose |
|---|---|
| `src/Tuck.Core` | Models, history store, search, ignore rules, secret detection, paste queue. Same behavior as `Packages/TuckCore` on macOS |
| `tests/Tuck.Core.Tests` | xUnit tests, ported from the Swift tests plus Windows-specific cases |
| `src/Tuck.App/Platform` | Win32 interop: clipboard listener, global hotkeys, Ctrl+V simulation, DPAPI, sign-in startup |
| `src/Tuck.App/ViewModels` | `AppController` (the twin of `AppModel` on macOS) and the item view model |
| `src/Tuck.App/Views` | Popup, preview pane, Settings window, tray icon |

## Things to check on first test

These parts are written against Windows APIs that can't be exercised from macOS:

- [ ] Tray icon appears; left-click opens the popup, right-click opens the menu
- [ ] Ctrl+Shift+V opens the popup at the mouse pointer, on each monitor and at different display scaling
- [ ] Copying text, links, images and files adds them; copying from KeePass or Bitwarden does not
- [ ] Enter pastes into the app you were in; Ctrl+Alt+V pastes the next queued item
- [ ] Secrets show as dots, expire, and the clipboard is cleared after pasting one
- [ ] Light and dark mode both look right, and switching while Tuck runs updates it
- [ ] Settings changes take effect immediately and persist after restarting Tuck
- [ ] "Open Tuck when you sign in" works after signing out and in
