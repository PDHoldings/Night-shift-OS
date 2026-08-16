import Foundation
import XCTest
@testable import RosterKit

/// "My schedule changed" — swaps, overtime, call-offs — must regenerate
/// everything downstream while historical attribution stays stable.
final class RosterExceptionTests: XCTestCase {
    let tz = TestSupport.chicago

    func testSwapReplacesShift() {
        let rotation = TestSupport.alcon()
        // Swap Tue night (Aug 11) for a day shift 07:00–19:00.
        let swap = RosterException(
            date: CalendarDate(year: 2026, month: 8, day: 11),
            replacement: ShiftOverride(label: "Day (swap)", type: .day, startMinuteOfDay: 7 * 60, durationMinutes: 12 * 60)
        )

        // Probe inside the ShiftDay for cycle date Aug 11 (fixed boundary 15:00).
        let day = RosterEngine.resolveShiftDay(
            for: TestSupport.date(2026, 8, 11, 16, 0, tz: tz),
            rotation: rotation,
            exceptions: [swap],
            timeZone: tz
        )
        XCTAssertEqual(day.shiftType, .day)
        XCTAssertEqual(day.shift?.start, TestSupport.date(2026, 8, 11, 7, 0, tz: tz))
    }

    func testCallOffBecomesOffDay() {
        let rotation = TestSupport.alcon()
        let callOff = RosterException(
            date: CalendarDate(year: 2026, month: 8, day: 11),
            replacement: nil,
            note: "called off"
        )

        let day = RosterEngine.resolveShiftDay(
            for: TestSupport.date(2026, 8, 11, 20, 0, tz: tz),
            rotation: rotation,
            exceptions: [callOff],
            timeZone: tz
        )
        XCTAssertEqual(day.shiftType, .off)
        XCTAssertNil(day.shift)
    }

    func testShiftRelativeBoundaryFollowsException() {
        // With a shift-relative boundary, swapping the shift moves the day
        // boundary too — the day is defined by the user's actual roster.
        var rotation = TestSupport.alcon()
        rotation.dayBoundaryRule = .shiftRelative(offsetMinutes: -240, offDayFallbackMinuteOfDay: 15 * 60)
        let swap = RosterException(
            date: CalendarDate(year: 2026, month: 8, day: 11),
            replacement: ShiftOverride(label: "Day (swap)", type: .day, startMinuteOfDay: 7 * 60, durationMinutes: 12 * 60)
        )

        let day = RosterEngine.resolveShiftDay(
            for: TestSupport.date(2026, 8, 11, 8, 0, tz: tz),
            rotation: rotation,
            exceptions: [swap],
            timeZone: tz
        )
        // Boundary = 07:00 − 4h = 03:00 on Aug 11.
        XCTAssertEqual(day.start, TestSupport.date(2026, 8, 11, 3, 0, tz: tz))
    }

    func testExceptionKeepsTilingContiguous() {
        var rotation = TestSupport.alcon()
        rotation.dayBoundaryRule = .shiftRelative(offsetMinutes: -240, offDayFallbackMinuteOfDay: 15 * 60)
        let callOff = RosterException(date: CalendarDate(year: 2026, month: 8, day: 11), replacement: nil)

        let days = RosterEngine.shiftDays(
            startingAt: TestSupport.date(2026, 8, 9, 16, 0, tz: tz),
            count: 7,
            rotation: rotation,
            exceptions: [callOff],
            timeZone: tz
        )
        for (a, b) in zip(days, days.dropFirst()) {
            XCTAssertEqual(a.end, b.start)
        }
    }

    func testHistoricalIDsStableAcrossRosterEdits() {
        // Editing the roster later must not orphan logs: the ShiftDay id for a
        // past instant is derived from the cycle date, so it is identical
        // before and after an exception is added elsewhere.
        let rotation = TestSupport.alcon()
        let pastLog = TestSupport.date(2026, 8, 11, 2, 0, tz: tz)
        let before = RosterEngine.resolveShiftDay(for: pastLog, rotation: rotation, timeZone: tz)

        let laterEdit = RosterException(
            date: CalendarDate(year: 2026, month: 8, day: 20),
            replacement: ShiftOverride(label: "OT", type: .night, startMinuteOfDay: 18 * 60, durationMinutes: 750)
        )
        let after = RosterEngine.resolveShiftDay(for: pastLog, rotation: rotation, exceptions: [laterEdit], timeZone: tz)

        XCTAssertEqual(before.id, after.id)
    }
}
