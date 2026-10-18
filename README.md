# Contour

Local-first personal finance app. No server, no account. No user data leaves
the device (AGENTS.md section 2). Phase 1 uses synthetic data only (PF-01).

## Setup

```
flutter pub get
```

`lib/design/tokens/tokens.g.dart` is committed (CR-01), so a clean clone builds
without running a generator.

## Commands

Run before every commit. All must pass (AGENTS.md section 4).

```
dart run tool/gen_tokens.dart          # regenerate tokens from tokens.json
flutter gen-l10n                       # strings (from T10)
dart format --set-exit-if-changed .
flutter analyze
dart run custom_lint                   # design and privacy lint rules (from T12)
dart run tool/check_tokens.dart
dart run tool/check_contrast.dart
flutter test
flutter test --tags golden
flutter test integration_test          # on a simulator or emulator
```

`dart run build_runner build -d` returns with the T06/T07 generators. It is not
a dependency until that task adds it (CR-08).

## Layout

See AGENTS.md section 3. Rules live in `AGENTS.md`, `spec.md` and `design.md`;
full detail is in `docs/`.
