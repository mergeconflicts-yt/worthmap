# Contour — Decisions and Open Questions

Version 1.0 — 17 October 2026. This file records design and product decisions and
any conflict between sources (AGENTS.md sections 1 and 9). A conflict names the
sources, the options and the preferred option. Feature code never changes
SPEC.md, DESIGN.md or AGENTS.md; it records the item here.

## Open questions

### LIGHT-LOSS-CONTRAST

- Conflict. DESIGN 2.4 states the Obsidian Light loss colour `#C8324B` measures
  4.7:1. The standard WCAG 2.x formula on the Light page `#ECEBE7` gives 4.39:1,
  below the 4.5:1 text minimum (DESIGN 2.2, 9). DESIGN 2.4 also notes as open
  that some figures use `#C2263A`; that value gives about 4.86:1 on the page.
- Options. (a) Keep the token `#C8324B` and accept 4.39:1 on the page, because
  gain and loss always carry a sign and a glyph (DESIGN 2.4), so colour is never
  the only signal. (b) Change the token to `#C2263A`. (c) Add a separate Light
  loss text tint token.

- Preferred. Option (a). The token in DESIGN 2.4 is the source of truth; the
  change in (b) belongs to the design owner and needs a DESIGN.md pull request.
  `tool/check_contrast.dart` measures the pair, prints a warning and lists it as
  a documented exception. Code that depends on this choice is marked
  `// DECISION-PENDING: LIGHT-LOSS-CONTRAST`.

### T03-DERIVED-TOKENS

- Several DESIGN tokens are not written literally for both themes. T03 used the
  nearest documented value and flagged the token with
  `$extensions.contour.derived` in `lib/design/tokens/tokens.json`. These need a
  design-owner review before T04 builds the theme:
  - `color.role.surface.pageSpotlight` Light opacity (white 6% assumed).
  - `color.data.category.other` Light mark (the Light text tint is used).
  - `color.data.assetClass.*` and `color.data.series.*` Light values (from the
    DATA-LIGHT mark map, DESIGN 2.4).
  - `color.data.heat.*` (the heat scale is stated for dark only; the Light value
    is not given).
  - `color.palette.inkDeep` is dark-only per DESIGN 2.1; the Light value repeats
    the dark value so every colour token has both themes.

### T03-UNUSED-TOKENS

- `tool/check_tokens.dart` does not yet check for unused tokens (DESIGN 9),
  because no consumer exists before T04. Add the check in T04 when the theme
  reads the tokens.

### T05-HERO-FILL-CONTRAST

- DESIGN 12 and 14.1 say the Light hero-fill stops reach 7:1 on the page. With
  the stated hex `#4B4E57` the measured value is 6.97:1 (rounds to 7.0).
  Preferred: keep the documented hex and record the 0.03 shortfall as a
  documented exception in `check_contrast` (done). Alternative: darken the stop
  to reach 7.0 strictly. DECISION-PENDING: T05-HERO-FILL-CONTRAST.

### T05-NUMBER-LOCALE

- `formatMoney` uses a fixed thousands separator (`,`) and decimal point (`.`).
  DESIGN 8 does not state whether number grouping follows the device locale in
  v1 (English). Preferred: keep the fixed English format for v1 and revisit
  with l10n (T10). DECISION-PENDING: T05-NUMBER-LOCALE.

## Decided

### T05-TOKENS

- Added `color.role.text.heroFill` (dark #FFFFFF → #9C9EA8, Light #16171B →
  #4B4E57, 90°) for the one hero number fill (DESIGN 14.1c). `check_contrast`
  now checks both stops against `surface.page` at 7:1.
- Added `space.cardTitleGap` = 10 for CARD-TITLE-OUT (title 10 pt above the
  card; the card's bottom padding is also 10). Derived; DESIGN 6.7 states 10 pt.

### T05-MONEYTEXT

- Added `lib/design/format/` (`MoneyText`, `ValueState`, `formatMoney`) inside
  T05, though T05's file list names only layout and components. `ObHero` and
  every money component need it (DESIGN 6.6, 8; acceptance "every money widget
  has hidden state"). The hidden mask is the currency mark plus six middle dots
  (`$······`); the accessible name is masked too (hidden_mode_semantics).

### T05-DESTRUCTIVE-FILL

- DESIGN 6.3 gives `action.destructive.fill` = Dark #3A3C44 / Light #E4E5EA
  (both from DESIGN 2.2 as "filled neutral grey"). Used as the button fill with
  `action.destructive.text`. No open question; recorded for review.

### T04-ASSETS

- Bundled Inter 4.1 (weights 200, 400, 500, 600) and Inter Display 4.1
  (weights 200, 300) as TTF files in `lib/design/fonts/`, licence
  `LICENSE-Inter.txt` (SIL OFL 1.1), per DESIGN 2.5. Source:
  `github.com/rsms/inter` release v4.1.
- Bundled Lucide line icons as SVG files in `lib/design/icons/`, licence
  `LICENSE-Lucide.txt` (ISC), per DESIGN 2.11. Stroke set to 1.75, and 2.2 for
  the tab bar Add (`plus-tab.svg`). Source: `github.com/lucide-icons/lucide`.

### T04-DEPENDENCY-FLUTTER-SVG

- Added `flutter_svg 2.3.0` to render the Lucide SVG assets. It runs fully on
  device, makes no network calls, has an OSI-approved licence (MIT), and had a
  release within the last 12 months (AGENTS 6.8). It brings `vector_graphics`,
  `vector_graphics_compiler`, `vector_graphics_codec`, and `xml`.

### T03-FORMATTER-LANGUAGE-VERSION


- `dart format` uses the package language version (`^3.5.0`, short style) for
  files inside the package, but the newest style for a temp file outside it.
  `tool/check_tokens.dart` regenerates into `.dart_tool/` inside the package so a
  formatting difference never hides a real token difference.

### T02b-PERCENT-ZERO-TOTAL

- `Percent.split` rejects a negative part and a total that is not positive, and
  rejects a negative scale. It returns an empty list for empty input. The
  largest-remainder rule itself is SPEC 4.1; these guard rails are arithmetic
  contract, not a financial rule.
