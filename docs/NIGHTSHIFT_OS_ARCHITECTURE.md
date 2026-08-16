# NightShift OS — Full Product Architecture
### Claude Code Handoff Document | Phanetics Digital Holdings, LLC
**Version:** 1.0 | **Date:** 2026-08-16 | **Owner:** Loi Phan (Mr. Lo), Founder/CEO
**Working title:** NightShift OS (final brand TBD — do not hardcode brand strings; use a `BrandConfig` constant)

---

## 0. Instructions to Claude Code (read first)

You are building a native iOS app for night-shift and rotating-shift workers. This document is the single source of truth. Rules of engagement:

1. **The roster is the architecture, not a feature.** Every entity in the data model is keyed to a `ShiftDay` (user-defined day boundary within a user-defined rotation), never to a calendar date at midnight. If you find yourself writing `Calendar.current.startOfDay(for:)` anywhere in business logic, stop — that is a bug by design.
2. **Build in phase order.** Do not pull Phase 2+ features into Phase 1. Each phase must compile, pass tests, and be usable on its own.
3. **Local-first.** Phase 1 requires zero backend. SwiftData + CloudKit sync. Backend (Cloudflare Workers — founder already operates 6 production Workers) enters in Phase 3.
4. **Do not build photo-calorie estimation from scratch.** Integrate a licensed SDK/vision API behind a protocol (`FoodRecognitionProvider`) so vendors are swappable. See §7.3.
5. **Ask before deviating** on: data model changes, adding third-party dependencies, changing the phase plan. Deviate freely on: internal implementation details, file organization within the prescribed structure.
6. **Testing bar:** unit tests for all roster/day-boundary math (this is the product's core IP — edge cases are the moat), plus UI tests for onboarding and logging flows.
7. Maintain a `CHANGELOG.md` and update the "Build Status" section at the bottom of this file as phases complete.

---

## 1. Problem Statement

~15M US night workers (and ~20% of the industrialized workforce globally) suffer structural health failure: weight gain (pooled OR 1.23 for obesity; permanent nights OR 1.43), Shift Work Disorder (~26.5% pooled prevalence), and 43% elevated depression risk. Every mainstream fitness app assumes a 9–5 life and a midnight day boundary. The most-cited broken feature in the market is MyFitnessPal's calorie day resetting at 12:00am — users literally spoof their phone's time zone to work around it. Rotating workers additionally face "circadian whiplash": no stable routine is possible, so all habit-based apps fail them.

**Thesis:** An app whose entire data model runs on the worker's actual roster — day boundary, meals, training, sleep, caffeine, streaks — solves what incumbents architecturally cannot without a rewrite.

## 2. Goals / Non-Goals

### Goals
- G1: A user on any rotation (fixed nights, 2-2-3, DuPont, 24/48, the founder's Alcon A/B-week pattern) can define it once and never manually re-set their day boundary.
- G2: Calorie/macro tracking that is *correct on their clock* — logging at 3am attributes to the right shift-day, streaks never break because of a calendar rollover.
- G3: Time-of-day-aware guidance: when to eat, caffeine cutoff, when to train, when to sleep — computed per upcoming shift.
- G4: 40% D30 retention among beta cohort of shift workers (vs. ~10–15% fitness-app norm) — the day-boundary correctness is the retention hypothesis.
- G5: Architecture supports future B2B (hospital/fire dept/logistics employer seats) without consumer-app rework: multi-tenant-ready identifiers, exportable aggregate wellness reports.

### Non-Goals (v1.x)
- NG1: Android (revisit post-PMF; keep business logic UI-agnostic to ease a future KMP or rewrite).
- NG2: Building our own food-image ML model (license it — commodity capability, accuracy risk).
- NG3: Medical diagnosis or treatment of Shift Work Disorder (regulatory line — we are a wellness app; include disclaimer copy).
- NG4: Social feed / general community in-app (Phase 4 at earliest; validation demand exists but is a distraction pre-PMF).
- NG5: Meal delivery / commerce integrations.

## 3. Target Users & Personas

| Persona | Schedule | Core pain | Willingness to pay |
|---|---|---|---|
| **Rotating Nurse "Rachel"** (primary) | 3x12s, rotating | Weight gain, day-boundary chaos, days-off flip decision | High (health-literate; employer budget path) |
| **Rotating Industrial "Marcus"** (primary) | 2-week rotation like Alcon | Circadian whiplash, no routine possible, vending machines | Medium (price-sensitive; employer channel) |
| **Permanent Nights "Dee"** | Fixed 11p–7a | Daytime sleep protection, isolation, when to train | Medium |
| **Firefighter "Tomas"** | 24/48 | Interrupted sleep, wants to train, recovery timing | Medium-high (dept wellness budgets) |
| **Trucker "Ray"** (Phase 3+) | Irregular OTR | No kitchen, sedentary, extreme obesity risk | Gear-buyer; app-skeptical |

## 4. Phase Plan (build order)

| Phase | Name | Contents | Exit criteria |
|---|---|---|---|
| **1** | The Wedge | Roster engine, day boundary, manual calorie/macro logging, circadian timing coach (rules-based), fasting timer, streaks-on-roster, onboarding | TestFlight beta; roster math test suite green; founder dogfoods a full A/B rotation |
| **2** | Intelligence | Photo calorie estimation (licensed provider), fatigue-aware training scheduler, workout library, shift snack planner + 3am fallback flow, days-off flip advisor | Photo log→confirm flow <15s; training plan adapts to a mid-week roster change |
| **3** | Integration | HealthKit read/write, daytime-sleep reclassification layer, Garmin (via HealthKit or Garmin Health API), Cloudflare Workers backend (auth, subscription, analytics), paywall | Sleep sessions during daytime correctly tagged; StoreKit 2 subscriptions live |
| **4** | Body & Beyond | Body comp (Navy tape formula — spec already exists in PDH archives), goal-shape guidance, progress photos, segment community (nurses/fire/logistics channels), B2B admin reporting | First employer pilot conversation-ready deck exportable from real aggregate data |

## 5. Core Concept: The Roster Engine

### 5.1 Definitions
- **Rotation**: a repeating pattern of `ShiftTemplate`s over an N-day cycle (N = 1 for fixed schedules, 14 for the founder's Alcon pattern, 21 for DuPont, etc.), with an anchor date.
- **ShiftTemplate**: `{ label, startTime, endTime, type: .night | .day | .swing | .off | .oncall }`. Times may cross midnight (store as start + duration, never two clock times).
- **ShiftDay**: the atomic unit of the app. A user's "day" begins at their **personal day boundary** — user-chosen, default = "when I wake," configurable as (a) fixed clock time, (b) offset from shift start (e.g., shift-start − 4h), or (c) wake event (from sleep log/HealthKit in Phase 3). All logs, targets, streaks, and summaries aggregate to ShiftDay.
- **Roster exceptions**: swapped shifts, overtime, call-offs. One-tap "my schedule changed" flow regenerates all downstream guidance from the change point forward — this is the rotating-worker killer feature.

### 5.2 Non-negotiable behaviors
- Logging an item at 02:47 during a night shift attributes to the ShiftDay that began the previous afternoon/evening.
- A streak = consecutive ShiftDays with the target behavior — never broken by a calendar date change, DST transition, or time-zone travel. (DST + rotation math must have exhaustive unit tests: spring-forward mid-shift, fall-back mid-sleep, user flies across time zones.)
- Deleting/editing a roster never orphans historical logs — logs pin to their resolved ShiftDay at write time (denormalize `shiftDayID` onto every log row).
- Days off: user chooses per-off-block strategy — "stay nocturnal" or "flip to days" — and the day boundary follows the choice. The **Flip Advisor** (Phase 2) recommends based on off-block length (rule of thumb: <2 days stay, ≥3 days flip candidate) and next-shift proximity.

## 6. Feature Requirements

### P0 — Phase 1 (cannot ship without)
1. **Rotation builder** — visual pattern editor; presets (fixed nights, 2-2-3 Panama, 4-on-4-off, DuPont, 24/48, custom N-day); anchor date; per-shift start/end.
   - AC: Founder's Alcon pattern (A-week Mon/Tue/Fri/Sat/Sun, B-week Wed/Thu, 18:00–06:30) representable in ≤2 minutes; renders correctly 8 weeks forward.
2. **Personal day boundary** — the flagship. Settings: fixed time / shift-relative / wake-based (Phase 3).
   - AC: Given boundary = 15:00, when user logs food at 03:00, then it appears in the ShiftDay that started at 15:00 the prior calendar date. Daily summary header shows shift-day label ("Night 3 of 5"), not just a date.
3. **Calorie & macro logging (manual + barcode)** — food database via Open Food Facts (barcode) + local user-foods + recent/frequent; macro targets per ShiftDay; targets can differ by shift type (shift day vs. off day).
4. **Circadian timing coach (rules-based v1)** — per upcoming shift: caffeine cutoff (last dose ≥8h before intended sleep), light guidance (bright early-shift, dim/sunglasses on commute home), anchor-sleep window suggestion, meal-timing template ("main meal before shift, light protein snacks during, no large meal at 4am"). Deterministic rules in v1; personalization later. Cite non-medical wellness framing.
5. **Fasting timer** — user-configured window, aligned to ShiftDay (carried from the original PDH Fitness Tracker Phase 1 spec).
6. **Streaks & shift-aware notifications** — notifications scheduled against roster (pre-shift meal reminder, caffeine-cutoff alert, wind-down alert after shift). Quiet during the user's sleep window *even though that's daytime*.
7. **Onboarding** — rotation setup → day boundary → goal (lose/maintain/gain/energy) → targets. ≤4 minutes; skippable depth.

### P1 — Phase 2
8. **Photo calorie estimation** — camera → provider estimate → user confirm/adjust → log. Always editable; show confidence; never auto-log without confirmation.
9. **Fatigue-aware training scheduler** — inputs: roster, logged/HealthKit sleep, subjective 1–5 energy check-in. Output: today's recommended session from the user's plan, with automatic **downgrade path** (planned strength → short strength → 20-min walk → mobility → rest) so a wrecked user keeps the streak with a smaller win. AC: mid-week roster change triggers full re-plan within one app launch.
10. **Shift snack planner + "3am fallback"** — pre-shift packing checklist from the plan; a one-tap "I'm at the vending machine" flow ranking least-bad choices and logging instantly. (Directly answers the top demand signal.)
11. **Days-off Flip Advisor** — per §5.2.

### P2 — Phase 3–4
12. **HealthKit integration + daytime-sleep reclassification** — read sleep/workouts/steps/HR; write nutrition/workouts. Reclassification layer flags and corrects sleep sessions mislabeled by source apps (e.g., 09:00–16:00 sleep is main sleep, not a nap).
13. **Body composition** — measurements (neck/waist/hip/height), US Navy circumference body-fat formula, trend charts on ShiftDay axis, goal-shape selection driving nutrition/training emphasis (per existing PDH Fitness Tracker Phase 4 spec).
14. **Backend & monetization** — Cloudflare Workers + D1/KV: account, receipt validation (StoreKit 2), anonymized analytics, feature flags. Pricing: free tier (roster + manual logging) / Pro **$4.99/mo or $39.99/yr** (photo logging, training scheduler, coach) — anchored to researched willingness-to-pay ($4–6/mo; $11/mo drew explicit resistance). B2B seat pricing deferred to pilot.
15. **Segment community & B2B reporting** — Phase 4; do not architect prematurely beyond keeping `userID` opaque and aggregates exportable.

## 7. Technical Architecture

### 7.1 Stack
- **Client:** Swift 6, SwiftUI, iOS 18+ target. SwiftData for persistence, CloudKit for sync. Swift Charts for trends. MVVM with an explicit domain layer (`RosterKit` — a local Swift package holding all roster/day-boundary math, zero UI imports, 100% unit-testable).
- **Backend (Phase 3):** Cloudflare Workers (TypeScript), D1 (relational), KV (flags/config), Queues (analytics ingestion). Reuses founder's existing Cloudflare account/infra. Auth: Sign in with Apple.
- **Notifications:** local `UNNotificationRequest`s computed from roster (72h rolling window, recomputed on app open and roster change); push (APNs via Workers) only in Phase 3+.

### 7.2 Data model (SwiftData entities — simplified)
```
Rotation { id, name, cycleLengthDays, anchorDate, dayBoundaryRule }
ShiftTemplate { id, rotationID, dayIndexInCycle, label, type, startTimeComponents, durationMinutes }
RosterException { id, date, replacementTemplate?, note }        // swaps, OT, call-offs
ShiftDay { id, resolvedStart, resolvedEnd, shiftType, label }   // materialized, cached forward 60d
FoodLog { id, shiftDayID, timestamp, name, kcal, protein, carbs, fat, source(.manual|.barcode|.photo), photoRef?, confidence? }
SleepLog { id, shiftDayID, start, end, quality?, source, classification(.main|.nap|.anchor) }
WorkoutLog { id, shiftDayID, start, type, durationMin, intensity, source, wasDowngraded }
EnergyCheckIn { id, shiftDayID, timestamp, score1to5 }
BodyMeasurement { id, shiftDayID, neckCm, waistCm, hipCm?, weightKg, navyBodyFatPct(computed) }
GoalProfile { id, objective, targetKcalByShiftType{}, macroSplit, goalShape?, fastingWindow? }
Streak { id, habitType, currentCount, bestCount, lastShiftDayID }
```
**Invariant:** every log row carries `shiftDayID` resolved at write time. ShiftDay resolution function signature: `resolveShiftDay(for timestamp: Date, rotation: Rotation, exceptions: [RosterException], tz: TimeZone) -> ShiftDay` — pure, deterministic, exhaustively tested (DST, tz travel, boundary-edge ±1s, mid-rotation edits, exceptions overlapping boundaries).

### 7.3 Provider abstractions (swappable vendors)
```
protocol FoodRecognitionProvider { estimate(image) async -> [FoodEstimate] }   // Passio SDK first; fallback: Claude vision API via Workers proxy
protocol FoodDatabaseProvider   { searchBarcode/searchText }                    // Open Food Facts first
protocol SleepDataProvider      { fetchSessions(range) }                        // HealthKit
```
Evaluate Passio Nutrition-AI SDK vs. Foodvisor vs. Claude-vision-via-Workers on: cost/scan, offline capability, license terms. Present comparison to founder before committing (Phase 2 gate).

### 7.4 Project structure
```
NightShiftOS/
  RosterKit/            # pure domain package: rotation math, day boundary, streaks, flip advisor, timing rules
  App/ (SwiftUI)        # Features/{Onboarding,Today,Log,Coach,Train,Body,Settings}
  Providers/            # food recognition, food db, health data — behind protocols
  Backend/ (Phase 3)    # Cloudflare Workers monorepo (TypeScript)
  Tests/                # RosterKitTests (priority 1), snapshot + UI tests
```

### 7.5 Key screens (Phase 1)
1. **Today** (home): shift-day header ("Night 2 of 4 · day ends 15:00"), rings for kcal/protein on *this ShiftDay*, next timing cue ("Caffeine cutoff in 1h 20m"), quick-log buttons.
2. **Roster**: rotation calendar 8 weeks out; tap-to-edit exceptions.
3. **Log**: search / barcode / recent; (Phase 2 adds camera tab).
4. **Coach**: tonight's plan — eat/caffeine/light/sleep timeline rendered as a horizontal shift timeline, not a midnight-anchored day.
5. **Settings**: day boundary rule, targets by shift type, notifications, data export (CSV — trust feature for this skeptical audience).

## 8. Success Metrics
- **Leading:** onboarding completion ≥70%; ≥5 logs in first 3 ShiftDays ≥50%; roster-exception feature used by ≥30% of rotating users in first month; photo-log confirm rate ≥80% (Phase 2).
- **Lagging:** D30 retention ≥40% (success) / ≥50% (stretch) in shift-worker beta; free→Pro conversion ≥5% at 60 days post-paywall; qualitative: unprompted "finally, my day doesn't reset at midnight" language in reviews.
- **Kill/pivot criterion:** if D30 <20% after two beta iterations, the wedge hypothesis is wrong — halt Phase 3, reassess.

## 9. Risks & Open Questions
- **R1 — Photo-calorie accuracy blowback:** mitigated by confirm-before-log, visible confidence, provider abstraction. (Owner: eng)
- **R2 — Apple sleep API limitations for daytime sleep:** validate HealthKit behavior with real daytime-sleep data early in Phase 3 spike. (Owner: eng — blocking for feature 12)
- **R3 — Wellness vs. medical-claim line:** all coach copy reviewed against "general wellness" FDA guidance; no SWD diagnosis/treatment claims. (Owner: founder + counsel — non-blocking, must clear before App Store submission)
- **R4 — MFP ships a day-boundary setting:** defense is roster-native everything (streaks, notifications, training, flip advisor), not the setting alone. Speed matters.
- **Q1:** Final brand name + App Store positioning (founder). **Q2:** Passio license cost at scale (eng, Phase 2 gate). **Q3:** Beta recruitment channels — r/nightshift, allnurses, founder's Alcon network (founder, before Phase 1 exit).

## 10. Build Status (Claude Code: update this)
- [~] Phase 1 — in progress (2026-08-16): RosterKit domain package (roster engine, day boundary, exceptions, streaks, timing coach, fasting, presets incl. Alcon A/B) with full unit-test suite; SwiftUI app skeleton (onboarding, Today, Roster, Log, Coach, Settings); roster-driven notification scheduler; Open Food Facts provider; CI running RosterKit tests on Linux + macOS. Remaining: barcode scan UI, targets-by-shift-type editor wiring, TestFlight beta, founder dogfood of a full A/B rotation.
- [ ] Phase 2 — blocked on Phase 1
- [ ] Phase 3 — blocked on Phase 2
- [ ] Phase 4 — blocked on Phase 3

---
*PDH internal. Mission: creating value at the speed of thought.*
