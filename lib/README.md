# lib/ map (AGENTS 3)

- `app/` — start, router (sets Section per route), theme, lock.
- `core/` — pure Dart: money, decimal policy, dates, ids, result. No Flutter imports.
- `design/` — tokens, theme, typography, icons, components, charts, layout, format, gallery. Only styled code.
- `domain/` — pure Dart entities and math. Tests first. No `DateTime.now()`.
- `data/` — drift db, repositories, prices (only network folder), capture, backup.
- `features/` — one folder per area. Widgets read providers only.
- `l10n/` — strings. English in v1.

Rules: money = int minor + currency. Math = Decimal. Unknown is never zero. No secrets in code.
