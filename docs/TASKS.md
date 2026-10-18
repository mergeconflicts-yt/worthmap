# Contour — Phase 1 Tasks (Base)

Version: 2026-10-17. Scope: Phase 1 only. Authority order: AGENTS.md, SPEC.md + docs/spec/, SYSTEM_DESIGN in docs/approved-architecture/SYSTEM_DESIGN.md, DATABASE_DESIGN in docs/approved-architecture/DATABASE_DESIGN.md, DESIGN.md + docs/design/, docs/screens/SCREENS.md, docs/flow.md + docs/flows/USAGE_FLOWS_REFERENCE.md. Do not inspect wealthfolio/. PF-01 stays in force. Use synthetic data only. Do not invent financial or privacy rules.

## Phase 1 kickoff status (2026-10-17)

### Roll-up (2026-10-17)

- Done (awaiting independent review): T01, T02, T02b, T03, T04, T06. Partly done: T05 (hero split-number typography open). Remaining: T07-T12.
- Next: T07 (encrypted database) — G01 still open; `SCHEMA.sql` is now present under `docs/approved-architecture/database/`. While blocked, T08 can start with a fake `KeyStore`, or T12 can add the design/privacy lint scaffolding. T06 is awaiting review, so the framework host/registry exist.
- Test state: `flutter test` 185 pass (includes the 8 goldens); `flutter test --tags golden` 8 pass and stable.
- Gate state: `dart format`, `flutter analyze`, `check_tokens` pass. `check_contrast` **fails by design** on the two open contrast decisions (R07, CR-19) until the design owner resolves them. Not wired yet: `custom_lint` (T12), `gen-l10n` (T10), `integration_test` (T12).

### Workspace verification

- The workspace is a git working tree. Branch and pull-request rules (AGENTS 8) apply.
- `flutter analyze`: no issues. `flutter test`: 185 pass; `flutter test --tags golden`: 8 pass (T04 gallery + T05 components, dark/light, 1.0/2.0).
- T01-T06 are complete. The token tools (T03), golden tests (T04), Phase 1 components (T05) and the widget framework (T06) now exist. The remaining AGENTS 4 commands do not exist yet and are expected to fail until their owning task: `dart run custom_lint` (T12 wiring), `flutter gen-l10n` (T10 strings), `flutter test integration_test` (T12).
- Present: `tool/`, `docs/DECISIONS.md`, `lib/core/`, `lib/design/`, `lib/app/widgets/`, `lib/features/home/widgets/` (T06 test widgets), `docs/approved-architecture/database/SCHEMA.sql`. Still absent: `lib/domain/`, `lib/data/`, `lib/l10n/`, `docs/screens/*.png`, `docs/WIDGET_CATALOGUE.md` (current source is `docs/spec/spec-widgets.md`).

### Independent tracks (after T01; run in parallel)

- core — T02 (done), T02b (done). Owner: Domain builder. Files: `lib/core/*`, `test/core/*`.
- design-system — T03 (done) → T04 (done) → T05 (done) → T06 (done, awaiting review). Owner: Design-system builder. Files: `lib/design/*`, `tool/gen_tokens.dart`, `tool/check_tokens.dart`, `tool/check_contrast.dart`, `test/golden/design/*`.
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

