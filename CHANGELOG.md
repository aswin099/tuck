# Changelog

All notable changes to Tuck. Versions follow [semantic versioning](https://semver.org).

## 1.0.1 (2026-11-07)

### Fixed
- Settings now always opens in front of other windows. It could open behind them when you opened it a second time.
- The About tab shows "Version 1.0.1" without the build number in brackets.

## 1.0.0 (2026-11-07)

The first full release of Tuck for Mac. Windows builds stay in preview until they've been tested on a real PC; the latest one is [0.1.0-preview.9](https://github.com/aswin099/tuck/releases/tag/v0.1.0-preview.9).

### What Tuck does
- Remembers what you copy: text, links, images and files.
- ⇧⌘V opens a search popup near your cursor. ↩ copies the item you pick, ⌘1–9 picks by position, ⌘P pins, ⌘⌫ deletes and ⌘Y shows a preview pane.
- Paste queue: press ⇥ on items, or turn on Collect New Copies, then ⌃⌘V gives them back oldest first.
- Hides API keys, tokens, private keys, card numbers and random-looking passwords, deletes them after a few minutes, and clears the clipboard after you paste one.
- Skips password-manager copies and any apps you choose to ignore.
- Encrypts its history file, with the key in your Keychain. No network code and no telemetry.
- Settings for shortcuts, auto-paste, history size and age, which kinds of items to save, the popup, secrets and ignored apps.

### New since the previews
- **No permission prompts on first run.** New installs start copy-only: pick an item and press ⌘V. Turn on Settings › General › *Paste into the active app* to have Tuck paste for you, which asks for Accessibility. If you already used Tuck, auto-paste stays on.
- **Installer window.** `Tuck-macOS.dmg` opens a window where you drag Tuck into Applications. The zip is still there if you prefer it.
- **Pinned items show a pin** instead of a small dot.
- The Accessibility prompt shows at most once per launch instead of on every paste.

### Fixed
- ⌘⌫ now deletes the selected item. The search field used to take it.
- The Settings window no longer changes size when you switch tabs.
- Changing shortcuts works on macOS 27.

### Known limits
- Tuck isn't signed by Apple, so the first time you open each version, macOS asks you to allow it in System Settings › Privacy & Security › Open Anyway. After an update, macOS may also ask for the Keychain and Accessibility again.
- There's no automatic update yet: download new versions from the [Releases page](https://github.com/aswin099/tuck/releases).

## Previews (0.1.0-preview.4 to preview.9)

Test builds for Mac and Windows, October to November 2026. They added the app icon, encrypted history, secret detection, the paste queue, the preview pane, Settings, and the Windows port.
