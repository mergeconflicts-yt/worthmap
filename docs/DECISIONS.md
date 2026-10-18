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
  `tool/check_contrast.dart` measures the pair on `surface.page` and on the
  composited `pageSpotlight` surface (DESIGN 9) and **fails** while this item is
  still an open question (R07, CR-19). An exemption passes only when an id is
  listed in `_closedDecisions` and recorded under "Decided" here. Code that
  depends on this choice is marked `// DECISION-PENDING: LIGHT-LOSS-CONTRAST`.
- Recommendation to close. Change the Light loss token to `#C2263A` (about
  4.86:1) in a DESIGN.md pull request, then add `LIGHT-LOSS-CONTRAST` to
  `_closedDecisions` and delete the exemption entries.

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
  `check_contrast` now **fails** while this item is an open question (R07,
  CR-19). Preferred: keep the documented hex and change the contract. Other
  option: darken the stop to reach 7.0 strictly. DECISION-PENDING:
  T05-HERO-FILL-CONTRAST.
- Recommendation to close. Darken the Light stop 1 slightly (a value that
  measures at least 7.00:1 on `#ECEBE7`) in a DESIGN.md pull request, then add
  `T05-HERO-FILL-CONTRAST` to `_closedDecisions` and delete the exemption.

### T05-NUMBER-LOCALE

- `formatMoney` uses a fixed thousands separator (`,`) and decimal point (`.`).
  DESIGN 8 does not state whether number grouping follows the device locale in
  v1 (English). Preferred: keep the fixed English format for v1 and revisit
  with l10n (T10). DECISION-PENDING: T05-NUMBER-LOCALE.

### HERO-SPLIT-NUMBER

- The Obsidian hero number typography is not built: currency mark at 0.45 em
  weight 300 raised, cents at 0.5 em in `text.secondary`, the rest with the
  14.1(c) fill (DESIGN 2.5, 6.7). `ObHero` currently paints one gradient-filled
  string, sized by `FitNumber`. Preferred: build the split-number typography in
  a design-only change with a golden for each part. `ObHeroVariant.period` was
  removed (it needs the T11 charts and `build()` never read it); it returns with
  the period chart. DECISION-PENDING: HERO-SPLIT-NUMBER.

### T06-L10N-CONSTANTS

- T06 test widgets, the host and the edit bar use visible words as Dart
  constants (`testNotLoadedLabel`, `WidgetEditBarLabels`, `unavailableLabel`)
  because l10n does not exist until T10. AGENTS 6.9 requires every visible string
  in l10n. Preferred: T10 replaces these constants with l10n lookups; the
  parameters already exist, so no component API changes then.
  DECISION-PENDING: T06-L10N-CONSTANTS.

### SCREEN-REFERENCES

- The screen screenshots (`docs/screens/<id>.png`), the design-gallery HTML
  (`design/gallery/*.html`) and `contour-design.html` are absent in this
  checkout. AGENTS 5 asks a builder to open the screenshot. Preferred: use
  `docs/screens/SCREENS.md` as the reference and record here that the image
  reference is missing. The reference images must return before a screen task is
  accepted as visually verified. DECISION-PENDING: SCREEN-REFERENCES.
- `design-mockups/dark/` and `design-mockups/light/` hold 25 + 25 camera
  photos (5712x4284, about 1 GB total, gitignored) taken from the gallery
  HTML pages. They are not sized or named per screen id, so they do not
  replace `docs/screens/<id>.png` or the gallery HTML. Keep this item open
  until per-screen captures return.

### FITNUMBER-FLOOR

- N-11: the `FitNumber` 40 pt floor is an unscaled font size, so the effective
  floor grows with the system text scale (80 px at 2.0). Preferred: confirm
  with the design owner that this is the intent. Code marks it
  `DECISION-PENDING: FITNUMBER-FLOOR` and keeps the behaviour.

### HERO-MARKER-STYLE

