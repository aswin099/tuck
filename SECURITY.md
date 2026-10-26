# Security policy

Tuck handles clipboard history, which can include passwords, keys and personal data, so security reports are taken seriously.

## Supported versions

Tuck is in early preview. Only the latest release gets security fixes.

| Version | Supported |
|---|---|
| Latest release | Yes |
| Older releases | No |

## Reporting a vulnerability

**Please don't open a public issue for security problems.**

Report privately through GitHub instead: open the repository's **Security** tab and choose **Report a vulnerability**. Only the maintainer can see the report.

Please include:
- What the problem is and what an attacker could do with it
- Steps to reproduce it, and your operating system and Tuck version
- Whether it affects macOS, Windows or both

Never include real clipboard contents, passwords or keys in a report. Use made-up examples.

## What to expect

- An acknowledgement within 7 days
- An assessment and, for confirmed issues, a fix or plan as soon as possible
- Credit in the release notes if you'd like it

## In scope

- History being readable by other users or apps, or written to disk unencrypted
- Secrets that Tuck should hide or skip being saved or shown
- Items from password managers, or from ignored apps, being recorded
- Any network traffic from Tuck (it should never make any)

Out of scope: problems that need an attacker who already controls your user account, and issues in macOS, Windows or third-party apps themselves.
