# AGENTS.md — Rules for AI agents working on Contour

Version 1.3 — 14 October 2026. How every AI agent and human developer works in this repository. Read all of it before the first change.

## 1. Read these first, in this order

| File | What it is | Wins for |
|---|---|---|
| `AGENTS.md` | Workflow, commands, rules, roles | Process and code conventions |
| `SPEC.md` (core) and `docs/spec/SPEC_REFERENCE.md` (full detail) | Product rules, numbers, screens, data model, releases; formulas, screen behaviour, test values, Appendix A sample data | Content and behaviour |
| `SYSTEM_DESIGN.md` | Data, workers, storage, privacy, recovery | Technical module and execution contracts (SPEC owns product meaning) |
| `DATABASE_DESIGN.md`, `docs/architecture/database/` | Tables, constraints, codecs, queries, migrations, recovery | Physical storage within SYSTEM_DESIGN (SPEC owns financial meaning) |
| `DESIGN.md` (core) and `docs/design/DESIGN_REFERENCE.md` (full detail) | Laws and key tokens; every token value, component spec, chart rule and lint rule | Style and interface code |
| `docs/screens/*.png` and `docs/screens/SCREENS.md` (screen descriptions) | Look of each screen, by id (`X10Home.png`) | Only where the documents say nothing |

- Read the SPEC.md sections and DESIGN.md components the task uses.
- A citation "DESIGN n.n" means section n.n in both DESIGN.md (short core) and `docs/design/DESIGN_REFERENCE.md` (full detail). Values and specs are in the reference.
- A citation "SPEC n.n" means section n.n in both SPEC.md (short core) and `docs/spec/SPEC_REFERENCE.md` (full detail). Both have the same authority; formulas, edge cases, test values and Appendix A are in the reference.
- Read the matching journey in `docs/USAGE_FLOWS.md`: entry paths, save boundaries, recovery paths, acceptance cases. Its correction gates name prerequisite specification work. It does not override SPEC.md or DESIGN.md.
- If sources disagree, follow "Wins for" and record the conflict in `docs/DECISIONS.md` (section 9).

## 2. Non-negotiable rules

Breaking one fails the task, even if the feature works.

1. Local first. No user data leaves the device.
   - No server, account, analytics, crash reporting, ads, or SDK that calls the network.
   - Network code only in `lib/data/prices/`, for explicitly enabled public symbols, prices and instrument details (SPEC.md 10.5).
   - No email network, remote FX, external export, cloud/device backup or sync. Recovery stays on the phone.
   - PF-01 (SYSTEM_DESIGN 12.2) is an unresolved OS-copy capability gate. Do not claim iOS release readiness or enable personal-data persistence on a noncompliant path. Backup exclusion and encryption do not prove universal phone confinement.
2. Data only. No advice, warnings, scores or judgements. No "should", "recommend", "on track", "risky", "good", "bad", "sell", "buy" in any string (SPEC.md 2, 16.3).
3. Correct numbers. Money = integer minor units + currency code. Maths uses `Decimal`, never `double`. Numbers follow SPEC.md 4.4 and 4.5. Unknown is never zero (SPEC.md 4.3).
4. Central design. No colours, text styles, sizes, spacing, radii, shadows, icons or painters outside `lib/design/`. Screens use only layout templates and components (DESIGN.md 0, 9).
5. One control row and one add control per screen (SPEC.md 3.3).
6. Privacy in logs. Never log, print or put in errors any amount, merchant, account name, balance, file content, email text or transcript. Logs hold event names and counts only.
7. No secrets in code. Keys, tokens and passwords go to secure storage. Never commit API keys.
8. Tests first for numbers. Every `lib/domain/` change starts with a failing unit test.

## 3. Repository map

```
lib/
  app/      start, router (sets the Section of every route), theme, lock
  core/     money, currency, dates, rounding, results
  design/   tokens, theme, typography, icons, components, charts, layout, format, gallery
  domain/   pure Dart: entities, numbers, forecast, calculators, importers, rules
  data/     drift db, repositories, prices, capture, backup
  features/ one folder per area (home, inbox, add, spending, wealth, investments, plan, ...)
  l10n/     strings (English in v1)
native/     ios and android native code (widgets, intents, share, notification listener)
test/       domain, importers, calculators, numbers, golden, fixtures
tool/       gen_tokens.dart, check_contrast.dart, check_tokens.dart, lints/
docs/       DECISIONS.md, ADRs, release notes
```

- Never edit generated files (`*.g.dart`, `tokens.g.dart`, l10n output). Change the source and run the generator.
- `test/fixtures/` data looks real but is fake. Never commit real statements, payslips or personal data.

## 4. Commands

Run before every commit. All must pass.

