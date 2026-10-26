# Tuck — DESIGN.md

Design system for the Tuck macOS app, its website and its README. Format follows the DESIGN.md convention so coding agents can read it.

## 1. Visual theme and atmosphere
Calm, quick and quietly friendly. A native Mac utility that looks like it shipped with the OS but has a personality: one indigo identity color and one warm amber accent. Dense but breathable. No gradients washes, no glow, no decorative chrome. The icon metaphor is a pocket with cards tucked inside; reuse it sparingly.

## 2. Color palette and roles
| Token | Hex | Role |
|---|---|---|
| indigo-900 | #14153A | Text on light, dark-mode window base |
| indigo-700 | #2B2D6E | Brand, app icon tile, primary text accent, wordmark |
| indigo-500 | #8E94F2 | Secondary accents, focus ring on dark |
| indigo-200 | #C9CCFF | Selected-row tint (dark), subtle fills |
| indigo-50 | #F6F5FF | Page background on light |
| amber-400 | #FFB547 | Single accent: pin marker, paste confirmation, key highlight |
| amber-200 | #FFD28A | Hover or tint of amber |
| text-secondary | #3B3D78 | Secondary text on light (passes 4.5:1 on indigo-50) |

Rules: in the app, prefer system semantic colors (`.primary`, `.secondary`, `.separator`) and use the indigo as `accentColor`. Amber is never used for text on light backgrounds. Always check 4.5:1 for text.

## 3. Typography
- App UI: SF Pro (system font), Dynamic Type friendly.
- Wordmark, website headings: Manrope 800, tracking -3% on large sizes.
- Website body: Manrope 500 or system-ui.
- Code and shortcuts: SF Mono / ui-monospace.

| Role | Size / weight |
|---|---|
| Popup item text | 13 / regular |
| Item metadata (source app, time) | 11 / regular, secondary |
| Search field | 15 / regular |
| Settings labels | 13 / regular |
| Section headers | 11 / semibold, secondary |
| Website H1 | 64–168 / 800 |
| Website body | 18 / 500 |

## 4. Component styling
- **Popup window**: 380 × 460 pt, corner radius 14, `.regularMaterial` background, 0.5 pt separator border, soft shadow (0 12 32 at 18% black). Appears near the cursor, clamped to the screen.
- **Search field**: top of the popup, 36 pt tall, no heavy border, magnifier icon, clear button; always focused on open.
- **Item row**: 36 pt min height, 12 pt horizontal padding, one to two lines of text, trailing shortcut hint (⌘1–9) in secondary text. Selected row: indigo-700 at 14% on light, indigo-200 at 22% on dark, radius 8, no heavy outline.
- **Image item**: thumbnail 48 × 32, radius 6, aspect-fit.
- **Pinned item**: 6 pt amber dot at leading edge, pinned items sorted first.
- **Source app badge**: 16 pt app icon, 11 pt name.
- **Footer**: 28 pt, key hints (↩ paste, ⌥↩ plain, ⌫ delete, ⌘P pin), 11 pt secondary.
- **Menu bar glyph**: template image, 18 pt, pocket and card from the logo; dimmed when paused.
- **Buttons (settings and site)**: radius 10, 36 pt height; primary indigo-700 on white text; secondary outlined.

## 5. Layout principles
- 4 pt base grid. Spacing scale: 4, 8, 12, 16, 24, 32, 48, 64.
- Popup content padding 8; rows full width inside.
- Settings: standard macOS grouped form, 520 pt wide, labels leading.
- Website: max content width 1120, 16 pt gutters on phones, generous vertical rhythm (96 pt sections).

## 6. Depth and elevation
Two levels only: the popup (material + soft shadow) and settings window (standard window chrome). No stacked cards, no nested shadows.

## 7. Do's and don'ts
Do:
- Show the keyboard shortcut next to every action
- Respect Reduce Motion, Increase Contrast and Reduce Transparency
- Keep animations under 150 ms, ease-out, no bounce
- Use real system controls and text styles

Don't:
- Use purple-to-blue gradient backgrounds or glowing effects
- Wrap everything in cards, or put cards inside cards
- Use gray text on colored backgrounds
- Use emoji as icons
- Copy another app's name, icon, layout or artwork

## 8. Responsive and adaptive behavior
- Popup keeps its size; its list scrolls and the window clamps to screen edges and Stage Manager.
- Website stacks to one column under 720 px; touch targets at least 44 px.
- Light and dark mode are both first-class. Dark base is indigo-900, not pure black.

## 9. Agent prompt guide
Quick reference:
- Brand indigo #2B2D6E, accent amber #FFB547, light page #F6F5FF, dark base #14153A
- Radius: 14 window, 10 buttons, 8 rows, 6 thumbnails
- Fonts: SF Pro in the app, Manrope on the web

Prompts:
- "Build the Tuck popup in SwiftUI following DESIGN.md: material background, 36 pt search field, 36 pt rows, selected row tint, footer key hints."
- "Build the Tuck landing page following DESIGN.md: Manrope headings, indigo and amber only, one screenshot of the popup, no gradients."
- "Audit this view against DESIGN.md for contrast, spacing and shortcut hints."