- N-15: `formatValueState` appends the "Est." / "Expected" marker to the hero
  number text, so the hero paints it at 64 pt in the hero style. Preferred:
  ask the design owner for the marker style (probably a caption style after
  the number, which needs a `Text.rich` hero). No code change until the owner
  decides. DECISION-PENDING: HERO-MARKER-STYLE.

### CR-17-PACKAGE-NAME

- The Dart package, bundle id and iOS folder are `contour`; the git folder is
  `money-matters`; R08 notes the parent project name `worthmap`. A rename after
  T07 also changes the native folders, key-store names and the database file
  paths (CR-17). Preferred: fix the product name before T07, then rename in one
  chore change. DECISION-PENDING: CR-17-PACKAGE-NAME.
- N-08: the Android application id is the Flutter default `com.contour.contour`
  (`android/app/build.gradle.kts`); the iOS bundle id matches. N-08 blocks T07
  and T08 on the final name and reverse-domain id (see TASKS T07). The
  `portfolio_manager/` parent copies named in the review are absent in this
  checkout (N-07), so there is nothing to replace here.
- 2026-10-18: owner chose to keep `contour` for now. The rename stays
  deferred; T07 and T08 stay blocked on this item until the final name lands.

### G14-FIN-DEFINITIONS

- G14 stays open. FIN-3-01 (the TWR sub-period formula) is fixed: the denominator
  is `startValue + flow` with the flow at the start of the day
  (spec-calculation.md 13.12). FIN-3-02..04 (the 13.2 and 13.4 test values, the
  net worth bridge gaps and the Appendix A contradictions) come from an external
  review (REVIEW-003) whose detail is not in this checkout. Do not guess them:
  no `lib/domain/numbers` task before they close. An independent check confirms
  13.2 and 13.4 match their stated formulas; the remaining items still need the
  review detail and dated fixtures. DECISION-PENDING: G14-FIN-DEFINITIONS.
- N-06: the REVIEW-003 detail files (`REVIEW-003-finance.md`, `REVIEW-003-ux.md`,
  the two REVIEW-004 files) are absent in this checkout, so they cannot be
  copied into `docs/reviews/`. The agent review quotes two rival pairs: 13.2
  locks `3,796,960` against `3,561,098` (compounding convention), and 13.4 gives
  `86,389,640` against the test value `94,529,640`. Recorded here so the docs
  pull request can adjudicate when the source files arrive. Gate stays open.

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

### T06-DESIGN-COMPONENTS

- T06 added two design components: `WidgetSection` and `WidgetEditBar` in
  `lib/design/components/surfaces/`, and exported them from
  `lib/design/design.dart`. `widget-framework.md` §1 assigns the design surfaces
  (`WidgetSlot`, `WidgetSection`, `WidgetEditBar`, sheets, reorder controls) to
  the design-system builder, while `docs/TASKS.md` T06 lists only
  `lib/app/widgets/*`, test widgets and tests. The components belong in
  `lib/design/` (AGENTS 2.4: no styling outside it), and the host needs them to
  demonstrate the two-level layout. Preferred: keep them in `lib/design/` and
  request the design-system reviewer for these two files. DECISION: the design
  owner may move or restyle them; the app host depends only on their public API.

### T06-TEST-CATALOGUE

- WIDGET-X03-DEFAULT is open, so T06 uses a test catalogue and a test default
  bundle only: `lib/features/home/widgets/test_widget_catalogue.dart`
  (`test.alpha`, `test.beta`, `test.gamma`, `test.own`, `test.tile.a`) and
  `lib/app/widgets/default_layout.dart`. Both are marked
  `// DECISION-PENDING: WIDGET-X03-DEFAULT`. They never enter a release layout.

### T06-HIDDEN-KEY-STORAGE

