# NightShift OS

A native iOS app for night-shift and rotating-shift workers, built by
Phanetics Digital Holdings, LLC. Working title — the brand is configured in
`App/BrandConfig.swift`, never hardcoded.

**The roster is the architecture, not a feature.** Every log, target, streak,
and summary is keyed to a `ShiftDay` — the user's own day, bounded by their
personal day boundary — never to a calendar date at midnight.

See [`docs/NIGHTSHIFT_OS_ARCHITECTURE.md`](docs/NIGHTSHIFT_OS_ARCHITECTURE.md)
for the full product architecture and phase plan.

## Repository layout

```
RosterKit/     Pure domain Swift package: rotation math, day boundary,
               streaks, timing coach, fasting. Zero UI imports, 100% unit-testable.
App/           SwiftUI app (iOS 18+, SwiftData). Features/{Onboarding,Today,Log,Coach,Settings}
Providers/     Vendor abstractions: food database (Open Food Facts), food
               recognition (Phase 2, protocol only)
Tests/         UI tests (RosterKit's own tests live in RosterKit/Tests)
docs/          Architecture handoff document
project.yml    XcodeGen spec — generates NightShiftOS.xcodeproj
```

## Getting started

### Domain package (any platform)

```bash
cd RosterKit
swift test
```

RosterKit is pure Foundation — it builds and tests on macOS and Linux. CI runs
the suite on both (`.github/workflows/rosterkit-tests.yml`).

### iOS app (macOS + Xcode 16+)

```bash
brew install xcodegen
xcodegen generate
open NightShiftOS.xcodeproj
```

## Development rules (from the architecture doc)

1. Never write `Calendar.current.startOfDay(for:)` in business logic — the
   midnight day boundary is the bug this product exists to fix.
2. Build in phase order; don't pull Phase 2+ features forward.
3. Local-first: Phase 1 has zero backend.
4. Every log row denormalizes `shiftDayID`, resolved at write time.
5. Roster/day-boundary math changes require unit tests — DST, time-zone
   travel, and boundary-edge cases are the moat.

## Status

Phase 1 (The Wedge) — in progress. See the Build Status section of the
architecture doc and `CHANGELOG.md`.