```
dart run tool/gen_tokens.dart          # regenerate tokens from tokens.json
dart run build_runner build -d        # drift, riverpod, other generators
flutter gen-l10n                      # strings
dart format --set-exit-if-changed .
flutter analyze
dart run custom_lint                  # design and privacy lint rules (DESIGN.md 9)
dart run tool/check_tokens.dart
dart run tool/check_contrast.dart
flutter test                          # unit and widget tests
flutter test --tags golden            # golden tests (light, dark, scale 1.0 and 2.0)
flutter test integration_test         # on a simulator or emulator, before a phase is accepted
```

- Update goldens on purpose only: `flutter test --tags golden --update-goldens`. Check every changed image and explain it in the pull request.
- Never update goldens to pass a test you do not understand.

## 5. Workflow for every task

1. Understand. Read the task, SPEC.md sections, DESIGN.md components and the Fxx journey in `docs/USAGE_FLOWS.md` (with its correction gates and component gaps). Open `docs/screens/<id>.png` and its description in `docs/screens/SCREENS.md`. If the screenshot is absent, use the figure in `contour-design.html` and record the missing reference.
2. Plan. Write a short plan in the pull request: changes, files, tests. One feature or one fix per pull request.
3. Test first for domain logic. Use Appendix A data and SPEC.md 13 test values.
4. Build with existing components and templates. If something is missing, follow DESIGN.md 10 (find, compose, variant, token, component).
5. Strings go to l10n, in SPEC.md Appendix B words.
6. Run all section 4 commands.
7. Check the screen against its screenshot and `docs/screens/SCREENS.md` at scale 1.0, light mode. Then dark mode and scale 2.0.
8. Open the pull request with the section 8 checklist.

If the task conflicts with section 2 or a number definition is unclear, stop and ask (section 9).

## 6. Code conventions

### 6.1 Dart and Flutter

- Null safety, `dart format`, `analysis_options.yaml`. Every `// ignore:` needs a reason comment.
- Small widgets. A screen file builds a layout template and passes components. No styling.
- No business logic in widgets. Widgets read providers. Controllers call the domain.

### 6.2 State (Riverpod)

- One provider per piece of state, with code generation (`@riverpod`).
- Controllers expose immutable state. Side effects (database writes) only in controller methods.
- Widgets never read the database.

### 6.3 Domain

- Pure Dart. No Flutter imports. No `DateTime.now()` in functions (pass a `Clock`). No unseeded randomness.
- Every public function has unit tests. Coverage target: 100% of lines.
- Number definitions live in `lib/domain/numbers/`, with the SPEC section in the doc comment, e.g. `/// SPEC 4.4: Available until [date]`.

### 6.4 Money and dates

- `Money(minor: int, currency: Currency)`; `Decimal` for rates and quantities.
- Convert and round only through `core/money` and `core/rounding` (SPEC.md 4.1).
- Split percentages only through `Percent.split(...)` (largest remainder).
- Payment dates are local calendar dates (`LocalDate`). Events are UTC instants.

### 6.5 Database (drift)

- Every schema change has a migration and a migration test with an old database fixture.
- Read DATABASE_DESIGN and the query contract first. SCHEMA.sql is an executable reference, not a production migration. Its Python checks do not replace Drift, SQLCipher, domain or device tests.
- Authored domain tables have `id` (UUID v7), `createdAt`, `updatedAt`, `deletedAt` and an entity revision. Deletes are soft. Technical, derived and staging records use the keys and retention in SYSTEM_DESIGN.md 5.2.
- Every confirmed authored mutation writes `ChangeLog` and affected dependency revisions atomically. ChangeLog, job metadata, public caches, search indexes and rebuildable projections create no user history. Manual quotes stay authored records.
- Queries that feed totals have tests with Appendix A data.

### 6.6 Importers and parsers

- Parsers are pure: bytes or text in, drafts with confidence out. They never write to the database.
- Bank layouts are `ParserTemplate` data files, never per-bank code branches.
- Each importer has fixtures: normal file, second import of the same file, broken file, file in another locale.

### 6.7 Platform features

- Each platform feature (OCR, speech, secure storage, app lock, files, widgets, notification access, FinanceKit) sits behind an interface in `lib/data/` or `lib/app/`, one implementation per platform.
- Domain and features never import a platform package (keeps Mac and Windows possible, SPEC.md 10.6).

### 6.8 Dependencies

- Add a package only if it runs fully on device, has a compatible OSI-approved licence, had a release in the last 12 months, and makes no network calls (or only in the allowed folders).
- Record each new dependency, reason and licence in `docs/DECISIONS.md`.
- Never add analytics, crash reporting, advertising or remote configuration packages.

### 6.9 Strings and accessibility

- Every visible string and semantic label goes through l10n.
- Every tappable widget has a semantic label.
- Every chart has a label and "Show as table". A preview chart (small card chart that opens the full chart and table) has a spoken label with the main values and no table (PREVIEW-CHART).

