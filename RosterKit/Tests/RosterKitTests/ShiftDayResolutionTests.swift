import Foundation
import XCTest
@testable import RosterKit

/// The product's headline acceptance criteria: logs attribute to the user's
/// ShiftDay, never to the calendar date at midnight.
final class ShiftDayResolutionTests: XCTestCase {
    let tz = TestSupport.chicago

    // Doc AC: boundary = 15:00, user logs food at 03:00 → the log's ShiftDay
    // started at 15:00 the *prior* calendar date.
    func testThreeAMLogAttributesToPriorDay() {
        let rotation = TestSupport.simpleNightRotation()
        let logTime = TestSupport.date(2026, 8, 16, 3, 0, tz: tz)

        let day = RosterEngine.resolveShiftDay(for: logTime, rotation: rotation, timeZone: tz)

        XCTAssertEqual(day.calendarDate, CalendarDate(year: 2026, month: 8, day: 15))
        XCTAssertEqual(day.start, TestSupport.date(2026, 8, 15, 15, 0, tz: tz))
        XCTAssertEqual(day.end, TestSupport.date(2026, 8, 16, 15, 0, tz: tz))
        XCTAssertTrue(day.contains(logTime))
    }

    // §5.2: logging at 02:47 during a night shift attributes to the ShiftDay
    // that began the previous afternoon.
    func testMidShiftLogDuringNightShift() {
        let rotation = TestSupport.alcon()
        let logTime = TestSupport.date(2026, 8, 11, 2, 47, tz: tz) // during Mon-night shift

        let day = RosterEngine.resolveShiftDay(for: logTime, rotation: rotation, timeZone: tz)

        XCTAssertEqual(day.calendarDate, CalendarDate(year: 2026, month: 8, day: 10))
        XCTAssertEqual(day.shiftType, .night)
        let shift = try! XCTUnwrap(day.shift)
        XCTAssertEqual(shift.start, TestSupport.date(2026, 8, 10, 18, 0, tz: tz))
        XCTAssertEqual(shift.end, TestSupport.date(2026, 8, 11, 6, 30, tz: tz))
    }

    // Boundary edges must be exact: one second before the boundary belongs to
    // the old day, the boundary instant itself starts the new day.
    func testBoundaryEdgeOneSecondEitherSide() {
        let rotation = TestSupport.simpleNightRotation()
        let boundary = TestSupport.date(2026, 8, 16, 15, 0, 0, tz: tz)

        let justBefore = RosterEngine.resolveShiftDay(for: boundary.addingTimeInterval(-1), rotation: rotation, timeZone: tz)
        let atBoundary = RosterEngine.resolveShiftDay(for: boundary, rotation: rotation, timeZone: tz)
        let justAfter = RosterEngine.resolveShiftDay(for: boundary.addingTimeInterval(1), rotation: rotation, timeZone: tz)

        XCTAssertEqual(justBefore.calendarDate, CalendarDate(year: 2026, month: 8, day: 15))
        XCTAssertEqual(atBoundary.calendarDate, CalendarDate(year: 2026, month: 8, day: 16))
        XCTAssertEqual(justAfter.calendarDate, CalendarDate(year: 2026, month: 8, day: 16))
        XCTAssertEqual(justBefore.end, atBoundary.start, "ShiftDays must tile time with no gap")
    }

    func testShiftRelativeBoundary() {
        // Boundary = shift start − 4h → 14:00 on working days.
        let rotation = TestSupport.simpleNightRotation(
            boundary: .shiftRelative(offsetMinutes: -240, offDayFallbackMinuteOfDay: 15 * 60)
        )

        let day = RosterEngine.resolveShiftDay(
            for: TestSupport.date(2026, 8, 16, 14, 30, tz: tz),
            rotation: rotation,
            timeZone: tz
        )
        XCTAssertEqual(day.calendarDate, CalendarDate(year: 2026, month: 8, day: 16))
        XCTAssertEqual(day.start, TestSupport.date(2026, 8, 16, 14, 0, tz: tz))

        let earlier = RosterEngine.resolveShiftDay(
            for: TestSupport.date(2026, 8, 16, 13, 59, tz: tz),
            rotation: rotation,
            timeZone: tz
        )
        XCTAssertEqual(earlier.calendarDate, CalendarDate(year: 2026, month: 8, day: 15))
    }

