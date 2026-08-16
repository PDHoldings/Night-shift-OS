import Foundation
import XCTest
@testable import RosterKit

/// DST transitions and time-zone travel are the moat: streaks and attribution
/// must survive both. US 2026 transitions: spring forward Mar 8, fall back Nov 1.
final class DSTAndTravelTests: XCTestCase {
    let tz = TestSupport.chicago

    func testSpringForwardMidShiftAttribution() {
        // Night shift 18:00 Mar 7 + 12.5h elapsed crosses the 02:00→03:00 jump.
        let rotation = TestSupport.simpleNightRotation()
        let logTime = TestSupport.date(2026, 3, 8, 3, 30, tz: tz) // just after the jump

        let day = RosterEngine.resolveShiftDay(for: logTime, rotation: rotation, timeZone: tz)

        XCTAssertEqual(day.calendarDate, CalendarDate(year: 2026, month: 3, day: 7))
        let shift = day.shift!
        XCTAssertEqual(shift.end.timeIntervalSince(shift.start), 750 * 60,
                       "duration is elapsed time, unaffected by the wall-clock jump")
    }

    func testSpringForwardDayIsShorter() {
        // The ShiftDay containing the spring-forward night is 23h long.
        let rotation = TestSupport.simpleNightRotation()
        let day = RosterEngine.resolveShiftDay(
            for: TestSupport.date(2026, 3, 7, 20, 0, tz: tz),
            rotation: rotation,
            timeZone: tz
        )
        XCTAssertEqual(day.end.timeIntervalSince(day.start), 23 * 3600)
    }

    func testFallBackAmbiguousHourResolves() {
        // 01:30 on Nov 1 occurs twice; both instants must resolve into the
        // ShiftDay that began Oct 31 at 15:00, with no crash.
        let rotation = TestSupport.simpleNightRotation()
        let firstOccurrence = TestSupport.date(2026, 11, 1, 1, 30, tz: tz)
        let secondOccurrence = firstOccurrence.addingTimeInterval(3600)

        for instant in [firstOccurrence, secondOccurrence] {
            let day = RosterEngine.resolveShiftDay(for: instant, rotation: rotation, timeZone: tz)
            XCTAssertEqual(day.calendarDate, CalendarDate(year: 2026, month: 10, day: 31))
            XCTAssertTrue(day.contains(instant))
        }
    }

    func testFallBackDayIsLonger() {
        let rotation = TestSupport.simpleNightRotation()
        let day = RosterEngine.resolveShiftDay(
            for: TestSupport.date(2026, 10, 31, 20, 0, tz: tz),
            rotation: rotation,
            timeZone: tz
        )
        XCTAssertEqual(day.end.timeIntervalSince(day.start), 25 * 3600)
    }

    func testBoundaryInsideSpringForwardGapStillTiles() {
        // A (pathological) 02:30 boundary doesn't exist on Mar 8. Resolution
        // must still tile time: every probed instant belongs to exactly one
        // ShiftDay and consecutive days share edges.
        let rotation = TestSupport.simpleNightRotation(boundary: .fixedTime(minuteOfDay: 2 * 60 + 30))
        var probe = TestSupport.date(2026, 3, 7, 12, 0, tz: tz)
        let end = TestSupport.date(2026, 3, 9, 12, 0, tz: tz)
        var previous: ShiftDay?
        while probe < end {
            let day = RosterEngine.resolveShiftDay(for: probe, rotation: rotation, timeZone: tz)
            XCTAssertTrue(day.contains(probe), "instant \(probe) not inside its resolved day")
            if let prev = previous, prev.calendarDate != day.calendarDate {
                XCTAssertEqual(prev.end, day.start)
            }
            previous = day
            probe = probe.addingTimeInterval(30 * 60)
        }
    }

    func testTimeZoneTravelKeepsResolutionConsistent() {
        // Same rotation, same instants — the user flies Chicago → Tokyo and the
        // app re-resolves in the new zone. Resolution must stay total (every
        // instant maps to a containing day) and contiguous in each zone.
        let rotation = TestSupport.simpleNightRotation()
        let instant = TestSupport.date(2026, 8, 16, 3, 0, tz: TestSupport.chicago)

        let home = RosterEngine.resolveShiftDay(for: instant, rotation: rotation, timeZone: TestSupport.chicago)
        let abroad = RosterEngine.resolveShiftDay(for: instant, rotation: rotation, timeZone: TestSupport.tokyo)

        XCTAssertTrue(home.contains(instant))
        XCTAssertTrue(abroad.contains(instant))
        // 03:00 Aug 16 Chicago = 17:00 Aug 16 Tokyo → cycle day Aug 16 in Tokyo
        // (its day started 15:00 Tokyo), day Aug 15 at home. Both are correct
        // *within their zone*; the point is neither crashes nor mis-tiles.
        XCTAssertEqual(home.calendarDate, CalendarDate(year: 2026, month: 8, day: 15))
        XCTAssertEqual(abroad.calendarDate, CalendarDate(year: 2026, month: 8, day: 16))
    }

    func testStreakSurvivesDSTTransition() {
        let rotation = TestSupport.simpleNightRotation()
        let calendar = RosterEngine.calendar(in: tz)
        var streak = Streak(habitType: "protein")

        // Hit the target on the days spanning fall-back (Oct 31, Nov 1, Nov 2).
        for (m, d) in [(10, 30), (10, 31), (11, 1), (11, 2)] {
            let day = RosterEngine.resolveShiftDay(
                for: TestSupport.date(2026, m, d, 20, 0, tz: tz),
                rotation: rotation,
                timeZone: tz
            )
            streak = StreakEngine.recordAchievement(on: day, streak: streak, calendar: calendar)
        }
        XCTAssertEqual(streak.currentCount, 4, "a calendar rollover or DST shift must never break a streak")
    }
}
