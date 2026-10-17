# Architecture approval record

16 October 2026 · ARCH-FINAL-001 · Final technical baseline.

**Decision: approved for implementation of the technical baseline.** All three architects approved the corrections; each final file attestation is kept in its report against the manifest hash. This decision does not remove the release prerequisites below.

**Scope:** the complete system/database architecture, updated widget contracts and final consolidation. This record supersedes ARCH-REVIEW-001–004 and WIDGET-ARCH-001; their evidence is preserved in the history archive. It does not approve a production release.

| Independent reviewer | Report | Scope |
|---|---|---|
| Senior system architect | System review | Execution, bounded work, feature coverage, latency and recovery; independent review of the database architect's validator corrections |
| Senior database architect | Database review | Schema, exact types, integrity, upgrades, retained evidence and query contracts |
| Senior privacy/reliability challenge architect | Challenge review | Authentication, privacy boundaries, direct confirmation, failure paths and readiness claims |

The reports contain the original findings, correction analysis and explicit decisions. Technical correction approval is separate from each reviewer's final manifest attestation. Final file verification is recorded in those reports against the exact manifest hash; no earlier manifest approves this package.

## Corrections included

- The prior 38 widget review findings are incorporated and re-reviewed. The final layout reference adds four regression tests: cumulative rename paths across skipped releases/restored snapshots; normalized empty no-op; exact version/title/size bounds; whole build-source byte and duplicate-key checks. A rename-map change must advance its catalogue version. Several historical aliases may share a target; only a collision within one saved surface blocks its edit.
- AuthPort validates fresh attempt/owner/epoch/policy state before vault admission. A protected policy bootstrap survives interrupted changes and cannot be downgraded by an old snapshot. Monotonic grace and device-credential fallback preserve the specified lock modes.
- Direct holdings/document review and Inbox review have distinct UI boundaries but share frozen input, owner-bound route, source identity, atomic linked writes and receipt-first retry.
- Saved closes prepare and validate complete evidence in bounded pages, then use one admitted atomic command. A capacity failure keeps the month open and preserves its input; it never truncates evidence. P22 measures large-history close capacity.
- FEATURE_CONTRACTS maps F01–F21 and every SPEC13 calculation section. It names current reference storage and the typed feature migrations still required. No generic payload or stale chart can replace missing authoritative data.
- One canonical package remains, with one tables-only view and one complete UML. Old reports, stale manifests, duplicate maps and location stubs are preserved only in a verified history archive. Current migration fixtures and validators remain in place.

## Evidence and limits

The reference checks comprise **117 tests**: schema/query 30, shared-state 15, integrity regressions 9, layout/migration 48 and full-review 15. All 17 SQL examples run against the reference schema. Tables and UML are generated from the same schema: 90 nodes, 695 visible fields, 206 foreign keys and one logical FTS link. The package checker verifies local links, flow/calculation coverage, artifact counts and manifest integrity. See Validation.

No Contour Flutter/Drift app exists in this workspace. No production dependency was added. Python/SQLite checks do not prove SQLCipher encryption, exact financial solvers, native authentication/cancellation, filesystem durability, Flutter failure containment or phone speed.

| Gate | Required before its dependent release |
|---|---|
| PF-01 | A compliant platform/storage capability under the no-copy policy; or an explicit user-approved policy change. No real-user iOS persistence on a noncompliant path. Encryption and backup flags do not prove phone confinement. |
| S01–S07 / DB-A–F | Pinned cipher/platform integration, exact kernel, real command writer, bounded parsers, shared projections, typed feature migrations, authentication, recovery and privacy evidence |
| P01–P22 | Physical-device latency, frame, memory, disk/WAL, cancellation and full-history measurements. Timings in the plan are targets, not measured results. |
| W-A–L | Real registry/build checker/host/editor, hidden and accessible previews, resource disposal, restore/upgrade and Phase 1 tests |
| Product and finance | Applicable G01–G14, catalogue defaults, LAYOUT-UPGRADE, WIDGET-HALF-REFLOW and financial/display definitions in DECISIONS. Undefined figures stay gated; this review does not invent formulas. |

These limits are implementation and product prerequisites within the approved technical baseline. They cannot be removed by a passing reference test or by labelling the architecture final.
