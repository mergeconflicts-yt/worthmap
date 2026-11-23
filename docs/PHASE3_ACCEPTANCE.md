# Contour — Phase 3 acceptance (PDF slice, 2026-11-23)

Scope: SPEC 17 Phase 3, PDF only (DECISIONS `P3-PDF-SUBSET`). Evidence was
produced on this host (macOS, Flutter test VM). No device or simulator run is
claimed.

## Commands

| Command | Result |
|---|---|
| `dart run tool/gen_tokens.dart` | pass, no diff |
| `dart run build_runner build -d` | not needed (no generated table) |
| `flutter gen-l10n` | pass |
| `dart format --set-exit-if-changed .` | pass, 0 changed |
| `flutter analyze` | pass, no issues |
| `dart run custom_lint` | pass, no issues |
| `dart run tool/check_tokens.dart` | OK |
| `dart run tool/check_contrast.dart` | OK, 545 pairs |
| `flutter test test` | pass, 1123 tests |
| `flutter test --tags golden` | pass, 209 goldens |
| `flutter test integration_test` | not run: no simulator on this host |

## SPEC 17 Phase 3 "Accept when"

| Item | State | Evidence |
|---|---|---|
| Fixture files import with the expected rows | pass for PDF | `test/domain/importers/pdf_test.dart` (statement rows, signs, dates, balance rows, template); `test/data/import_staging_test.dart` |
| A second import of the same file is detected | pass | digest check in `ImportStagingRepository.stage`; test "a second import of the same file asks first" |
| A taught PDF template imports the next month with no questions | pass | `pdf_test.dart` "a taught layout imports the next month with no questions"; template mismatch test |
| No network calls during imports | pass by construction | the PDF reader and importer import no network library; staging writes SQL only |

## Flow checks

| Flow | Check | State |
|---|---|---|
| F06 step 1 | local file only; no URL resolved | pass in code; no picker binding (release states unavailable) |
| F06 step 2 | encrypted PDF asks for the password; a wrong one keeps retry | pass for RC4; AES files show X88 (`P3-PDF-SUBSET`) |
| F06 step 2 (remember) | "Remember for this layout" stores the password in secure storage; a saved password opens the next copy; a wrong saved one is cleared | pass (`test/features/import/import_password_test.dart`) |
| F06 step 3 | preview before staging; a layout is saved only after a usable preview | pass (X65, X66, `teachPdfTemplate`) |
| F06 step 4 | Send publishes once; no payment is written | pass (`test/data/import_staging_test.dart`) |
| F06 step 5 | history and "Undo this import" | pass |
| F06 step 6 | a known source identity is not staged twice | pass |

## Screens

- X63, X64, X65, X66, X68 and X88 are built from `lib/design` components.
- Entries: Home > Get started step 2, and Settings > Capture > Import layouts.
  Both open `/x63`; tests in `test/features/import/import_entry_test.dart`.
- 16 goldens: `screens_x63_import_hub`, `screens_x65_import_preview`,
  `screens_x68_import_done`, `screens_x88_import_error`, in dark and light at
  1.0 and 2.0. All inspected.
- Tests: `test/features/import/import_flow_test.dart` (3).

## Known gaps (DECISIONS)

`P3-BALANCE-ROWS`, `P3-TEMPLATE-TABLE`, `P3-INTAKE-BINDING`,
`P3-CATEGORY-SUGGESTION`, `P3-HISTORY-OPEN`.

Deferred formats and sources keep their tasks in `docs/TASKS_PHASE3.md`:
CSV, Excel, OFX, QFX, QIF, CAMT.053, MT940, QR, receipt photo, holdings
screenshot, share extension, and the Inbox producer handover.
