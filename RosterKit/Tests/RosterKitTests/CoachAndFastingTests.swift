import Foundation
import XCTest
@testable import RosterKit

final class CoachAndFastingTests: XCTestCase {
    let tz = TestSupport.chicago

    private var nightShift: ResolvedShift {
        ResolvedShift(
            label: "Night",
            type: .night,
            start: TestSupport.date(2026, 8, 10, 18, 0, tz: tz),
            end: TestSupport.date(2026, 8, 11, 6, 30, tz: tz)
        )
    }

    func testCaffeineCutoffIsEightHoursBeforeSleep() {
        let plan = TimingCoach.plan(for: nightShift)
        // Sleep = shift end + 30m commute + 30m wind-down = 07:30.
        let expectedSleep = TestSupport.date(2026, 8, 11, 7, 30, tz: tz)
        XCTAssertEqual(plan.sleepWindow.start, expectedSleep)
        XCTAssertEqual(plan.caffeineCutoff, expectedSleep.addingTimeInterval(-8 * 3600)) // 23:30 mid-shift
    }

    func testCuesAreOrderedAndComplete() {
        let plan = TimingCoach.plan(for: nightShift)
        let times = plan.cues.map(\.time)
        XCTAssertEqual(times, times.sorted())

        let kinds = Set(plan.cues.map(\.kind))
        for required: CoachCue.Kind in [.mainMeal, .caffeineCutoff, .brightLight, .dimLight, .windDown, .sleepStart, .avoidLargeMeal] {
            XCTAssertTrue(kinds.contains(required), "missing cue \(required)")
        }
    }

    func testMainMealPrecedesShift() {
        let plan = TimingCoach.plan(for: nightShift)
        let mainMeal = plan.cues.first { $0.kind == .mainMeal }!
        XCTAssertEqual(mainMeal.time, TestSupport.date(2026, 8, 10, 16, 30, tz: tz))
    }

    func testSleepWindowLengthMatchesPreference() {
        let prefs = CoachPreferences(targetSleepHours: 6.5)
        let plan = TimingCoach.plan(for: nightShift, preferences: prefs)
        XCTAssertEqual(plan.sleepWindow.duration, 6.5 * 3600)
    }

    // MARK: - Fasting

    private var shiftDays: [ShiftDay] {
        RosterEngine.shiftDays(
            startingAt: TestSupport.date(2026, 8, 15, 16, 0, tz: tz),
            count: 2,
            rotation: TestSupport.simpleNightRotation(),
            timeZone: tz
        )
    }

    func testFastingWindowAlignsToShiftDayNotMidnight() {
        let days = shiftDays
        let window = FastingWindow.sixteenEight // eat 15:00–23:00 on this roster

        let eating = FastingTimer.eatingInterval(for: window, on: days[0])
        XCTAssertEqual(eating.start, TestSupport.date(2026, 8, 15, 15, 0, tz: tz))
        XCTAssertEqual(eating.end, TestSupport.date(2026, 8, 15, 23, 0, tz: tz))
    }

    func testFastingStateTransitions() {
        let days = shiftDays
        let window = FastingWindow.sixteenEight

        // 16:00 — eating, until 23:00.
        let atFour = FastingTimer.state(at: TestSupport.date(2026, 8, 15, 16, 0, tz: tz), window: window, shiftDay: days[0], nextShiftDay: days[1])
        XCTAssertEqual(atFour, .eating(until: TestSupport.date(2026, 8, 15, 23, 0, tz: tz)))

        // 02:00 (mid night shift, next calendar day) — fasting until 15:00,
        // still within the same ShiftDay.
        let atTwo = FastingTimer.state(at: TestSupport.date(2026, 8, 16, 2, 0, tz: tz), window: window, shiftDay: days[0], nextShiftDay: days[1])
        XCTAssertEqual(atTwo, .fasting(until: TestSupport.date(2026, 8, 16, 15, 0, tz: tz)))
    }

    func testFastProgress() {
        let days = shiftDays
        let window = FastingWindow.sixteenEight
        // Fast runs 23:00 → 15:00 next day (16h). At 07:00 we are 8h in = 0.5.
        let progress = FastingTimer.fastProgress(
            at: TestSupport.date(2026, 8, 16, 7, 0, tz: tz),
            window: window,
            shiftDay: days[0],
            nextShiftDay: days[1]
        )
        XCTAssertEqual(progress!, 0.5, accuracy: 0.001)
    }
}
