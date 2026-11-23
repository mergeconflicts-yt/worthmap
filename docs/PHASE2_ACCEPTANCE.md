# Contour — Phase 2 acceptance (2026-11-22)

Status: **accepted 2026-11-23** by the owner. Every review named in
`docs/TASKS_PHASE2.md` is closed. Three evidence items stay open as accepted
exceptions and keep their gate ids (see "Acceptance decision").

Scope: SPEC 17, "v1 Phase 2 — Capture, Inbox, Spending". Evidence was produced
on this host (macOS, Flutter test VM). A device or simulator run is marked
separately.

## Acceptance decision

- Phase 2 is accepted. The screens, reads, commands and tests in P01–P29 are
  the delivered work.
- The review roles named per task approved their task on 2026-11-23:
  product and finance, design and accessibility, privacy and security.
- Accepted exceptions, not passes. Each stays open in DECISIONS with its gate
  id, and no release claim depends on it:
  - `3.1` input target (3 taps): the X20 harness measured 4 activations. No
    device run. The claim is not made.
  - `P24-ENGINE-EVIDENCE`: no verified on-device speech engine and no
    airplane-mode run. Voice ships behind `UnavailableSpeechPort` until the
    binding is verified.
  - `flutter test integration_test`: not run on this host (no simulator).
- The device gates keep their Phase 1 status and are not closed by this
  acceptance: `PF-01`, DB-A, DB-B, `T07-CIPHER-BUILD`, T08/T11 native
  bindings, `P21-UNWIRED-GATEWAY`.

## Commands

| Command | Result |
|---|---|
| `dart run tool/gen_tokens.dart` | pass, no diff |
| `dart run build_runner build -d` | not needed (no new generated tables) |
| `flutter gen-l10n` | pass |
| `dart format --set-exit-if-changed .` | pass, 0 changed |
| `flutter analyze` | pass, no issues |
| `dart run custom_lint` | pass, no issues |
| `dart run tool/check_tokens.dart` | OK |
| `dart run tool/check_contrast.dart` | OK, 545 pairs |
| `flutter test test` | pass, 1037+ tests |
| `flutter test --tags golden` | pass, 173+ goldens |
| `flutter test integration_test` | **not run**: no simulator on this host |

## SPEC 17 "Accept when"

| Item | State | Evidence |
|---|---|---|
| 3.1 input targets (3 taps) | **not met; accepted exception** | X20 harness measured 4 activations after the account choice (one is Save). No device run. The 3-tap claim is not made. |
| Nine voice sentences in airplane mode | **open; accepted exception** | `P24-ENGINE-EVIDENCE`: no verified on-device engine and no device. The parser tests pass for all fifteen sentences. |
| Transfer, refund and reimbursement fixtures | transfer pass; refund/reimbursement pass in domain tests | F05-A/D in P23 vault and domain tests; F08-D/E in P09 and P27. |
| Nothing saved before Save | pass | P22 F03-C, P24 F04-C tests. |

## Feature checks

| Flow | Check | State |
|---|---|---|
| F03 | no write before Save; split once; Undo | pass |
| F04 | no record before Save; denial keeps typing | pass; airplane-mode run open |
| F05 | principal not spending; one fee; boundary Missing | pass (boundary attribution Missing by decision) |
| F07 | uncertain unticked; exact totals; rollback; repeat/Undo | pass |
| F08 | filter on Show; cancelled delete; delete/Undo once; zero vs Missing; limits leave balances | pass |
| F09 | one occurrence per slot; Stop keeps history; declined rule writes none | pass in P16/P28 tests |

## Demo wiring (debug only)

- A debug build starts the synthetic in-memory demo: `main.dart` selects
  `DemoBootstrap` under `kDebugMode`. It starts on X03 Home with a demo-only
  **Go to** card (Spending, Add a payment); the debug menu at `/dev/gallery`
  opens the rest, and `DEMO_ROUTE` opens one screen directly.
- Tests: `test/app/demo_composition_test.dart` asserts the live numbers, the
  payments list and the history entries over the same composition.
- This is not a release path: the vault is in memory, the cipher is the
  synthetic adapter, and nothing persists (PF-01, T07-CIPHER-BUILD).

## Known gaps carried by DECISIONS

These gaps are accepted carry-overs, not review blocks. Each keeps its id and
its owner task in the phase that closes it.

`P2-INBOX-PRODUCER`, `P2-TRANSFER-BOUNDARY`, `P2-SEARCH-ENTRY`,
`P2-SPEND-NEXT-INCOME`, `P21-CARD-LIMIT`, `P22-PAYMENT-DEFAULTS`,
`P23-LARGE-TEXT`, `P24-ENGINE-EVIDENCE`, `P25-BADGE`, `P25-SOURCE-STRIP`,
`P25-LAST-CAPTURE`, `P25-RULE-TOGGLE`, `P26-WIDGETS`,
`P26-CATEGORY-AVERAGES`, `P26-NEEDS-WANTS`, `P26-WHERE-BARS`,
`P26-FIXED-RINGS`, `P26-MONEY-IN-COLOUR`, `P26-MONEY-IN-SPLIT`,
`P26-LIMITS-UNDO`, `P27-RING-LINK`, `P27-EXPECTATION-TOGGLES`,
`P27-FILTER-ROWS`, `P27-LIMIT-BAR`, `P28-TABBAR-ADD`, `P28-BILLING-STRIP`,
`P28-CANCEL-ADDRESS`, `P28-AUTOCREATE`, `P28-SCHEDULE-CATEGORY`,
`P28-CATEGORY-EDIT`, `P28-HISTORY-CHART`, `P29-HIDDEN-OTHER`,
`P29-HISTORY-BLOCKED`, `P29-HISTORY-DETAIL`.

Device gates keep their Phase 1 status: `PF-01`, DB-A, DB-B, the native
bindings (T08/T11), and `P21-UNWIRED-GATEWAY`.
