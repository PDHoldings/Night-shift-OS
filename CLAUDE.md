# NightShift OS — agent notes

Read `docs/NIGHTSHIFT_OS_ARCHITECTURE.md` first. It is the single source of
truth: phase plan, data model, acceptance criteria, and rules of engagement.

## Hard rules

- **Never** use `Calendar.current.startOfDay(for:)` (or any midnight-anchored
  day boundary) in business logic. The `ShiftDay` and the user's personal day
  boundary are the entire point of this product.
- All roster/day-boundary math lives in `RosterKit` (pure Swift package, no UI
  imports). Any change there needs unit tests — DST transitions, time-zone
  travel, boundary edges ±1s, exceptions.
- Every log row denormalizes `shiftDayID`, resolved at write time via
  `RosterEngine.resolveShiftDay`. Never recompute it for stored rows.
- Brand strings only via `App/BrandConfig.swift` (final name TBD).
- Build in phase order. Phase 1 is local-first: no backend, no photo AI.
- Coach copy is general-wellness only — no diagnosis/treatment claims.
- Update `CHANGELOG.md` and the Build Status section of the architecture doc
  as work lands.

## Working in this repo

- `cd RosterKit && swift test` — runs on macOS and Linux; CI does both
  (`.github/workflows/rosterkit-tests.yml`).
- The iOS app can't be compiled on Linux. Keep app-layer changes conservative
  and push domain logic into RosterKit where it's testable.
- Xcode project is generated, not committed: `xcodegen generate` from
  `project.yml`.