- SPEC W7 lists "shown items and kept items (keys that this release does not
  know or does not show)". T06 reads this as: a user hidden key leaves the stored
  order (a known key that is not listed is hidden, W3.10); an unknown or
  unreleased key stays stored and is skipped at render. So `LayoutEditor.hide`
  removes the placement, and the resolver skips unknown and gated keys. No
  `hidden` column is needed.

### T06-IN-MEMORY-REPO

- T07 (encrypted database) is blocked input (`SCHEMA.sql`, G01). T06 uses
  `InMemoryLayoutRepository` behind the `LayoutRepository` interface so the
  framework runs now. The Drift implementation and the atomic ChangeLog write
  (SYSTEM_DESIGN 5.2) land in T07. DECISION-PENDING: T06-IN-MEMORY-REPO.

### T06-MOVES-NO

- A descriptor with `movable: false` ("Moves" = No, SPEC W3.9) may not leave its
  `ownSurface`. The registry rejects such a placement in the default file, and
  `LayoutEditor.take` throws. Hide stays allowed for every widget.

### R03-R05-CORE-BOUNDS

- R03: `Money` unary negation and `formatMoney` use the checked BigInt path, so
  the signed 64-bit minimum negates and formats correctly.
- R04: `LocalDate.parse` throws a source-free `InvalidLocalDateFormat`
  (`code = 'invalid-local-date'`), so no statement field enters an error
  (AGENTS 2.6).
- R05: `LocalDate` accepts years 1–9999 only (`minYear`/`maxYear`), which matches
  the approved SQL date range (DATABASE_DESIGN / SCHEMA.sql).

### R06-SHARED-INTERACTION

- One `AppInteraction` widget (`lib/design/components/interaction/`) gives focus,
  Enter/Space activation (repeat consumed), the `border.focusRing` ring (2 px,
  offset 2) and the `surface.tile` hover tint to `AppButton`, `AppIconButton`,
  `InfoButton` and `GlassCard` (AGENTS 11, DESIGN 13.2). It uses a `Focus` with a
  key handler, not `FocusableActionDetector`, so a held Enter/Space does not
  re-fire or fall through to an app-level shortcut.

### CR-08-DEPENDENCIES

- Removed unused packages so every dependency has an owner and a record (AGENTS
  6.8): `flutter_riverpod`, `riverpod_annotation`, `go_router`, `drift`,
  `drift_dev`, `riverpod_generator`, `build_runner`, `uuid` and `intl`. `uuid` is
  not needed (`lib/core/ids.dart` writes UUIDv7). `intl` must not be pinned; let
  `flutter_localizations` choose it at T10. Each owning task re-adds its package
  with its own DECISIONS record. `flutter_svg` was already recorded
  (T04-DEPENDENCY-FLUTTER-SVG).
- `decimal 2.3.3` is kept: exact money maths (AGENTS 2.3, SPEC 4.1). Licence
  BSD-3-Clause, runs fully on device, no network, released within the last 12
  months.

### CR-09-ANDROID

- Added the Android platform with `flutter create --platforms=android .` so v1
  can run on Android (AGENTS 11) and the T07/T08/T11 device tests have a target.
  `analysis_options.yaml` now excludes `android/**`. Android lock and keystore
  stubs stay with T08.

### CR-10-DOC-NAMES

- The repo is the only source (no parent copies). Rule and reference docs use
  their canonical names, which most cross-references already used: `AGENTS.md`,
  `SPEC.md`, `DESIGN.md`, `docs/spec/SPEC_REFERENCE.md`,
  `docs/design/DESIGN_REFERENCE.md`,
  `docs/approved-architecture/SYSTEM_DESIGN.md`,
  `docs/approved-architecture/DATABASE_DESIGN.md` and
  `docs/flows/USAGE_FLOWS_REFERENCE.md`. Cross-references were corrected in the
  same change.