- G01 Account prerequisites: move basic bank, cash, card setup + opening balances to base phase. Define inclusive balance anchor and accepted postings after it. Blocks F01, F03, F05, F06, F10. Source: docs/flow.md, docs/flows/USAGE_FLOWS_REFERENCE.md.
- WIDGET-X03-DEFAULT: X03 catalogue entry and defaults open. Text absent except parenthetical in docs/spec/spec-widgets.md:84. Phase 1 accepts with test widgets and test layout file only. Source: docs/spec/spec-widgets.md, widget-framework.md.
- LAYOUT-UPGRADE DECISION-PENDING: interim rule usable for tests W-J, W-L. Production new-release behaviour stays product-gated. Source: docs/spec/spec-widgets.md W10, DATABASE_DESIGN.md:225.
- WIDGET-HALF-REFLOW: threshold open, interim above 1.3 on phones. Blocks final geometry sign-off only.
- PF-01 phone confinement: no personal-data persistence, no iOS release claim. Prototype with synthetic data only. Source: SYSTEM_DESIGN.md 12.2.
- Missing sources: docs/WIDGET_CATALOGUE.md absent (current source is docs/spec/spec-widgets.md); docs/screens/*.png and the design-gallery HTML absent (see DECISIONS SCREEN-REFERENCES). `SCHEMA.sql` is now present at docs/approved-architecture/database/SCHEMA.sql. lib/core (T02-T02b), lib/design (T03-T05), tool/ and docs/DECISIONS.md now exist. T07 must translate DATABASE_DESIGN + database/table-map.md + query-contracts.md + shared-state.md. Do not invent tables.
- CASHFLOW-*, SUBS-TOTAL, REGULAR-INVEST, HOME-GOALS-NAME: block later financial widgets only, not Phase 1 host.
- FIN-3 gate: no `lib/domain/numbers` task before FIN-3-01..04 are closed.
  FIN-3-01 (TWR sub-period formula) is fixed in spec-calculation.md 13.12.
  FIN-3-02..04 (13.2 and 13.4 test values, net worth bridge gaps, Appendix A
  contradictions) stay open in docs/DECISIONS.md (G14-FIN-DEFINITIONS).

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
- Status: done 2026-10-17. Files: pubspec.yaml, analysis_options.yaml, lib/main.dart, lib/app/app.dart, .gitignore, lib/README.md, ios/ via flutter create, test/widget_test.dart smoke. Checks: flutter pub get pass, flutter analyze no issues, flutter test 1/1 pass. No Podfile: no native plugins yet, pod install not required. Needs privacy/security review. Shared-file owner for pubspec-yaml. Verified 2026-10-17: still no issues; the core tests in T02 build on this foundation.

### T02 — Core value types

- Objective: pure-Dart Money, Decimal policy, LocalDate, Clock, Result, UUIDv7 codec. Refs: SPEC 4.1, 4.2, 4.9; AGENTS.md 6.3, 6.4.
- Dependencies: T01. Blocked by: none. G01 does not block types.
- Owner: Domain builder. Files allowed: `lib/core/money.dart`, `lib/core/decimal.dart`, `lib/core/dates.dart`, `lib/core/ids.dart`, `lib/core/result.dart`, `test/core/*_test.dart` only.
- Provides: `Money(minor,currency)`, `Decimal` helpers, `LocalDate`, `Clock`, `Result`. Consumes: T01 project only.
- Acceptance: failing tests first, then pass. 100% line coverage on new files. No `double` for money. No `DateTime.now()` in functions. No Flutter imports in `lib/core/` or `lib/domain/`.
- Evidence: test file diff + coverage report + `dart format` log. Reviewer: product and finance.
- Status: done 2026-10-17, awaiting independent review. Files: `lib/core/money.dart`, `lib/core/decimal.dart`, `lib/core/dates.dart`, `lib/core/ids.dart`, `lib/core/result.dart`; tests `test/core/{decimal,money,dates,ids,result}_test.dart`. Evidence: tests written first and seen to fail (missing-source compile errors), then 42 core tests pass; `flutter analyze` no issues; `dart format --set-exit-if-changed` no diff; 100% line coverage on all five files (lcov: money 60/60, decimal 25/25, dates 48/48, ids 49/49, result 8/8). Uses `package:decimal` only; no `double` for money; no `DateTime.now()`; no Flutter import in `lib/core`. Reviewer: product and finance (required before integration).

### T02b — Percent split and largest remainder

- Objective: `Percent.split` that makes parts add to exactly 100%, plus change/percentage helpers. Refs: SPEC 4.1, 4.2, Appendix A shares; AGENTS 6.4; DESIGN 4.
- Dependencies: T02. Blocks percentage display, split bars and `X23Split`.
- Owner: Domain builder. Files allowed: `lib/core/percent.dart`, `test/core/percent_test.dart` only.
- Provides: largest-remainder split with a deterministic tie-break and signed parts. Consumes: T02 `Decimal`.
- Acceptance: failing tests first, then pass. Every split adds to the exact whole. Ties break deterministically (largest remainder, then stable input order). 100% line coverage. Reviewer: product and finance.
- Evidence: test diff, coverage log, `dart format` log. Reviewer: product and finance.
- Status: done 2026-10-17, awaiting independent review. Files: `lib/core/percent.dart`, `test/core/percent_test.dart`. Evidence: tests written first and seen to fail (missing-source compile errors), then 19 tests pass; `flutter analyze` no issues; `dart format --set-exit-if-changed` no diff; 100% line coverage (lcov 54/54). The Appendix A home split at scale 1 gives 35.2, 12.8, 0.0, 52.0, sum 100. Reviewer: product and finance (required before integration).

### T03 — Design tokens foundation

- Objective: tokens.json single source + generator + Contrast check. Refs: DESIGN 0-2; SPEC 7; AGENTS.md 4, 6.9.
- Dependencies: T01. Blocks T04-T06.
- Owner: Design-system builder. Files allowed: `lib/design/tokens/tokens.json`, `tool/gen_tokens.dart`, generated `tokens.g.dart` via generator only, `tool/check_tokens.dart`, `tool/check_contrast.dart` wiring only.
- Provides: `context.tokens` roles used by T04. Consumes: none.
- Acceptance: `dart run tool/gen_tokens.dart` regenerates without diff. `dart run tool/check_tokens.dart` passes. `dart run tool/check_contrast.dart` passes for Phase 1 roles. Dark + Light values for every colour token. No colour literals elsewhere.
- Evidence: generator log, check logs, tokens diff. Reviewer: design and accessibility.
- Status: done 2026-10-17, awaiting independent review. Files: `lib/design/tokens/tokens.json`, `lib/design/tokens/token_types.dart`, generated `lib/design/tokens/tokens.g.dart`, `tool/token_gen_lib.dart`, `tool/gen_tokens.dart`, `tool/check_tokens.dart`, `tool/check_contrast.dart`; `docs/DECISIONS.md` created. Evidence: `dart run tool/gen_tokens.dart` writes the same file twice (idempotent); `check_tokens` OK; `check_contrast` OK (525 pairs) with two documented warnings; `flutter analyze` no issues; `dart format --set-exit-if-changed` no diff; `flutter test` 62 pass at T03 (81 pass now with later tasks). `lib/app/app.dart` now uses `ColorTokensDark.palettePage`, so no colour literal is outside `lib/design/`. Open: T03-DERIVED-TOKENS and LIGHT-LOSS-CONTRAST in `docs/DECISIONS.md`; the unused-token check starts in T04. Reviewer: design and accessibility (required before integration).

### T04 — Theme, section, type, icons minimal

- Objective: Obsidian dark/light themes, SectionScope, AppText subset, AppIcons subset for Phase 1 screens. Refs: DESIGN 2-3; SPEC 7.
- Dependencies: T01, T03.
- Owner: Design-system builder. Files allowed: `lib/design/theme/*`, `lib/design/typography/*`, `lib/design/icons/*`, `test/golden/design/theme_*` + gallery entries only.
- Provides: `AppTheme.dark/light`, `SectionScope`, `AppText.*`, `AppIcons.*`. Consumes: T03 tokens.
- Acceptance: gallery entry + goldens dark/light, scale 1.0/2.0. Text >=13pt except 12/11 allowed roles. Contrast >=4.5:1. No `TextStyle` outside `lib/design/`.
- Evidence: golden images + `flutter test --tags golden` log + lint log. Reviewer: design and accessibility.
- Status: done 2026-10-17, awaiting independent review. Files: `lib/design/theme/app_theme.dart` (ContourTokens + AppTheme), `lib/design/theme/section.dart`, `lib/design/typography/app_text.dart`, `lib/design/icons/app_icons.dart`, `lib/design/gallery/gallery.dart`, `lib/design/design.dart`; fonts `lib/design/fonts/*` (Inter 4.1, OFL), icons `lib/design/icons/*.svg` (Lucide, ISC); `test/golden/design/*` and baseline PNGs; `dart_test.yaml`. Evidence: `flutter test` 72 non-golden pass; `flutter test --tags golden` 4 goldens pass (dark/Light, 1.0/2.0) at T04 (8 goldens now, T05 adds 4). `flutter analyze` no issues; `dart format --set-exit-if-changed` no diff. `git` absent, so the baseline PNGs are the committed images for review. Open: the `custom_lint` design rules do not exist yet (T12). Reviewer: design and accessibility (required before integration).

### T05 — Layout templates + Phase 1 components

- Objective: TabRootScreen, DetailScreen, start-screen host, ObHero (number + 0Hero), GlassCard, ScreenHeader, AppButton, WidgetSlot host placeholder. Refs: DESIGN 5-6; SPEC 3.3, 6.1; SCREENS.md rules.
- Dependencies: T01, T03, T04.
- Owner: Design-system builder. Files allowed: `lib/design/layout/*`, `lib/design/components/hero/*`, `lib/design/components/surfaces/*`, `lib/design/components/buttons/*`, gallery + goldens for each variant only.
- Provides: templates + components consumed by T06, T10. Consumes: T03-T04.
- Acceptance: one control row lint passes. One add control lint passes. Every tappable has semantic label. Every money widget has hidden state. Goldens dark/light 1.0/2.0. `custom_lint` passes (no_color_literals, no_text_style, no_raw_spacing, etc.).
- Evidence: gallery + goldens + lint logs. Reviewer: design and accessibility.
- Status: partly done 2026-10-17, awaiting independent review. Built: `TabRootScreen`, `DetailScreen`, `FormScreen`, `PageBackground`, `GlassCard` (normal, stage, wide; CARD-TITLE-OUT title/meta), `ScreenHeader`, `WidgetSlot` (normal, editing placeholder), `AppButton` (primary, neutral, ghost, soft, destructive; disabled, icon, compact, full width), `AppIconButton` (onPage, onCard, plain), `InfoButton`, `ObHero` (number, detail; hidden, side figures) + `MoneyText`/`ValueSpec`/`ValueState`/`formatValueState`/`FitNumber` in `lib/design/format/`; `Space`/`VSpace`/`HSpace`. Gallery `lib/design/gallery/components_gallery.dart`; goldens `test/golden/design/components_{dark,light}_{1.0x,2.0x}.png`; `test/design/components_test.dart` (format + value states + hidden state), `test/design/fit_number_test.dart`. Tokens added: `color.role.text.heroFill` (DESIGN 14.1c) and `space.cardTitleGap` (10). Checks: `flutter analyze` clean; `check_tokens` OK; `check_contrast` OK 529 pairs; `flutter test` pass; `flutter test --tags golden` 8 pass and stable. Open: the hero split-number typography and the `period` variant (needs T11 charts) are not built — `ObHeroVariant.period` was removed, T05 stays partly done (DECISIONS HERO-SPLIT-NUMBER); `custom_lint` design rules do not exist yet (T12), so the one-control-row / one-add-control / raw-spacing lints are not run; strings in the gallery are literal (l10n is T10); `WidgetSlot` dashed outline needs a component painter (WIDGETSLOT-DASH). Reviewer: design and accessibility.

### T06 — Widget framework Phase 1 (registry, host, layout repo, editor)

- Objective: independent registry, two-level surface host, layout repository/editor, bundled default layout file, test widgets for X03. Refs: SPEC W1-W13, W8; SYSTEM_DESIGN 3.1, 8.3; DATABASE_DESIGN 5.1; widget-framework.md; usage-flows F01.
- Dependencies: T01, T05, T07 (layout tables interface only). Continues when T07 blocked: use in-memory layout repo with same interface, mark Drift wiring pending.
- Owner: Feature-framework builder (app role). Files allowed: `lib/app/widgets/registry.dart`, `lib/app/widgets/host.dart`, `lib/app/widgets/editor.dart`, `lib/app/widgets/default_layout.dart` (compiled constant), `lib/features/home/widgets/test_*.dart`, `test/widget_framework/*_test.dart` only. No screen-key switches in screens.
- Provides: `WidgetRegistry`, `SurfaceHost`, layout edit session (private candidate, Done commits touched surfaces, Cancel writes nothing). Consumes: T05 templates, T07 layout tables (or in-memory stub with identical API).
- Acceptance: W-A to W-L subset for Phase 1 with test widgets: registry from Phase 1, no fixed cards, Done/Cancel semantics, resident-only Add preview shows Not loaded yet on cache miss, hidden lease release. Tests use synthetic layout only. WIDGET-X03-DEFAULT stays open — test catalogue row only, flagged `// DECISION-PENDING: WIDGET-X03-DEFAULT`.
- Evidence: unit tests + widget tests + editor convergence test logs. Reviewer: product and finance + design and accessibility.
- Status: done 2026-10-17, awaiting independent review. Built: `lib/app/widgets/layout_model.dart` (`WidgetSize`, `LayoutPlacement`, `LayoutSection`, `SurfaceLayout`, `AddWidgetEntry`/`AddTarget`/`AddBlock`, `LayoutBundle` with rename chain, `LayoutFormatError`); `registry.dart` (`WidgetKind`, `WidgetDescriptor`, `WidgetRegistry.validate` for the supported W-L subset); `read_store.dart` (`MetricKey`, `MetricState`, `MetricValue`, `SharedReadStore`, `InMemoryReadStore`); `default_layout.dart` (test bundle); `layout_repository.dart` (`StoredLayout`, `LayoutRepository`, `InMemoryLayoutRepository`); `resolver.dart` (`LayoutResolver`, `ResolvedPlacement/Section/Surface`; unknown key skip W3.10, gate W3.12/6, size fallback W3.11, explicit-empty DB4-4, empty-section drop); `editor.dart` (`LayoutEditor` private candidate, hide/move/moveSection/add/take/insert/resetToDefault/undo/done/cancel, `LayoutCommit` with base version + new-in-version); `widget_surface_host.dart` (`WidgetSurfaceHost` two-level host with half-size pairing). Design additions: `lib/design/components/surfaces/widget_section.dart`, `widget_edit_bar.dart` (design-system file ownership cross — see DECISIONS T06-DESIGN-COMPONENTS). Test widgets: `lib/features/home/widgets/test_widget_catalogue.dart` (test.alpha/beta/gamma/own/tile.a). Tests: `test/widget_framework/*` (layout model, registry, resolver, editor, repository, read store; host widget tests). Checks: `flutter analyze` clean; `check_tokens` OK; `check_contrast` OK 529 pairs; `flutter test` 147 pass; `flutter test --tags golden` 8 pass. Open: WIDGET-X03-DEFAULT (test catalogue only); in-memory repo (T07 Drift wiring pending); l10n strings are constants (`testNotLoadedLabel`), replaced in T10; host pairing threshold stays interim per WIDGET-HALF-REFLOW; `WidgetSlot` dashed outline still pending (WIDGETSLOT-DASH). Reviewer: product and finance + design and accessibility.

### T07 — Encrypted database, migrations, ChangeLog, layout tables

- Objective: Drift over verified SQLCipher, owner isolate, schema v1-v5 incl. layout_surfaces/sections/items, entity registry, operation intent/receipt, ChangeLog, read_revision. Refs: SYSTEM_DESIGN 2, 4-6, 12.1; DATABASE_DESIGN 1-6; SPEC 9; EXECUTION_SAFETY 1, 6.
- Dependencies: T01, T02. SCHEMA.sql absent — translate from DATABASE_DESIGN + database/table-map.md + query-contracts.md + shared-state.md. Do not invent financial rules. G01 anchor definition pending — schema must support inclusive anchor without fixing its finance meaning.
- Owner: Data builder. Files allowed: `lib/data/db/*` (schema, migrations, owner, codecs), `test/data/migration_*_test.dart`, fixtures synthetic only. Exclusive owner of schema files.
- Provides: `CommandRepository.execute`, owner-validated reads, `read_revision` advance, ChangeLog writes. Consumes: T02 codecs.
- Acceptance: migration tests with old-database fixtures pass. Database does not open without key. Foreign keys + recursive triggers verified each open. WAL + synchronous FULL + temp MEMORY verified. No Drift rows leak to features. Synthetic data only per PF-01. Python/SQLite checks alone do not count.
- Evidence: migration test logs, cipher negative-open test, `flutter analyze` log. Reviewer: privacy and security + product and finance.
- Status: remaining with blocked input (SCHEMA.sql missing, G01 open) as of 2026-10-17. T01 and T02 are done. Work continues with stub schema behind interface; production migration waits for source. Reviewer: privacy and security + product and finance.

### T08 — App lock, keys, lifecycle control

- Objective: AuthPort, native biometric/device-credential, 256-bit keys, lock state machine, lifecycle control store, background mask/blur. Refs: SPEC 6.1 X02, 9.1, 11; SYSTEM_DESIGN 12.1, 12.3.
- Dependencies: T01, T07 (key + generation epochs only). Continues with fake KeyStore when native verification pending.
- Owner: Native builder. Files allowed: `lib/app/auth/*`, `lib/data/keys/*`, `native/android/*lock*` stubs, `native/ios/*lock*` stubs, `test/app/auth_*_test.dart` only. Domain/features never import platform packages.
- Provides: `AuthPort`, `KeyStore`, lock states closed/authenticating/opening/unlocked/closing/closed. Consumes: T07 epochs.
- Acceptance: F01-C: shared file exposes no content before unlock. Missing control state requires auth, never defaults to off. Off mode still checks epochs/keys/deletion. No secret in logs. Tests use injected monotonic clock, no wall clock.
- Evidence: unit tests + manual lock/unlock log on simulator + analyser log. Reviewer: privacy and security.
- Status: remaining as of 2026-10-17. T01 done; waits for T07 key/epoch interface (or a fake KeyStore with the same API). Reviewer: privacy and security.

### T09 — Router + SectionScope + Phase 1 routes

- Objective: go_router with Section per route, routes X01, X02, X03, X80, X86 + gallery (debug only). Refs: SPEC 5.1-5.4; DESIGN 3; AGENTS.md 11.
- Dependencies: T01, T04, T06, T08.
- Owner: App builder. Files allowed: `lib/app/router.dart`, `lib/app/section_scope.dart` only. Exclusive owner of router.
- Provides: routes + SectionScope consumed by T10. Consumes: T06 host, T08 auth gate.
- Acceptance: deep link waits behind unlock, never replays Save/Confirm/Delete. No amounts in URLs/logs. Unavailable target returns to nearest parent. Tab re-select returns to root.
- Evidence: router tests + navigation test log. Reviewer: design and accessibility.
- Status: remaining as of 2026-10-17. Wait for T06 (host) and T08 (auth gate); T04 is done. Shared-file owner for router. Reviewer: design and accessibility.

### T10 — Phase 1 screens (X01, X03, X80 skeleton, X86 base, X02 silhouette)

- Objective: build Welcome (currency required only), first-run Home state, Settings skeleton, Privacy base, Lock silhouette. Refs: SPEC 6.1, 6.9; SCREENS.md X01, X02, X03, X80, X86; flows F01, F19-base, F21-base.
- Dependencies: T05, T06, T09. G01 blocks final F01 acceptance but not skeleton build with `// DECISION-PENDING: G01`.
- Owner: Feature builder. Files allowed: `lib/features/start/*`, `lib/features/home/x03_*`, `lib/features/settings/x80_*`, `lib/features/settings/x86_*`, `lib/l10n/*` additions for these screens only, `test/golden/*` for these screens only.
- Provides: screens. Consumes: T05 components, T06 host/registry, T09 router, T08 lock.
- Acceptance: X01: one required choice (main currency), Start. X03: hero —, Get started 0 of 5, Next 30 days none recorded, sample Appendix A only where defined else Missing/None recorded. X80 skeleton list only. X86: network off, Delete-all entry. Banned-word check passes. One control row + one add control. Goldens dark/light 1.0/2.0. Usability F01-A passes with synthetic data.
- Evidence: goldens + `flutter test --tags golden` log + interface-check log + l10n diff. Reviewer: product and finance + design and accessibility.
- Status: remaining as of 2026-10-17. Wait for T06 and T09; T05 is done. G01 still blocks final F01 acceptance. Reviewer: product and finance + design and accessibility.

### T11 — Privacy policy test + Delete-all skeleton (no real data)

- Objective: network-off enforcement test, backup/transfer exclusion wiring, Delete-all intent plumbing (destructive confirm UI only in Phase 1). Refs: SPEC 2, 10.5, 11, 14; SYSTEM_DESIGN 11-12; flows F21.
- Dependencies: T07, T08, T10.
- Owner: Native builder (with Data builder review). Files allowed: `lib/data/prices/gateway_stub.dart` (off by default), `lib/data/backup/exclusions.dart` stub, `lib/features/settings/delete_all_*` UI only, `test/privacy/*_test.dart` only.
- Provides: gateway off gate, exclusion flags. Consumes: T07 generations, T08 lifecycle.
- Acceptance: price request while off is rejected. No balances/quantities/names in request DTO. PF-01: no real-user persistence claim. Delete-all requires confirm, removes synthetic snapshot + keys in test. No email/SMS/bank credentials requested.
- Evidence: privacy tests + traffic test (zero non-gateway sockets) log. Reviewer: privacy and security (required before integration).
- Status: remaining as of 2026-10-17. Wait for T07, T08 and T10. Reviewer: privacy and security (required before integration).

### T12 — Quality harness and interface checks

- Objective: wire all AGENTS.md section 4 commands + SPEC 16.3 checks + golden harness. Refs: AGENTS.md 4, 7; SPEC 16; DESIGN 9.
- Dependencies: T01 (harness first), then all tasks.
- Owner: Foundation builder. Files allowed: `tool/lints/*` wiring, `tool/check_*.dart` wiring, `test/tags.yaml` or equivalent, `integration_test/phase1_smoke.dart` skeleton only.
- Provides: CI gates consumed by all tasks. Consumes: none beyond T01.
- Acceptance: `dart format`, `flutter analyze`, `custom_lint`, `check_tokens`, `check_contrast`, `flutter test`, `flutter test --tags golden`, `integration_test` smoke documented as pass/fail per task. No empty tests or no-op checks substituted.
- Evidence: per-task command logs attached to pull requests. Reviewer: design and accessibility + privacy and security.
- Status: partly started 2026-10-17. T01 is done; the token checks, golden harness and `dart_test.yaml` golden tag exist (T03-T05). Still to wire: `tool/lints/*` (`custom_lint`), `gen-l10n`, `integration_test/phase1_smoke.dart`. Reviewer: design and accessibility + privacy and security.
