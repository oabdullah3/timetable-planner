# Automated Test Suite

**Date:** 2026-07-29
**Purpose:** Lock down manually-verified functionality with automated tests before further development.

## Scope

Unit tests only — no widget tests. Focus on the three most critical layers:

1. **Timetable Generator** — constraints, locks, clash detection, scoring
2. **Data Models** — JSON roundtrip, copy semantics
3. **Parser Service** — Excel parsing (via a fixture file)

## Test Structure

```
test/
├── fixtures/
│   └── minimal_test.xlsx          # Minimal 3-row Excel for parser tests
├── unit/
│   ├── generator/
│   │   ├── constraints_test.dart  # Min/max, desired range, course counting
│   │   ├── locks_test.dart        # Locked courses, locked sessions
│   │   ├── clash_test.dart        # Overlap detection, day separation
│   │   └── scoring_test.dart      # Violations, penalty, preference sorting
│   ├── models/
│   │   └── serialization_test.dart # JSON roundtrip, copyWith
│   └── services/
│       └── parser_test.dart       # Excel parsing with fixture
```

## Running by Phase

```bash
flutter test test/unit/generator/     # Generator tests only
flutter test test/unit/models/        # Model tests only
flutter test test/unit/services/      # Parser tests only
flutter test test/unit/               # All unit tests
flutter test                           # All tests
```

## Key Design Decisions

- Generator tests create model instances directly (no Excel parsing needed)
- Parser tests use the real `excel` package against a `.xlsx` fixture
- All tests are `flutter test` compatible (not widget tests)
- Each test file is self-contained — run individually or by directory