- Link repair: `DESIGN_REFERENCE.md` now uses `../screens/` and `../spec/`
  paths; `USAGE_FLOWS_REFERENCE.md` now uses `../approved-architecture/`
  paths for system, database, widget-framework and execution-safety docs, and
  links its short core to `../flow.md` (`docs/flow.md` is the short core, not
  a separate `docs/USAGE_FLOWS.md`). Verified with a local link check: 0 bad
  `.md`/`.sql`/`.png` links.

### CR-16-COVERAGE

- `coverage/` is ignored (`.gitignore`); the committed `coverage/lcov.info` was
  removed from git. Coverage numbers stay as pull-request evidence.

### CR-11-NEEDS-WANTS (accepted as is)

- REVIEW-003 UX-3-07 and REVIEW-004 OB-FIN-16 query Needs and Wants. SPEC
  (SPEC_REFERENCE.md 9.3) already defines them as the two parts of spent "from
  the user's category tag (`isEssential`)", states "They are labels, not
  judgements", and "The app sets no target for them". `isEssential` is a user
  tag (spec-data-model.md 3). The values are the user's own split; the app adds
  no target, score or advice, so AGENTS 2.2 holds. Decision: accept as is; no
  Home change. The Appendix A needs/wants table is sample data (user tag).

### R01-FIT-NUMBER

- R01: `FitNumber` (`lib/design/format/fit_number.dart`) shrinks the hero
  number from its style size down to 40, never below, with no ellipsis and no
  removed digits. Below 40 it wraps at group boundaries with zero-width spaces.
  It follows the system text scale. `ObHero` paints the hero number through it
  and stacks side figures in a column at large text sizes. Goldens cover the
  long amounts at 1.0 and 2.0.

### R02-VALUE-STATES

- R02 / CR-03: `ValueSpec` has named constructors only (`real`, `estimated`,
  `expected`, `noneRecorded`, `missing`, `oldPrice`), so an invalid
  state/value pair cannot be built. Labels are required for the non-real
  states. `formatValueState` in `lib/design/format/` is the one place that
  turns a spec into pixels and semantics. `MoneyText` and `ObHero` share it.
  Estimated shows "Est.", expected shows "Expected", none-recorded and missing
  never render blank or zero. Hidden mode shows the mask in pixels and
  `amountHiddenLabel` in semantics (CR-07).

### CR-01-TOKENS-G

- CR-01 option (a): `lib/design/tokens/tokens.g.dart` is committed.
  `.gitignore` ignores `*.g.dart` with an exception for this file. A clean
  clone builds without a generator. `check_tokens` proves the file matches
  `tokens.json`. Drift/Riverpod `*.g.dart` files follow the same rule when
  their owners add them.

### CR-03-07-MONEY-HERO

- CR-04: hero number fits through `FitNumber` (R01). CR-05: the unused
  `ObHeroVariant.period` was removed; it returns with the T11 period chart.
  CR-06: `formatMoney` has `SignStyle.none | negativeOnly | always` with the
  true minus U+2212 and `+` for gains. CR-07: hidden semantics use the l10n
  word, pixels keep the dots.

### CR-12-PINNED-CURRENCY

- CR-12: `Currency.of(code)` is the pinned ISO 4217 table for production
  code (DATABASE_DESIGN 3). The public factory stays for tests only, to build
  edge cases. Production code must not pass its own `minorUnits`.

### CR-13-MULTI-CURRENCY

- CR-13: `$` marks USD only. In a view with more than one currency, show the
  code so CAD, AUD and SGD amounts are not confused with USD. `currencyMark`
  already falls back to the code for unknown marks.

### CR-14-UPPERCASE-SEMANTICS

- CR-14: kickers, periods and card meta paint uppercase but keep the
  original-case string in `semanticsLabel`, so a screen reader does not spell
  them out. Uppercase transform stays visual only.

### CR-15-TEXTALIGN-END

- CR-15: `MoneyText` uses `TextAlign.end`, not fixed `TextAlign.right`, so a
  future right-to-left layout costs nothing. v1 stays left-to-right.

### R07-CONTRAST-GATE

