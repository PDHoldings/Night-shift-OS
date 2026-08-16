# Changelog

## [Unreleased]

### Phase 1 — The Wedge (in progress)

#### Added
- `RosterKit` domain package: rotation model (N-day cycles, anchor date,
  midnight-crossing shifts stored as start + duration), personal day boundary
  rules (fixed time, shift-relative with off-day fallback), pure
  `resolveShiftDay` engine, roster exceptions (swap/overtime/call-off),
  shift-day labels ("Night 2 of 4"), streaks on ShiftDays, rules-based
  circadian timing coach, ShiftDay-aligned fasting timer.
- Rotation presets: fixed nights, 2-2-3 Panama, 4-on-4-off, DuPont (28-day),
  24/48, and the founder's Alcon A/B-week pattern.
- RosterKit test suite: doc acceptance criteria (3 AM log → prior ShiftDay),
  boundary edges ±1s, DST spring-forward/fall-back (including a boundary
  inside the spring-forward gap), time-zone travel, exception handling,
  streak semantics, preset structure, coach and fasting rules.
- SwiftUI app skeleton (iOS 18, SwiftData): onboarding (rotation → boundary →
  goal), Today (shift-day header + rings + next cue), Roster (8-week calendar
  with one-tap schedule-change exceptions), Log (manual entry + recents),
  Coach (shift timeline + anchor sleep card), Settings (day boundary, CSV
  export, wellness disclaimer).
- Roster-driven local notification scheduler (72h rolling window, quiet
  during the sleep window).
- Provider abstractions: `FoodDatabaseProvider` with Open Food Facts client;
  `FoodRecognitionProvider` protocol stub for Phase 2.
- XcodeGen project spec, CI workflow running RosterKit tests on Linux + macOS.

#### Notes
- DuPont preset uses the standard 28-day cycle (the architecture doc's "21"
  appears to be a typo; flagged for founder review).