    func testShiftRelativeOffDayFallback() {
        // Alcon: Wed of A-week (index 2) is off; fallback boundary 15:00 applies.
        var rotation = TestSupport.alcon()
        rotation.dayBoundaryRule = .shiftRelative(offsetMinutes: -240, offDayFallbackMinuteOfDay: 15 * 60)

        let day = RosterEngine.resolveShiftDay(
            for: TestSupport.date(2026, 8, 12, 16, 0, tz: tz), // Wed A-week, off
            rotation: rotation,
            timeZone: tz
        )
        XCTAssertEqual(day.shiftType, .off)
        XCTAssertEqual(day.start, TestSupport.date(2026, 8, 12, 15, 0, tz: tz))
    }

    // ShiftDays must tile time: across a whole cycle, end(k) == start(k+1).
    func testShiftDaysAreContiguous() {
        let rotation = TestSupport.alcon()
        let days = RosterEngine.shiftDays(
            startingAt: TestSupport.date(2026, 8, 10, 16, 0, tz: tz),
            count: 56,
            rotation: rotation,
            timeZone: tz
        )
        XCTAssertEqual(days.count, 56)
        for (a, b) in zip(days, days.dropFirst()) {
            XCTAssertEqual(a.end, b.start, "gap between \(a.calendarDate) and \(b.calendarDate)")
        }
    }

    // Stable IDs: resolving the same instant twice yields the same ShiftDay id,
    // and ids embed the cycle date so logs pin correctly at write time.
    func testStableShiftDayID() {
        let rotation = TestSupport.simpleNightRotation()
        let t = TestSupport.date(2026, 8, 16, 3, 0, tz: tz)
        let a = RosterEngine.resolveShiftDay(for: t, rotation: rotation, timeZone: tz)
        let b = RosterEngine.resolveShiftDay(for: t, rotation: rotation, timeZone: tz)
        XCTAssertEqual(a.id, b.id)
        XCTAssertTrue(a.id.hasSuffix("2026-08-15"))
    }

    func testLabelShowsPositionInRun() {
        let rotation = TestSupport.alcon()
        // A-week: Fri/Sat/Sun is a 3-night run. Sat (Aug 15) is night 2 of 3.
        let day = RosterEngine.resolveShiftDay(
            for: TestSupport.date(2026, 8, 15, 19, 0, tz: tz),
            rotation: rotation,
            timeZone: tz
        )
        XCTAssertEqual(day.label, "Night 2 of 3")

        // Wed/Thu off after A-week Tue: Aug 12 is Off 1 of 2.
        let offDay = RosterEngine.resolveShiftDay(
            for: TestSupport.date(2026, 8, 12, 16, 0, tz: tz),
            rotation: rotation,
            timeZone: tz
        )
        XCTAssertEqual(offDay.label, "Off 1 of 2")
    }

    func testCurrentAndNextShift() {
        let rotation = TestSupport.alcon()
        let during = TestSupport.date(2026, 8, 11, 2, 0, tz: tz) // inside Mon 18:00–06:30

        let current = RosterEngine.currentShift(at: during, rotation: rotation, timeZone: tz)
        XCTAssertEqual(current?.start, TestSupport.date(2026, 8, 10, 18, 0, tz: tz))

        let next = RosterEngine.nextShift(after: during, rotation: rotation, timeZone: tz)
        XCTAssertEqual(next?.start, TestSupport.date(2026, 8, 11, 18, 0, tz: tz)) // Tue night
    }
}
