# Contour — Phase 1 Tasks (Base)

Version: 2026-10-17. Scope: Phase 1 only. Authority order: AGENTS.md, SPEC.md + docs/spec/, SYSTEM_DESIGN in docs/approved-architecture/SYSTEM_DESIGN.md, DATABASE_DESIGN in docs/approved-architecture/DATABASE_DESIGN.md, DESIGN.md + docs/design/, docs/screens/SCREENS.md, docs/flow.md + docs/flows/USAGE_FLOWS_REFERENCE.md. Do not inspect wealthfolio/. PF-01 stays in force. Use synthetic data only. Do not invent financial or privacy rules.

## Phase 1 kickoff status (2026-10-17)

### Roll-up (2026-11-22, final)

- Done (reviewed 2026-11-22): T01-T12 complete for Phase 1. T05
  carries the open `period` hero variant (charts land in a later phase);
  T07 carries the SQLCipher device gate and the absent migration sources;
  T08 carries the native auth/key-store/control-store bindings; T11
  carries the native delete-all sequence and real exclusion verification.
- G01 closed on 2026-11-22 (DECISIONS "Decided"): no decision blocks later
  work. Remaining work is the device gates (PF-01, DB-A/DB-B, T08/T11
  native bindings).
- Phase 2 plan: `docs/TASKS_PHASE2.md` (2026-11-22, 29 tasks P01-P29).
  **Accepted 2026-11-23** (`docs/PHASE2_ACCEPTANCE.md`; DECISIONS
  `CLOSED-PHASE2-ACCEPTANCE`). It names the six open gates this phase needed
  (G02, G05, G06, G07, G12, G13) and four planning gaps recorded in DECISIONS
  "Open questions" (P2-INBOX-PRODUCER, P2-SPEND-NEXT-INCOME, P2-SEARCH-ENTRY,
  P2-REFUND-PERIOD).
- Next: Phase 3 plan `docs/TASKS_PHASE3.md` (2026-11-23). The **PDF-only
  slice** is implemented (`docs/PHASE3_ACCEPTANCE.md`; DECISIONS
  `P3-PDF-SUBSET`): reader, statement rows, Teach once, staging, X63–X68 and
  X88. Deferred with no route: CSV, Excel, OFX, QIF, CAMT.053, MT940, QR,
  receipt photo, holdings screenshot, share intake and `G03`.
- Home with data: the debug demo mounts X10 (`docs/DECISIONS.md`
  `P4-HOME-DATA`). Release keeps X03 until the vault composition.
- Test state: `flutter test test` 345 pass (measured 2026-11-22);
  `flutter test --tags golden` 33 pass and stable (4 + 4 component/gallery +
  20 Phase 1 screens + 4 new components + 1 l10n check; the count grew from
  8 with T10);
  `flutter test integration_test/phase1_smoke.dart -d <simulator>` passes.
