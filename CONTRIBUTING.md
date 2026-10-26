# Contributing to Tuck

Thanks for helping. A few ground rules:

1. **Original work only.** Do not copy code, assets or wording from Maccy or any other app, and do not reverse-engineer or redistribute paid binaries. Describe behavior from public documentation or normal use.
2. **Keep it local.** No network calls, analytics or accounts.
3. **Test the core.** Logic that does not need AppKit goes in `Packages/TuckCore/Sources/TuckCore` with tests in `Packages/TuckCore/Tests/TuckCoreTests`. Run `swift test --package-path Packages/TuckCore` before opening a PR.
4. **Follow DESIGN.md** for UI changes: system fonts and materials, keyboard shortcuts shown, light and dark mode both checked.
5. **Small PRs.** One change per pull request, with a short description of what and why.

## Setup
```sh
brew install xcodegen
xcodegen generate
open Tuck.xcodeproj
```

## Commit messages
Short imperative summary on the first line, details after a blank line if needed.