- R07 / CR-19: `tool/check_contrast.dart` records below-minimum pairs as
  failures while their decision id is still an open question. An exemption
  passes only when its id is in `_closedDecisions` and recorded under
  "Decided" here. It checks the composited `pageSpotlight` surface (DESIGN 9)
  and reports unrounded values. Current open ids: `LIGHT-LOSS-CONTRAST`,
  `T05-HERO-FILL-CONTRAST`.

### CR-18-FROMMINOR

- CR-18: `Money.fromMinor` no longer range-checks. A Dart `int` cannot exceed
  the signed 64-bit range, so the check cost one BigInt per amount for no
  effect. `_of` still checks every computed value. Behaviour is unchanged.

### R08-HANDOFF (partly done)

- R08: `docs/approved-architecture/database/SCHEMA.sql` (v1.5 reference
  schema) is present with `table-map.md`, `query-contracts.md` and
  `shared-state.md`. Canonical doc paths are fixed and verified with 0 bad
  links (CR-10). Still with T07: old-schema migration fixtures, reference
  validators and the architecture manifest. T07 must translate SCHEMA.sql
  into Drift, not use it as a production migration. PF-01 and product
  correction gates stay open.

### PF-01-ANDROID

- N-01: the release manifest sets `android:allowBackup="false"` and
  `android:dataExtractionRules="@xml/data_extraction_rules"`, and
  `res/xml/data_extraction_rules.xml` excludes every domain (`root`, `file`,
  `database`, `sharedpref`, `external`) for both `cloud-backup` and
  `device-transfer`. The release manifest holds no INTERNET permission;
  only the debug and profile manifests do. `test/privacy/` checks both
  files. Deviation from the review: `android:fullBackupContent="false"` was
  not set because that attribute takes a resource reference, not a boolean;
  `allowBackup="false"` plus the rules file already opts out of Auto Backup
  and device transfer.

### T06-N-FIXES

- N-02 (W3.7): `WidgetDescriptor.metricKeys` declares the canonical keys a
  placement leases. `WidgetSurfaceHost` takes the store and wraps each shown
  placement in a lease widget that acquires in `initState` and releases in
  `dispose`; a hide releases at once. Test widgets `test.alpha`/`test.beta`
  carry keys; a host test asserts acquire on show and zero subscribers on
  hide.
- N-03: `LayoutEditor.done()` returns `InheritDefault` (candidate back at
  the default) or `SaveLayout` (one commit). `applyDone` maps them to
  `clear()` and `save()`; `StoredLayout` keeps `newInThisVersion`
  deliberately for T07. W-J tests: Default then Done stores no row;
  stamp-only Done writes once. Clearing an absent row notifies no one.
- N-04: `_newKeys` session tracking is removed. `done()` reports candidate
  keys minus default keys minus keys present at session open, so a move, an
  add-then-hide, or an earlier-release addition is never new. Tests cover
  all three.
- N-05: `MetricValue` carries a `ValueSpec` (null only while loading) with a
  `presentation` getter; `Object? value` is removed. New
  `ValueSpec.notAvailable` and `ValueSpec.loading` states with required
  labels. `WidgetPreviewBuilder` takes `ValueSpec?`.
- N-09: the half-pair grid is `WidgetGrid` in `lib/design/layout/` and the
  fallback is `UnavailableCard` in `lib/design/components/`; both are
  exported from `lib/design/design.dart`. The host label is required (l10n
  in T10).
- N-12: edit-mode slot content is wrapped in `ExcludeSemantics` as well as
  `IgnorePointer`; the tool row stays accessible.
- N-13: `hide()` on an absent key returns early with no undo snapshot.
- N-14: empty labels are rejected for every state, not only the unknown
  ones.
- N-16: the hero side-figure period uses the one rule (visual uppercase,
  original-case semantics). Components goldens were re-baselined for this
  intended change only; the new baselines were inspected.