## 7. Definition of done

- [ ] Behaviour matches SPEC.md. Screen matches its screenshot and `docs/screens/SCREENS.md`.
- [ ] All section 4 commands pass.
- [ ] Domain changes have unit tests. Screen changes have goldens (light, dark, scale 1.0 and 2.0).
- [ ] Automated interface checks pass (advice words, text size, touch targets, one control row, one add control, contrast, percentages, unknown is not zero).
- [ ] No network call outside allowed folders. No personal data in logs.
- [ ] Strings are in l10n and follow SPEC.md Appendix B.
- [ ] Current phase acceptance tests pass (SPEC.md 17).
- [ ] `docs/DECISIONS.md` updated for any decision or conflict.

## 8. Pull requests and commits

- Branches: `feat/<area>-<short-name>`, `fix/<area>-<short-name>`, `chore/<short-name>`.
- Commits: imperative, short first line, with the area: `investments: add realised gain per sale (SPEC 13.13)`.
- Pull request description: what and why; SPEC.md and DESIGN.md sections; screen id; your build next to the reference screenshot (light and dark); test list; this checklist:

```
- [ ] Uses a layout template and existing components only (or adds them in lib/design with goldens)
- [ ] No styling values outside lib/design (lints pass)
- [ ] One control row, one add control
- [ ] Numbers follow SPEC 4.4 / 4.5; unknown values use StateValue
- [ ] No advice words; strings in l10n
- [ ] No network or logging of personal data
- [ ] Unit, golden, and lint checks pass
```

- One reviewer agent of the right role (section 10) approves before merge.

## 9. When something is unclear

- Do not guess a number definition, product rule or privacy behaviour.
- Write the question in the pull request and in `docs/DECISIONS.md` "Open questions", with the options and your preferred one.
- If you must continue, choose the option that is more private, more factual and easier to undo. Mark the code `// DECISION-PENDING: <id>`.
- Change SPEC.md, DESIGN.md or this file only in their own pull request, with the reason. Never with feature code.

## 10. Agent roles

| Role | Does | Does not |
|---|---|---|
| Planner | Splits a release phase into tasks with SPEC.md references, order and acceptance tests | Write production code |
| Domain builder | `lib/domain/`, `lib/core/`, unit tests, fixtures | Touch `lib/design/` or features |
| Data builder | `lib/data/` (database, migrations, repositories, importers, prices, capture, backup) | Add network code outside allowed folders |
| Design-system builder | `lib/design/` (tokens, components, charts, gallery, goldens), lint rules | Build feature screens |
| Feature builder | `lib/features/` screens from templates and components, controllers, l10n | Create styles, tokens or charts |
| Native builder | `native/` (widgets, intents, share extension, notification listener, platform plug-ins) | Change domain rules |
| Reviewer: product and finance | Numbers vs SPEC.md 4 and Appendix A, wording vs Appendix B, data-only rule | Approve its own work |
| Reviewer: design and accessibility | DESIGN.md rules, goldens, contrast, text scale, screen readers | Approve its own work |
| Reviewer: privacy and security | Network policy, logs, secure storage, permissions, dependencies | Approve its own work |

- One agent edits a file at a time. Claim the task and its folders in the task tracker first.
- Shared files (`pubspec.yaml`, router, `tokens.json`, database schema) change only in small, separate pull requests.

## 11. Platforms

- v1: iPhone (iOS 16+) and Android (8.0+), phones only.
- v2: iPad, Android tablets, Mac and Windows from the same code base, with independent local data per device (SPEC.md 10.6). No transfer or sync.
- Rules from day one:
  - Platform features only behind interfaces (6.7).
  - No phone-only package in `lib/domain/`, `lib/core/` or `lib/features/`.
  - Layout templates read the window size class from `context`. Features never check platform or screen width (DESIGN.md 13).
  - Every confirmed financial write goes through the single command writer, records `ChangeLog` and invalidates affected projections. No upload queue.
  - Keyboard and pointer work in every component (focus order, hover state, shortcuts registered through the template).

## 12. Never

- Add a server, account system, analytics, crash reporting, ads, remote configuration, mail networking, outgoing exports or device sync.
- Send user data, files, transcripts or email text off the device.
- Request Gmail restricted scopes, SMS permission, or bank, broker or bureau credentials.
- Use `double` for financial values, or format money outside `lib/design/format/`. Only `lib/design/charts/` may use `double`, for bounded drawing coordinates; labels and tables keep financial types.
- Style outside `lib/design/`, or add a second control row or add button.
- Write advice, warnings or judgements in any string.
- Commit real personal data, statements, payslips or keys.
- Edit generated files, or update goldens without reviewing the images.
- Merge without a reviewer of the right role.

IMP:
Reply using ASD-STE100 Simplified Technical English style
I prefer replies in bullet points with side headings whenever required
