# Tuck — Product

Working name: **Tuck**. A free, open-source clipboard manager for macOS. MIT licensed.

## Purpose
Remember what you copy, and get it back in two keystrokes. Tuck is a clean-room project: it is inspired by the category (Maccy and others) but shares no code, name or artwork with any existing app.

## Audience
Mac users who copy and paste all day: developers, writers, analysts, support and ops staff. They are keyboard-first, privacy-aware and allergic to bloat.

## Principles
1. **Keyboard first.** Every action has a shortcut. The mouse is optional.
2. **Private by default.** Everything stays on the Mac. No network code, no telemetry, no accounts.
3. **Light.** Idle CPU near zero, popup opens in under 150 ms, small memory footprint.
4. **Native.** SwiftUI and AppKit, system fonts, system materials, respects light/dark and accessibility settings.
5. **Honest and small.** Do a few things well. No sync, no AI, no upsells.

## MVP scope
- Watch the system pasteboard; store text, links, images and files (rich text planned)
- Global hotkey (default ⇧⌘V, user-configurable) opens a popup near the cursor or screen center
- Search as you type (type and source-app filters exist in the core; popup UI for them is planned)
- Enter pastes into the previous app; ⌘1–9 pastes the nth item
- Pin, delete, clear history
- Ignore rules: skip items marked concealed or transient by the source app (the nspasteboard.org conventions, which password managers use), plus a per-app ignore list
- Settings: hotkey, history size, launch at login, ignored apps (retention period planned)
- Menu bar item with a pause toggle

## Out of scope for v1
Cloud or iCloud sync, snippets and templates, OCR, scripting, iOS companion, telemetry of any kind. Planned after v1: rich text, plain-text paste variant (⌥Enter), SQLite storage.

## Behavior notes (written from public documentation, in our own words)
- Pasteboard changes are detected by polling the change count, default every 0.5 s, adjustable.
- Auto-paste needs the Accessibility permission; without it Tuck copies the item and tells the user to press ⌘V.
- Duplicate copies are merged into the existing entry and moved to the top.
- Hotkey conflicts with system shortcuts should be detected and reported, not silently ignored.

## Technical direction
- Swift (5 language mode for now, Swift 6 later), SwiftUI for views, AppKit (`NSPanel`, `NSPasteboard`, `CGEvent`) for the popup, pasteboard and paste simulation
- macOS 14 Sonoma or later
- Storage: an AES-256-GCM encrypted JSON file in Application Support (permissions 0600), key held in the login Keychain (device-only); expiring items stay in memory. Target is SQLite with the same encryption
- Global hotkey: the KeyboardShortcuts package (MIT)
- Tests: XCTest unit tests for store, dedupe and ignore rules; XCUITest for popup flows
- Distribution: GitHub Releases (signed and notarized), Homebrew cask, later the App Store if wanted

## Legal and attribution
- Original code, original name, original icon. Do not copy source, assets or wording from Maccy or any other app.
- Third-party packages keep their own licenses and are listed in THIRD_PARTY_NOTICES.md.
- Do not reverse-engineer or redistribute paid binaries. Behavior is specified from public docs and from using the apps normally.

## Success checks
- Popup opens in under 150 ms on an M-series Mac
- Idle CPU under 1%
- Passwords copied from a compliant password manager never appear in history
- A new contributor can build and run it in under five minutes
