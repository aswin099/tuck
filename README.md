# Tuck

A free, open-source clipboard manager for macOS. Local-only, keyboard-first, MIT licensed.

> Status: early preview (v0.1). It builds and runs, and the core library has unit tests, but it hasn't had much real-world use yet. Expect rough edges and please [report problems](https://github.com/aswin099/tuck/issues).

## What it does
- Remembers what you copy: text, links, images and files
- Global hotkey (default ⇧⌘V) opens a search popup near your cursor
- Type to search, ↩ to paste, ⌘1–9 to paste the Nth item, ⌘P to pin, ⌘⌫ to delete
- Preview pane (⌘Y) with the full text, image or file list, source app, time and size
- Paste queue: press ⇥ on items (or turn on "Collect New Copies"), then ⌃⌘V pastes them one by one, oldest first
- Secret detection: API keys, tokens, private keys, card numbers and random-looking passwords are hidden and deleted after a few minutes (or not saved at all), and the clipboard is cleared after you paste one
- Skips copies marked concealed or transient (password managers), plus any apps you list
- Menu bar item with Pause, Paste Queue, Settings and Clear History
- Settings for shortcuts, auto-paste, history size and age, which kinds of items to save, popup position and layout, secrets and ignored apps
- Nothing leaves your Mac: no network code, no telemetry

## Install

You need **macOS 14 Sonoma or later**. There are two ways to install Tuck.

### Option 1: Download the app (easiest)

1. Open the [Releases page](https://github.com/aswin099/tuck/releases) and download `Tuck.zip` from the latest release. If there is no release yet, use Option 2.
2. Unzip it and drag **Tuck.app** into your **Applications** folder.
3. Open Tuck. Because Tuck is not signed by Apple, macOS shows *"Apple could not verify Tuck is free of malware"*. Click **Done** (not Move to Trash).
4. Open **System Settings → Privacy & Security**, scroll down to the message about Tuck and click **Open Anyway**. Confirm with your password or Touch ID.
5. Open Tuck again. You only need to do steps 3–5 once per version.

Comfortable with Terminal? Instead of steps 3–5 you can run this once after step 2:
```bash
xattr -dr com.apple.quarantine /Applications/Tuck.app
```

### Option 2: Build it yourself

This needs **[Xcode](https://apps.apple.com/app/xcode/id497799835)** (free, from the App Store; open it once after installing) and **[Homebrew](https://brew.sh)**. Run these in Terminal:

```bash
# 1. Install XcodeGen, which creates the Xcode project
brew install xcodegen

# 2. Download the code
git clone https://github.com/aswin099/tuck.git
cd tuck

# 3. Create the Xcode project
xcodegen generate

# 4. Build the app
xcodebuild -project Tuck.xcodeproj -scheme Tuck -configuration Release \
  -derivedDataPath build CODE_SIGN_IDENTITY=- build

# 5. Copy it to Applications and open it
cp -R build/Build/Products/Release/Tuck.app /Applications/
open /Applications/Tuck.app
```

An app you build yourself opens without the security warning.

## First launch

- **Tuck has no window or Dock icon.** It lives in the **menu bar** at the top right of your screen (a tray icon). Click it for Open Tuck, Pause Recording, Paste Queue, Settings and Quit.
- **Press ⇧⌘V** (Shift + Command + V) anywhere to open the clipboard popup. Type to search, use ↑ ↓ to choose and ↩ to paste.
- **Allow Accessibility so Tuck can paste for you.** The first time you paste, macOS asks for permission. Turn on **Tuck** in **System Settings → Privacy & Security → Accessibility**. Without it, Tuck copies the item and you press ⌘V yourself.
- **If a Keychain prompt appears, click Always Allow.** Tuck keeps the key that encrypts your history in your Keychain.
- **Start Tuck automatically:** Settings → General → *Open Tuck at login*.

## Update

Quit Tuck from its menu bar icon, replace **Tuck.app** in Applications with the new version (or for Option 2, run `git pull` in the `tuck` folder and repeat steps 3–5), then open it. Because Tuck isn't signed by Apple, macOS may ask you to allow Accessibility and the Keychain again after an update. Your history is kept.

## Uninstall

1. Quit Tuck from its menu bar icon.
2. Delete **Tuck.app** from Applications.
3. To also delete your clipboard history, delete the folder `~/Library/Application Support/Tuck`.
4. Optional: open **Keychain Access**, search for **Tuck history key** and delete it.
5. Optional: remove Tuck from **System Settings → Privacy & Security → Accessibility**.

## Development

Requirements: Xcode 15.4 or later and XcodeGen (see Option 2).

```bash
swift test --package-path Packages/TuckCore   # run the core unit tests
xcodegen generate                             # create Tuck.xcodeproj (not committed)
open Tuck.xcodeproj                           # press Run in Xcode
```

If Xcode shows a signing error when you press Run, select the **Tuck** target → **Signing & Capabilities** and choose your Personal Team, or set Signing Certificate to **Sign to Run Locally**.

Branches: `develop` for day-to-day work, `staging` for testing a release, `main` for released code. Open pull requests against `develop`.

## Project layout
| Path | Purpose |
|---|---|
| `Packages/TuckCore/Sources/TuckCore` | Models, history store, search, ignore rules. No AppKit, fully testable |
| `Packages/TuckCore/Tests/TuckCoreTests` | Unit tests |
| `App/` | SwiftUI and AppKit app: menu bar, popup panel, pasteboard monitor, paster, settings |
| `App/Assets.xcassets` | App icon and menu bar glyphs |
| `tools/render-icon.swift` | Draws the icon and glyphs; run `swift tools/render-icon.swift App/Assets.xcassets` after changing them |
| `project.yml` | XcodeGen spec |
| `PRODUCT.md`, `DESIGN.md` | Product spec and design system |

## Privacy
History is stored in `~/Library/Application Support/Tuck/history.tuck`, readable only by your user and encrypted with AES-256-GCM. The key is created on first run and kept in your login Keychain as a device-only item (never synced to iCloud). Items Tuck hides as secrets are kept in memory only and never written to disk. A plain-text `history.json` from an earlier version is encrypted automatically on first launch. If the Keychain can't be used, Tuck keeps history in memory only rather than writing it unencrypted. Encryption protects the file at rest; it does not protect against other software running as your user, so keep using the ignore list for sensitive apps.

## Roadmap
- Thumbnail cache for image items
- Rich text support and plain-text paste (⌥↩)
- SQLite storage
- Filters by type and source app in the popup UI
- Signed and notarized releases, Homebrew cask
- XCUITest popup flows

## Contributing
See [CONTRIBUTING.md](CONTRIBUTING.md).

## License
MIT. See [LICENSE](LICENSE). Third-party notices are in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