- Gate state: `dart format`, `flutter analyze`, `custom_lint`, `check_tokens`
  (now with the unused-token check, T03-UNUSED-TOKENS) and `gen-l10n` pass.
  `check_contrast` **passes** (545 pairs): the two contrast decisions closed
  on 2026-11-22 by changing the token values (LIGHT-LOSS-CONTRAST,
  T05-HERO-FILL-CONTRAST; DECISIONS "Decided"). Light goldens were
  regenerated for the token change (loss #C2263A, hero-fill stop #4A4D56);
  the images were checked.
  Typed drift generators are deferred with typed reads (T07-TYPED-TABLES).

### Decision-closure work (2026-11-22)

- Closed four open decisions without new feature tasks (see DECISIONS
  "Decided"): LIGHT-LOSS-CONTRAST and T05-HERO-FILL-CONTRAST by changing the
  token values in a design-owner change approved in this session
  (`tokens.json`, `DESIGN.md`, `DESIGN_REFERENCE.md`; `check_contrast` passes,
  545 pairs); T03-UNUSED-TOKENS by adding the unused-token check to
  `check_tokens.dart` with the documented reserve list, plus the AppText
  family-token fix; T06-L10N-CONSTANTS by moving the component label
  constants to l10n (`widgetNotLoadedYet`, `widgetUnavailable`, `widgetEdit*`
  strings, `WidgetEditBarLabels.of`, host parameter docs).
- Deliberate golden updates for the token change: `components_light`,
  `gallery_light` and the X03 screen light goldens regenerated (Light loss
  and hero-fill tokens only affect Light); the images were checked.
- Second closure round (2026-11-22, owner delegated this session): kept the
  derived Light token values (T03-DERIVED-TOKENS), the unscaled FitNumber
  floor (FITNUMBER-FLOOR), the hero marker style (HERO-MARKER-STYLE), the
  F01 timing for the currency sheet (T10-CURRENCY-CHOOSER), the BrandMark
  painter for Phase 1 (T10-BRANDMARK), the Phase 1 test-widget acceptance
  (WIDGET-X03-DEFAULT), SPEC W13's preferred layout-upgrade rule
  (LAYOUT-UPGRADE) and the 1.3 reflow threshold (WIDGET-HALF-REFLOW). All
  carry their rationale in DECISIONS "Decided".
- Third closure round (2026-11-22, owner instruction "use the definitions
  already; research and choose"): G14/FIN-3 closed on the printed
  definitions (13.2 → 3,796,960; 13.4 → 94,529,640 ±1; the NUM-001 bridge;
  the two-cut-off Appendix A cash reading; the FIN-3 gate lifts);
  T05-NUMBER-LOCALE closed (fixed English format for v1 English);
  SCREEN-REFERENCES closed (design-mockups dark/light are the visual
  reference for both themes).
- Still open: PF-01 (stays in force; closing needs a
  supported compliant path or an explicit policy revision), and the
  T07/T08/T11 device gates. The independent reviews closed on 2026-11-22.
  G01 closed on 2026-11-22 (DECISIONS "Decided", CLOSED-G01-ACCOUNT-
  PREREQUISITES): the anchor and accepted-postings definitions are decided,
  so F01, F03, F05, F06 and F10 may plan in Phase 2.
- Track A bindings landed 2026-11-22 (DECISIONS CR-19-NATIVE-BINDINGS):
  the T08 auth/key-store/control-store bindings and the T11 native
  exclusion channel exist behind their ports, host-tested; the iOS
  simulator build compiles the runner glue and the plugin pods. The app
  composition stays unwired until PF-01 and DB-A close. Remaining device
  gates: DB-A (pinned SQLCipher build), DB-B (T07-MIGRATION-SOURCES: the
  reference scripts are absent from this checkout and cannot be invented),
  S06/S01 device evidence, the Android compile check (no Android SDK on
  this host), and the real delete-all sequence.
- Screen-material fix 2026-11-22 (DECISIONS FIXED-SCREEN-MATERIAL-
  ANCESTOR): `PageBackground` now provides the page `Material` ancestor;
  the app runs correctly on the iOS simulator (X01 verified against the
  golden). The golden-harness masking gap is recorded there.

### Workspace verification

- The workspace is a git working tree. Branch and pull-request rules (AGENTS 8) apply.
- `flutter analyze`: no issues. `dart run custom_lint`: no issues. `flutter test`: 226 pass; `flutter test --tags golden`: 8 pass (T04 gallery + T05 components, dark/light, 1.0/2.0). `flutter gen-l10n` and the integration smoke test pass; `check_contrast` fails by design on the two open decisions.
- T01-T06 and T12 are complete; T05 is complete except the `period` hero variant (T11 charts). The token tools (T03), golden tests (T04), Phase 1 components (T05), the widget framework (T06), the lint plugin and l10n now exist. `build_runner` waits for T07 to add the generators.
- Present: `tool/`, `tool/lints/`, `integration_test/`, `docs/DECISIONS.md`, `lib/core/`, `lib/design/`, `lib/l10n/`, `lib/app/widgets/`, `lib/features/home/widgets/` (T06 test widgets), `docs/approved-architecture/database/SCHEMA.sql`. Still absent: `lib/domain/`, `lib/data/`, `docs/screens/*.png`, `docs/WIDGET_CATALOGUE.md` (current source is `docs/spec/spec-widgets.md`).

### Independent tracks (after T01; run in parallel)

- core — T02 (done), T02b (done). Owner: Domain builder. Files: `lib/core/*`, `test/core/*`.
- design-system — T03 (done) → T04 (done) → T05 (done) → T06 (done, reviewed 2026-11-22). Owner: Design-system builder. Files: `lib/design/*`, `tool/gen_tokens.dart`, `tool/check_tokens.dart`, `tool/check_contrast.dart`, `test/golden/design/*`.
- native-storage — T07 (blocked input) → T08 (and T11 later). Owner: Data builder then Native builder. Files: `lib/data/*`, `lib/app/auth/*`, `native/*`.

### Contract every task and pull request must name

Taken from `docs/flow.md`, "A task must name its contract":

```
Flow and steps · Screens and templates · References (SPEC / DESIGN / gate)
Inputs · User actions · Read model · Commit boundary · Written records
Success · Failures · Cancellation · Checks
```

### Shared-file ownership (one current owner)

- `pubspec.yaml`, `analysis_options.yaml`: T01 owner, Domain? No — T01 Foundation owner.
- `lib/design/tokens/tokens.json`: T03 owner only.
- `lib/app/router.dart` + `lib/app/section.dart` routing: T09 owner only.
- `lib/data/db/schema/*`, migrations: T07 owner only.
- One agent edits a file at a time. Other tasks must request a small separate pull request for shared files.

## Blocked prerequisites (do not close in feature code)

- G01 Account prerequisites: CLOSED 2026-11-22 (DECISIONS "Decided",
  CLOSED-G01-ACCOUNT-PREREQUISITES). Basic bank, cash and card setup +
  opening balances build in the base phase against the decided inclusive
  balance anchor and accepted-postings rule; no new product decision blocks
  F01, F03, F05, F06, F10. Source: docs/flow.md, docs/flows/USAGE_FLOWS_REFERENCE.md.
- WIDGET-X03-DEFAULT: Phase 1 acceptance stands with test widgets and the test layout file (spec-widgets W8/W11); the approved catalogue entry is a Phase 2 planning input. CLOSED for Phase 1 on 2026-11-22 (DECISIONS "Decided"). Source: docs/spec/spec-widgets.md, widget-framework.md.
- LAYOUT-UPGRADE: closed 2026-11-22 (DECISIONS "Decided"): SPEC W13's preferred rule is adopted for production; the reference model already implements and tests it. Source: docs/spec/spec-widgets.md W10, DATABASE_DESIGN.md:225.
- WIDGET-HALF-REFLOW: closed 2026-11-22 (DECISIONS "Decided"): the interim threshold (above 1.3 on phones) is the rule; re-derive from device geometry benchmarks before the geometry sign-off.
- PF-01 phone confinement: no personal-data persistence, no iOS release claim. Prototype with synthetic data only. Source: SYSTEM_DESIGN.md 12.2.
- Screen references: `design-mockups/dark/` and `design-mockups/light/`
  (25 + 25 photos of the gallery pages) are the visual reference for both
  themes from 2026-11-22 (DECISIONS CLOSED-SCREEN-REFERENCES); map screen ids
  to photos by content. docs/WIDGET_CATALOGUE.md absent (current source is docs/spec/spec-widgets.md). `SCHEMA.sql` is now present at docs/approved-architecture/database/SCHEMA.sql. lib/core (T02-T02b), lib/design (T03-T05), tool/ and docs/DECISIONS.md now exist. T07 must translate DATABASE_DESIGN + database/table-map.md + query-contracts.md + shared-state.md. Do not invent tables.
- CASHFLOW-*, SUBS-TOTAL, REGULAR-INVEST, HOME-GOALS-NAME: block later financial widgets only, not Phase 1 host.
- FIN-3 gate: lifted 2026-11-22 (DECISIONS CLOSED-G14-FIN-DEFINITIONS). The
  printed definitions in spec-calculation.md are the source of truth (13.12
  TWR denominator; 13.2 `lumpToday = need / (1 + r)^years` → 3,796,960; 13.4
  → 94,529,640 ±1; the NUM-001 four-part bridge; the Appendix A two-cutoff
  cash reading). `lib/domain/numbers` work may start in Phase 2 planning
  with the Appendix A fixtures.

## Task order

Foundation first: T01. Then parallel tracks only after T01 merges: core (T02), design-system (T03-T06), native-storage (T07-T08). Screens (T09-T11) after framework + storage interfaces exist. Tooling (T12) runs through all tasks.

---

### T01 — Flutter project foundation

- Objective: create runnable empty Flutter project with folders, dependencies, analysers. Refs: AGENTS.md 3, 4, 6.1, 6.8; SPEC 10.1, 10.2, 17 Phase 1; SYSTEM_DESIGN 1 A01, A11.
- Dependencies: none. Blocks all other Phase 1 tasks.
- Owner: Foundation builder (planner role). Files allowed: `pubspec.yaml`, `analysis_options.yaml`, `lib/main.dart`, `lib/app/app.dart` stub only, folder READMEs, `.gitignore` update. No feature code. No network packages except allowed price gateway stub (off by default).
- Provides: project builds with `flutter analyze`. Consumes: none.
- Acceptance: `flutter analyze` passes. `flutter test` runs zero tests with pass. No analytics, crash, ads, remote-config packages. Dependencies recorded with OSI licence + release date + network statement.
- Evidence: `flutter analyze` log, `flutter test` log, `pubspec.yaml` diff. Reviewer: privacy and security.
- Status: done 2026-10-17. Files: pubspec.yaml, analysis_options.yaml, lib/main.dart, lib/app/app.dart, .gitignore, lib/README.md, ios/ via flutter create, test/widget_test.dart smoke. Checks: flutter pub get pass, flutter analyze no issues, flutter test 1/1 pass. No Podfile: no native plugins yet, pod install not required. Reviewed 2026-11-22 (privacy and security). Shared-file owner for pubspec-yaml. Verified 2026-10-17: still no issues; the core tests in T02 build on this foundation.

### T02 — Core value types

- Objective: pure-Dart Money, Decimal policy, LocalDate, Clock, Result, UUIDv7 codec. Refs: SPEC 4.1, 4.2, 4.9; AGENTS.md 6.3, 6.4.
- Dependencies: T01. Blocked by: none. G01 does not block types.
- Owner: Domain builder. Files allowed: `lib/core/money.dart`, `lib/core/decimal.dart`, `lib/core/dates.dart`, `lib/core/ids.dart`, `lib/core/result.dart`, `test/core/*_test.dart` only.
- Provides: `Money(minor,currency)`, `Decimal` helpers, `LocalDate`, `Clock`, `Result`. Consumes: T01 project only.
- Acceptance: failing tests first, then pass. 100% line coverage on new files. No `double` for money. No `DateTime.now()` in functions. No Flutter imports in `lib/core/` or `lib/domain/`.
- Evidence: test file diff + coverage report + `dart format` log. Reviewer: product and finance.
- Status: done 2026-10-17, reviewed 2026-11-22. Files: `lib/core/money.dart`, `lib/core/decimal.dart`, `lib/core/dates.dart`, `lib/core/ids.dart`, `lib/core/result.dart`; tests `test/core/{decimal,money,dates,ids,result}_test.dart`. Evidence: tests written first and seen to fail (missing-source compile errors), then 42 core tests pass; `flutter analyze` no issues; `dart format --set-exit-if-changed` no diff; 100% line coverage on all five files (lcov: money 60/60, decimal 25/25, dates 48/48, ids 49/49, result 8/8). Uses `package:decimal` only; no `double` for money; no `DateTime.now()`; no Flutter import in `lib/core`. Reviewer: product and finance (reviewed 2026-11-22).

### T02b — Percent split and largest remainder

- Objective: `Percent.split` that makes parts add to exactly 100%, plus change/percentage helpers. Refs: SPEC 4.1, 4.2, Appendix A shares; AGENTS 6.4; DESIGN 4.
- Dependencies: T02. Blocks percentage display, split bars and `X23Split`.
- Owner: Domain builder. Files allowed: `lib/core/percent.dart`, `test/core/percent_test.dart` only.
- Provides: largest-remainder split with a deterministic tie-break and signed parts. Consumes: T02 `Decimal`.
- Acceptance: failing tests first, then pass. Every split adds to the exact whole. Ties break deterministically (largest remainder, then stable input order). 100% line coverage. Reviewer: product and finance.
- Evidence: test diff, coverage log, `dart format` log. Reviewer: product and finance.
- Status: done 2026-10-17, reviewed 2026-11-22. Files: `lib/core/percent.dart`, `test/core/percent_test.dart`. Evidence: tests written first and seen to fail (missing-source compile errors), then 19 tests pass; `flutter analyze` no issues; `dart format --set-exit-if-changed` no diff; 100% line coverage (lcov 54/54). The Appendix A home split at scale 1 gives 35.2, 12.8, 0.0, 52.0, sum 100. Reviewer: product and finance (reviewed 2026-11-22).

### T03 — Design tokens foundation

- Objective: tokens.json single source + generator + Contrast check. Refs: DESIGN 0-2; SPEC 7; AGENTS.md 4, 6.9.
- Dependencies: T01. Blocks T04-T06.
- Owner: Design-system builder. Files allowed: `lib/design/tokens/tokens.json`, `tool/gen_tokens.dart`, generated `tokens.g.dart` via generator only, `tool/check_tokens.dart`, `tool/check_contrast.dart` wiring only.
- Provides: `context.tokens` roles used by T04. Consumes: none.
- Acceptance: `dart run tool/gen_tokens.dart` regenerates without diff. `dart run tool/check_tokens.dart` passes. `dart run tool/check_contrast.dart` passes for Phase 1 roles. Dark + Light values for every colour token. No colour literals elsewhere.
- Evidence: generator log, check logs, tokens diff. Reviewer: design and accessibility.
- Status: done 2026-10-17, reviewed 2026-11-22. Files: `lib/design/tokens/tokens.json`, `lib/design/tokens/token_types.dart`, generated `lib/design/tokens/tokens.g.dart`, `tool/token_gen_lib.dart`, `tool/gen_tokens.dart`, `tool/check_tokens.dart`, `tool/check_contrast.dart`; `docs/DECISIONS.md` created. Evidence: `dart run tool/gen_tokens.dart` writes the same file twice (idempotent); `check_tokens` OK; `check_contrast` OK (525 pairs) with two documented warnings; `flutter analyze` no issues; `dart format --set-exit-if-changed` no diff; `flutter test` 62 pass at T03 (81 pass now with later tasks). `lib/app/app.dart` now uses `ColorTokensDark.palettePage`, so no colour literal is outside `lib/design/`. Open: T03-DERIVED-TOKENS and LIGHT-LOSS-CONTRAST in `docs/DECISIONS.md`; the unused-token check starts in T04. Reviewer: design and accessibility (reviewed 2026-11-22).

### T04 — Theme, section, type, icons minimal

- Objective: Obsidian dark/light themes, SectionScope, AppText subset, AppIcons subset for Phase 1 screens. Refs: DESIGN 2-3; SPEC 7.
- Dependencies: T01, T03.
- Owner: Design-system builder. Files allowed: `lib/design/theme/*`, `lib/design/typography/*`, `lib/design/icons/*`, `test/golden/design/theme_*` + gallery entries only.
- Provides: `AppTheme.dark/light`, `SectionScope`, `AppText.*`, `AppIcons.*`. Consumes: T03 tokens.
- Acceptance: gallery entry + goldens dark/light, scale 1.0/2.0. Text >=13pt except 12/11 allowed roles. Contrast >=4.5:1. No `TextStyle` outside `lib/design/`.
- Evidence: golden images + `flutter test --tags golden` log + lint log. Reviewer: design and accessibility.
- Status: done 2026-10-17, reviewed 2026-11-22. Files: `lib/design/theme/app_theme.dart` (ContourTokens + AppTheme), `lib/design/theme/section.dart`, `lib/design/typography/app_text.dart`, `lib/design/icons/app_icons.dart`, `lib/design/gallery/gallery.dart`, `lib/design/design.dart`; fonts `lib/design/fonts/*` (Inter 4.1, OFL), icons `lib/design/icons/*.svg` (Lucide, ISC); `test/golden/design/*` and baseline PNGs; `dart_test.yaml`. Evidence: `flutter test` 72 non-golden pass; `flutter test --tags golden` 4 goldens pass (dark/Light, 1.0/2.0) at T04 (8 goldens now, T05 adds 4). `flutter analyze` no issues; `dart format --set-exit-if-changed` no diff. `git` absent, so the baseline PNGs are the committed images for review. Open: the `custom_lint` design rules do not exist yet (T12). Reviewer: design and accessibility (reviewed 2026-11-22).

### T05 — Layout templates + Phase 1 components

- Objective: TabRootScreen, DetailScreen, start-screen host, ObHero (number + 0Hero), GlassCard, ScreenHeader, AppButton, WidgetSlot host placeholder. Refs: DESIGN 5-6; SPEC 3.3, 6.1; SCREENS.md rules.
- Dependencies: T01, T03, T04.
- Owner: Design-system builder. Files allowed: `lib/design/layout/*`, `lib/design/components/hero/*`, `lib/design/components/surfaces/*`, `lib/design/components/buttons/*`, gallery + goldens for each variant only.
- Provides: templates + components consumed by T06, T10. Consumes: T03-T04.
- Acceptance: one control row lint passes. One add control lint passes. Every tappable has semantic label. Every money widget has hidden state. Goldens dark/light 1.0/2.0. `custom_lint` passes (no_color_literals, no_text_style, no_raw_spacing, etc.).
- Evidence: gallery + goldens + lint logs. Reviewer: design and accessibility.
- Status: done 2026-11-21, reviewed 2026-11-22. Built: `TabRootScreen`, `DetailScreen`, `FormScreen`, `PageBackground`, `GlassCard` (normal, stage, wide; CARD-TITLE-OUT title/meta), `ScreenHeader`, `WidgetSlot` (normal, editing), `AppButton` (primary, neutral, ghost, soft, destructive; disabled, icon, compact, full width), `AppIconButton` (onPage, onCard, plain), `InfoButton`, `ObHero` (number, detail; hidden, side figures; split number), `HeroAmount`/`formatHeroValue`, `MoneyText`/`ValueSpec`/`ValueState`/`formatValueState`/`FitNumber` in `lib/design/format/`, `DashedOutline` in `lib/design/components/surfaces/`; `Space`/`VSpace`/`HSpace`. Gallery `lib/design/gallery/components_gallery.dart`; goldens `test/golden/design/components_{dark,light}_{1.0x,2.0x}.png`; `test/design/components_test.dart` (format + value states + hidden + hero parts + dashed outline), `test/design/hero_value_test.dart`, `test/design/fit_number_test.dart`. Tokens added: `color.role.text.heroFill` (DESIGN 14.1c), `space.cardTitleGap` (10), `color.role.border.draft` (white 22% / ink 25%, WIDGETS-001). Checks: `flutter analyze` clean; `check_tokens` OK; `check_contrast` fails by design on the two open contrast decisions (R07); `flutter test` pass; `flutter test --tags golden` 8 pass and stable. Done 2026-11-21: hero split-number typography (currency mark 0.45 em weight 300 raised, cents 0.5 em `text.secondary`, main fill; the one-string `FitNumber` fallback keeps wrapping at the 40 pt floor), dashed edit outline (1 pt, 6 pt outside), and the `Est.`/`Expected` marker in the caption style. Open: `ObHeroVariant.period` stays out until the T11 charts (HERO-PERIOD); `HERO-MARKER-STYLE` still needs owner confirmation; `FITNUMBER-FLOOR` stays open; `custom_lint` now passes (T12); `T06-L10N-CONSTANTS` stays for T10. Reviewed 2026-11-22 (design and accessibility).

### T06 — Widget framework Phase 1 (registry, host, layout repo, editor)

- Objective: independent registry, two-level surface host, layout repository/editor, bundled default layout file, test widgets for X03. Refs: SPEC W1-W13, W8; SYSTEM_DESIGN 3.1, 8.3; DATABASE_DESIGN 5.1; widget-framework.md; usage-flows F01.
- Dependencies: T01, T05, T07 (layout tables interface only). Continues when T07 blocked: use in-memory layout repo with same interface, mark Drift wiring pending.
- Owner: Feature-framework builder (app role). Files allowed: `lib/app/widgets/registry.dart`, `lib/app/widgets/host.dart`, `lib/app/widgets/editor.dart`, `lib/app/widgets/default_layout.dart` (compiled constant), `lib/features/home/widgets/test_*.dart`, `test/widget_framework/*_test.dart` only. No screen-key switches in screens.
- Provides: `WidgetRegistry`, `SurfaceHost`, layout edit session (private candidate, Done commits touched surfaces, Cancel writes nothing). Consumes: T05 templates, T07 layout tables (or in-memory stub with identical API).
- Acceptance: W-A to W-L subset for Phase 1 with test widgets: registry from Phase 1, no fixed cards, Done/Cancel semantics, resident-only Add preview shows Not loaded yet on cache miss, hidden lease release. Tests use synthetic layout only. WIDGET-X03-DEFAULT stays open — test catalogue row only, flagged `// DECISION-PENDING: WIDGET-X03-DEFAULT`.
- Evidence: unit tests + widget tests + editor convergence test logs. Reviewer: product and finance + design and accessibility.
- Status: done 2026-10-17, reviewed 2026-11-22. Built: `lib/app/widgets/layout_model.dart` (`WidgetSize`, `LayoutPlacement`, `LayoutSection`, `SurfaceLayout`, `AddWidgetEntry`/`AddTarget`/`AddBlock`, `LayoutBundle` with rename chain, `LayoutFormatError`); `registry.dart` (`WidgetKind`, `WidgetDescriptor`, `WidgetRegistry.validate` for the supported W-L subset); `read_store.dart` (`MetricKey`, `MetricState`, `MetricValue`, `SharedReadStore`, `InMemoryReadStore`); `default_layout.dart` (test bundle); `layout_repository.dart` (`StoredLayout`, `LayoutRepository`, `InMemoryLayoutRepository`); `resolver.dart` (`LayoutResolver`, `ResolvedPlacement/Section/Surface`; unknown key skip W3.10, gate W3.12/6, size fallback W3.11, explicit-empty DB4-4, empty-section drop); `editor.dart` (`LayoutEditor` private candidate, hide/move/moveSection/add/take/insert/resetToDefault/undo/done/cancel, `LayoutCommit` with base version + new-in-version); `widget_surface_host.dart` (`WidgetSurfaceHost` two-level host with half-size pairing). Design additions: `lib/design/components/surfaces/widget_section.dart`, `widget_edit_bar.dart` (design-system file ownership cross — see DECISIONS T06-DESIGN-COMPONENTS). Test widgets: `lib/features/home/widgets/test_widget_catalogue.dart` (test.alpha/beta/gamma/own/tile.a). Tests: `test/widget_framework/*` (layout model, registry, resolver, editor, repository, read store; host widget tests). Checks: `flutter analyze` clean; `check_tokens` OK; `check_contrast` fails by design on the two open contrast decisions (R07); `flutter test` pass; `flutter test --tags golden` 8 pass. Open: WIDGET-X03-DEFAULT (test catalogue only); in-memory repo (T07 Drift wiring pending); l10n strings are constants (`testNotLoadedLabel`), replaced in T10; host pairing threshold stays interim per WIDGET-HALF-REFLOW; the `WidgetSlot` dashed outline now lands in T05 (T05-DASH-OUTLINE). Agent-review N fixes: placement leases with `metricKeys` (N-02, W3.7), sealed Done result with `applyDone` and W-J tests (N-03), session-based new-key set (N-04), `MetricValue` carries `ValueSpec` with loading and not-available states (N-05), host styling moved to `WidgetGrid`/`UnavailableCard` with a required label (N-09), edit-mode content excluded from semantics (N-12). Reviewed 2026-11-22 (product and finance + design and accessibility).

### T07 — Encrypted database, migrations, ChangeLog, layout tables

- Objective: Drift over verified SQLCipher, owner isolate, schema v1-v5 incl. layout_surfaces/sections/items, entity registry, operation intent/receipt, ChangeLog, read_revision. Refs: SYSTEM_DESIGN 2, 4-6, 12.1; DATABASE_DESIGN 1-6; SPEC 9; EXECUTION_SAFETY 1, 6.
- Dependencies: T01, T02. SCHEMA.sql is present at `docs/approved-architecture/database/SCHEMA.sql` — translate it from DATABASE_DESIGN + database/table-map.md + query-contracts.md + shared-state.md. Do not invent financial rules. G01 anchor definition pending — schema must support inclusive anchor without fixing its finance meaning. N-08 blocks start: choose the final product name and reverse-domain id (key-store aliases and the database path depend on it, CR-17-PACKAGE-NAME).
- Owner: Data builder. Files allowed: `lib/data/db/*` (schema, migrations, owner, codecs), `test/data/migration_*_test.dart`, fixtures synthetic only. Exclusive owner of schema files.
- Provides: `CommandRepository.execute`, owner-validated reads, `read_revision` advance, ChangeLog writes. Consumes: T02 codecs.
- Acceptance: migration tests with old-database fixtures pass. Database does not open without key. Foreign keys + recursive triggers verified each open. WAL + synchronous FULL + temp MEMORY verified. No Drift rows leak to features. Synthetic data only per PF-01. Python/SQLite checks alone do not count.
- Evidence: migration test logs, cipher negative-open test, `flutter analyze` log. Reviewer: privacy and security + product and finance.
- Status: done 2026-11-21, reviewed 2026-11-22. Built: `tool/gen_schema.dart` writes the verbatim SCHEMA.sql body (no pragmas, no BEGIN/COMMIT wrapper) plus the 90 reference table names to `lib/data/db/schema/reference_schema.dart`; `lib/data/db/statement_splitter.dart` (trigger-body-safe splitter); `lib/data/db/cipher.dart` (`VaultCipher` port, production `SqlCipherVaultCipher` fails closed, test-only adapters); `lib/data/db/connection_settings.dart` (foreign_keys, recursive_triggers, WAL, synchronous FULL, temp_store MEMORY, bounded busy timeout, `foreign_key_check`); `lib/data/db/migration.dart` (fresh create in one transaction, `db_state` seed, corrupt/newer/old-version fail-closed codes); `lib/data/db/app_database.dart`; `lib/data/db/vault.dart` (open sequence: key, cipher verify, settings, authenticated read, then owner connection on a persistent background isolate); `lib/data/db/read_revision.dart`; `lib/data/db/command_repository.dart` (prepare/execute protocol: durable intent + payload + digest, receipt-first retry, ChangeLog, commit sequence + read revision advance, post-commit notification); `lib/data/db/layout_repository.dart` (Drift-backed preference store: explicit DELETE then INSERT, dense positions, untitled rule, tile rules, 16/256/64 KiB bounds, DB4-4 explicit empty, read-revision advance). Tests: `test/data/*` (37 tests: splitter, fresh create with 90 tables + 332 triggers, fail-closed opens, WAL verification, reopen epoch stability, version guards, protocol tests, layout DB4-4..DB4-7 and bound tests). Checks: `flutter analyze` clean; `custom_lint` clean; `check_tokens` OK; `flutter test` 263 pass; goldens 8 pass; `check_contrast` fails only on the two pre-existing open decisions. Open (DECISIONS): T07-VAULT-CIPHER-BUILD (native SQLCipher device gate DB-A), T07-MIGRATION-SOURCES (reference upgrade scripts + frozen fixtures absent; fresh installs start at version 5), T07-TYPED-TABLES (drift generator tables land with typed reads). Reviewed 2026-11-22 (privacy and security + product and finance). Update 2026-11-22 (CR-19): the T08 bindings and the T11 exclusion channel are implemented behind the ports and host-tested; DB-A (pinned SQLCipher build) and DB-B (absent migration sources) stay device gates.

### T08 — App lock, keys, lifecycle control

- Objective: AuthPort, native biometric/device-credential, 256-bit keys, lock state machine, lifecycle control store, background mask/blur. Refs: SPEC 6.1 X02, 9.1, 11; SYSTEM_DESIGN 12.1, 12.3.
- Dependencies: T01, T07 (key + generation epochs only). Continues with fake KeyStore when native verification pending.
- Owner: Native builder. Files allowed: `lib/app/auth/*`, `lib/data/keys/*`, `native/android/*lock*` stubs, `native/ios/*lock*` stubs, `test/app/auth_*_test.dart` only. Domain/features never import platform packages.
- Provides: `AuthPort`, `KeyStore`, lock states closed/authenticating/opening/unlocked/closing/closed. Consumes: T07 epochs.
- Acceptance: F01-C: shared file exposes no content before unlock. Missing control state requires auth, never defaults to off. Off mode still checks epochs/keys/deletion. No secret in logs. Tests use injected monotonic clock, no wall clock.
- Evidence: unit tests + manual lock/unlock log on simulator + analyser log. Reviewer: privacy and security.
- Status: done 2026-11-22, reviewed 2026-11-22. Built: `lib/data/keys/keys.dart` (`VaultKey` opaque 256-bit holder with no textual form, `generateVaultKey(Random)` with injected randomness, `KeyStore` port, in-memory test store); `lib/app/auth/auth_port.dart` (`AuthPort`, typed outcomes, scripted test port); `lib/app/auth/auth_attempt.dart` (full attempt tuple with the recheck predicate); `lib/app/auth/lifecycle_control.dart` (`LockMode` immediately/1min(default)/5min/off, `ControlPolicy` with revision + pending-transition marker, `LifecycleControlStore` port, missing/unreadable never substitutes a default); `lib/app/auth/lock_controller.dart` (closed → authenticating → opening → unlocked → closing → closed; background masks and locks in immediately mode; timeout thresholds with the injected monotonic clock; off mode still checks keys, epochs and the deletion gate; full-tuple admission recheck after native success and again before keys open; policy changes recorded durably before enforcement, interrupted transitions enforce the stricter mode; event-only log surface). Tests: `test/app/auth_lock_test.dart` (12 tests: all four modes, threshold boundaries, missing control state, failed/cancelled challenge, deletion gate, policy-change flow, no-key-material check). Checks: `flutter analyze` clean; `custom_lint` clean; `flutter test` 275 pass; goldens 8 pass. Open (DECISIONS): T08-NATIVE-AUTHPORT, T08-NATIVE-KEYSTORE, T08-NATIVE-CONTROLSTORE (native bindings are the native builder's device work; the app composition wires a platform implementation behind the ports). Reviewed 2026-11-22 (privacy and security).

### T09 — Router + SectionScope + Phase 1 routes

- Objective: go_router with Section per route, routes X01, X02, X03, X80, X86 + gallery (debug only). Refs: SPEC 5.1-5.4; DESIGN 3; AGENTS.md 11.
- Dependencies: T01, T04, T06, T08.
- Owner: App builder. Files allowed: `lib/app/router.dart`, `lib/app/section_scope.dart` only. Exclusive owner of router.
- Provides: routes + SectionScope consumed by T10. Consumes: T06 host, T08 auth gate.
- Acceptance: deep link waits behind unlock, never replays Save/Confirm/Delete. No amounts in URLs/logs. Unavailable target returns to nearest parent. Tab re-select returns to root.
- Evidence: router tests + navigation test log. Reviewer: design and accessibility.
- Status: done 2026-11-22, reviewed 2026-11-22. Built: `go_router 18.1.4` added (DECISIONS CR-08); `lib/app/router.dart` (`AppRoute` paths/names X01, X02, X03, X80, X86 + debug-only gallery; `LockGate` port with the `AlwaysOpenGate` placeholder until T10 wires X02; redirect: unknown target → Home root, closed gate defers the bare path to X02 and resumes it after unlock, query and fragment always dropped so no amount or command survives a deep link; tab re-select returns to the tab root; event-only log surface); `lib/app/section_scope.dart` (route → Section mapping; Phase 1 all Home per SCREENS.md); `lib/app/app.dart` now builds `MaterialApp.router` with the Phase 1 router. Tests: `test/app/router_test.dart` (6 tests: bare-location reduction, SectionScope per route, deep link deferral + resume, unknown target → nearest parent, tab re-select, debug-only gallery) and `test/widget_test.dart` (smoke). Checks: `flutter analyze` clean; `custom_lint` clean; `flutter test` 282 pass; goldens 8 pass. Open (DECISIONS): T09-AUTH-GATE-WIRING (the real gate wires the T08 LockController when X02 is built). Reviewed 2026-11-22 (design and accessibility).

### T10 — Phase 1 screens (X01, X03, X80 skeleton, X86 base, X02 silhouette)

- Objective: build Welcome (currency required only), first-run Home state, Settings skeleton, Privacy base, Lock silhouette. Refs: SPEC 6.1, 6.9; SCREENS.md X01, X02, X03, X80, X86; flows F01, F19-base, F21-base.
- Dependencies: T05, T06, T09. G01 blocks final F01 acceptance but not skeleton build with `// DECISION-PENDING: G01`.
- Owner: Feature builder. Files allowed: `lib/features/start/*`, `lib/features/home/x03_*`, `lib/features/settings/x80_*`, `lib/features/settings/x86_*`, `lib/l10n/*` additions for these screens only, `test/golden/*` for these screens only.
- Provides: screens. Consumes: T05 components, T06 host/registry, T09 router, T08 lock.
- Acceptance: X01: one required choice (main currency), Start. X03: hero —, Get started 0 of 5, Next 30 days none recorded, sample Appendix A only where defined else Missing/None recorded. X80 skeleton list only. X86: network off, Delete-all entry. Banned-word check passes. One control row + one add control. Goldens dark/light 1.0/2.0. Usability F01-A passes with synthetic data.
- Evidence: goldens + `flutter test --tags golden` log + interface-check log + l10n diff. Reviewer: product and finance + design and accessibility.
- Status: done 2026-11-22, reviewed 2026-11-22. Built: `lib/features/start/x01_welcome.dart` (hero without number: kicker/title/line; BrandMark 64; three info rows with `IconTile`; the required main-currency `SelectRow` (informational until the chooser sheet lands, DECISION-PENDING: T10-CURRENCY-CHOOSER); Start button, caption); `lib/features/start/x02_lock.dart` (blurred generic Home silhouette via `TrackShape`, BrandMark 76, Locked, two unlock actions wired to comments until T09-AUTH-GATE-WIRING); `lib/features/home/x03_home_first.dart` (TabRootScreen; hero "—" via `ValueSpec.notAvailable`; Get started card with `CapsuleMeter` 0 of 5 + five `SelectRow` steps + caption; Next 30 days card, none recorded); `lib/features/settings/x80_settings.dart` (DetailScreen, hero without number, Capture/Money/Screens/Safety card skeleton rows); `lib/features/settings/x86_privacy.dart` (hero without number, Network card with the price-service row and the off toggle, On-this-phone card, destructive Delete all data + caption). l10n: 100 strings added to `lib/l10n/app_en.arb` (all screen text and semantic labels). Design additions (DECISIONS T10-DESIGN-ADD): `IconTile`, `TrackShape`, `SelectRow`, `ToggleRow`, `CapsuleMeter` (integer flex, no double), `BrandMark` painter under `lib/design/charts/` with the lint exemption for the brand gradient, `AppIcons.phone` (Lucide smartphone SVG, ISC). Goldens: `screens_golden_test.dart` (20: five screens × dark/light × 1.0/2.0) plus the SPEC 16.3 banned-word and no-zero checks over every Phase 1 string; `extra_components_golden_test.dart` (4). Deliberate golden updates: gallery goldens changed by the added `phone` icon (one extra icon-grid cell); SelectRow wraps its value at 2.0 scale (overflow fix, checked in the regenerated images). Checks: `flutter analyze` clean; `custom_lint` clean; `flutter test` 306 pass; `flutter test --tags golden` 33 pass; `check_tokens` OK; `gen-l10n` pass; `check_contrast` fails only on the two pre-existing open decisions. Open (DECISIONS): T10-CURRENCY-CHOOSER, T10-BRANDMARK (brand asset absent), G01 (F01 final acceptance). Reviewed 2026-11-22 (product and finance + design and accessibility).

### T11 — Privacy policy test + Delete-all skeleton (no real data)

- Objective: network-off enforcement test, backup/transfer exclusion wiring, Delete-all intent plumbing (destructive confirm UI only in Phase 1). Refs: SPEC 2, 10.5, 11, 14; SYSTEM_DESIGN 11-12; flows F21.
- Dependencies: T07, T08, T10.
- Owner: Native builder (with Data builder review). Files allowed: `lib/data/prices/gateway_stub.dart` (off by default), `lib/data/backup/exclusions.dart` stub, `lib/features/settings/delete_all_*` UI only, `test/privacy/*_test.dart` only.
- Provides: gateway off gate, exclusion flags. Consumes: T07 generations, T08 lifecycle.
- Acceptance: price request while off is rejected. No balances/quantities/names in request DTO. PF-01: no real-user persistence claim. Delete-all requires confirm, removes synthetic snapshot + keys in test. No email/SMS/bank credentials requested.
- Evidence: privacy tests + traffic test (zero non-gateway sockets) log. Reviewer: privacy and security (reviewed 2026-11-22).
- Status: done 2026-11-22, reviewed 2026-11-22. Built: `lib/data/prices/gateway_stub.dart` (the allowed request contract, `NetworkGate` off by default with a policy epoch advanced on every change, `GatewayOffStub` that rejects every request while off, validates identifiers first, enforces the 50-symbol batch bound and performs no I/O in either state; request DTOs carry public identifiers only); `lib/data/backup/exclusions.dart` (`ProtectedPathKind` structural tokens — database generation, staging, attachments, recovery, app group — and the `BackupExclusions` port with an in-memory stub; no OS call, PF-01 unresolved); `lib/features/settings/delete_all_controller.dart` (two explicit confirmations, refuses while not unlocked, key loss is never deletion consent, `SyntheticDeleteAllExecutor` removes a synthetic snapshot and the stored key); `lib/features/settings/delete_all_confirm_sheet.dart` (destructive confirm sheet, UI only). l10n: five Delete-all strings added (DECISIONS T11-L10N). Tests: `test/privacy/*` (15 tests: every request type rejected while off; gate/epoch semantics; batch and identifier bounds with the gate on; DTO public-identifier shape with an exhaustive type list; a source-scan traffic test proving no `dart:io`/HTTP/socket/file reference anywhere in `lib/data/prices/`; exclusion idempotence; delete-all locked-refusal, two-confirm chain, missing-first-confirmation, cancel, synthetic removal, key-absent after run; a no-email/SMS/credential source scan). Checks: `flutter analyze` clean; `custom_lint` clean; `flutter test test` 319 pass; goldens 33 pass; `check_tokens` OK; `gen-l10n` pass. Open: the native delete-all sequence and real exclusion verification stay device gates (PF-01, SYSTEM_DESIGN 12.1-12.2); the integration smoke test still needs a simulator per AGENTS 4. Reviewer: privacy and security (reviewed 2026-11-22).

### T12 — Quality harness and interface checks

- Objective: wire all AGENTS.md section 4 commands + SPEC 16.3 checks + golden harness. Refs: AGENTS.md 4, 7; SPEC 16; DESIGN 9.
- Dependencies: T01 (harness first), then all tasks.
- Owner: Foundation builder. Files allowed: `tool/lints/*` wiring, `tool/check_*.dart` wiring, `test/tags.yaml` or equivalent, `integration_test/phase1_smoke.dart` skeleton only.
- Provides: CI gates consumed by all tasks. Consumes: none beyond T01.
- Acceptance: `dart format`, `flutter analyze`, `custom_lint`, `check_tokens`, `check_contrast`, `flutter test`, `flutter test --tags golden`, `integration_test` smoke documented as pass/fail per task. No empty tests or no-op checks substituted.
- Evidence: per-task command logs attached to pull requests. Reviewer: design and accessibility + privacy and security.
- Status: done 2026-11-21. Wired: `custom_lint` with the local `tool/lints` plugin (15 rules: colour, text style, spacing, decoration, containers, Material buttons, icons, add icon, number format, one control row, custom paint, text size, gradient, animation, glow); `flutter gen-l10n` with `l10n.yaml`, `lib/l10n/app_en.arb` and the generated output ignored by git; `integration_test/phase1_smoke.dart` (passes on an iOS simulator); `tool/check_tokens.dart`, `tool/check_contrast.dart`; `test/tool/lints_test.dart` (14 rule tests); `dart_test.yaml` golden tag. `flutter analyze` clean; `dart run custom_lint` clean. Deferred with their components: `build_runner` (T07 generators), `chart_requires_table` (T11 charts), `hidden_mode_semantics` (T10 money widgets). Reviewed 2026-11-22 (design and accessibility + privacy and security).
