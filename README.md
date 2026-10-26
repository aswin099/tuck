# Tuck

A free, open-source clipboard manager for macOS. Local-only, keyboard-first, MIT licensed.

> Status: early scaffold (v0.1). The core library has unit tests; the app has not been run yet. Expect rough edges.

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

## Requirements
- macOS 14 Sonoma or later
- Xcode 15.4 or later
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`

## Build and run
```sh
swift test --package-path Packages/TuckCore   # run the core unit tests
xcodegen generate          # creates Tuck.xcodeproj
open Tuck.xcodeproj        # press Run in Xcode
```

On first paste, macOS asks for the Accessibility permission (System Settings → Privacy & Security → Accessibility). Tuck needs it to send ⌘V to the app you are pasting into. Without it, the item is copied and you press ⌘V yourself.

## Project layout
| Path | Purpose |
|---|---|
| `Packages/TuckCore/Sources/TuckCore` | Models, history store, search, ignore rules. No AppKit, fully testable |
| `Packages/TuckCore/Tests/TuckCoreTests` | Unit tests |
| `App/` | SwiftUI and AppKit app: menu bar, popup panel, pasteboard monitor, paster, settings |
| `project.yml` | XcodeGen spec |
| `PRODUCT.md`, `DESIGN.md` | Product spec and design system |

## Privacy
History is stored in `~/Library/Application Support/Tuck/history.tuck`, readable only by your user and encrypted with AES-256-GCM. The key is created on first run and kept in your login Keychain as a device-only item (never synced to iCloud). Items Tuck hides as secrets are kept in memory only and never written to disk. A plain-text `history.json` from an earlier version is encrypted automatically on first launch. If the Keychain can't be used, Tuck keeps history in memory only rather than writing it unencrypted. Encryption protects the file at rest; it does not protect against other software running as your user, so keep using the ignore list for sensitive apps.

## Roadmap
- Real menu bar glyph and app icon assets
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
