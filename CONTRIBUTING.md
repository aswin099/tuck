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

## Issues and pull requests
- Use the **Bug report** or **Feature request** form when opening an issue.
- Open pull requests against `develop`. The pull request template has a short checklist.
- Report security problems privately, as described in [SECURITY.md](SECURITY.md).
- Everyone taking part follows the [code of conduct](CODE_OF_CONDUCT.md).

## Commit messages
Short imperative summary on the first line, details after a blank line if needed.
