import Foundation
import XCTest
@testable import RosterKit

final class RotationPresetTests: XCTestCase {
    let tz = TestSupport.chicago

    // Doc AC: the founder's Alcon pattern renders correctly 8 weeks forward.
    func testAlconPatternEightWeeks() {
        let rotation = TestSupport.alcon() // anchor Mon 2026-08-10
        let days = RosterEngine.shiftDays(
            startingAt: TestSupport.date(2026, 8, 10, 16, 0, tz: tz),
            count: 56,
            rotation: rotation,
            timeZone: tz
        )

        XCTAssertEqual(days.count, 56)
        // 7 working nights per 14-day cycle → 28 nights in 8 weeks.
        XCTAssertEqual(days.filter { $0.shiftType == .night }.count, 28)

        // A-week: Mon Tue Fri Sat Sun work; Wed Thu off.
        let expectedWorkIndexes: Set<Int> = [0, 1, 4, 5, 6, 9, 10]
        for day in days {
            let shouldWork = expectedWorkIndexes.contains(day.dayIndexInCycle)
            XCTAssertEqual(day.shiftType == .night, shouldWork,
                           "cycle day \(day.dayIndexInCycle) on \(day.calendarDate)")
        }

        // Shifts run 18:00–06:30.
        let monday = days[0]
        XCTAssertEqual(monday.shift?.start, TestSupport.date(2026, 8, 10, 18, 0, tz: tz))
        XCTAssertEqual(monday.shift?.end, TestSupport.date(2026, 8, 11, 6, 30, tz: tz))
    }

    func testAlconBWeekWedThu() {
        let rotation = TestSupport.alcon()
        // B-week Wed = Aug 19 (cycle index 9), Thu = Aug 20 (index 10).
        let wed = RosterEngine.resolveShiftDay(for: TestSupport.date(2026, 8, 19, 19, 0, tz: tz), rotation: rotation, timeZone: tz)
        let thu = RosterEngine.resolveShiftDay(for: TestSupport.date(2026, 8, 20, 19, 0, tz: tz), rotation: rotation, timeZone: tz)
        XCTAssertEqual(wed.shiftType, .night)
        XCTAssertEqual(wed.dayIndexInCycle, 9)
        XCTAssertEqual(thu.shiftType, .night)
        XCTAssertEqual(thu.dayIndexInCycle, 10)
        XCTAssertEqual(wed.label, "Night 1 of 2")
        XCTAssertEqual(thu.label, "Night 2 of 2")
    }

    func testPatternRepeatsAcrossCycles() {
        let rotation = TestSupport.alcon()
        let calendar = RosterEngine.calendar(in: tz)
        // Aug 10 and Aug 24 are both cycle day 0.
        XCTAssertEqual(RosterEngine.dayIndexInCycle(of: CalendarDate(year: 2026, month: 8, day: 24), in: rotation, calendar: calendar), 0)
        // Dates before the anchor wrap correctly (floor mod).
        XCTAssertEqual(RosterEngine.dayIndexInCycle(of: CalendarDate(year: 2026, month: 8, day: 9), in: rotation, calendar: calendar), 13)
    }

    func testDupontStructure() {
        let rotation = RotationPresets.dupont(anchor: CalendarDate(year: 2026, month: 8, day: 10))
        XCTAssertEqual(rotation.cycleLengthDays, 28)
        XCTAssertEqual(rotation.templates.count, 14) // 4N + 3D + 3N + 4D
        XCTAssertEqual(rotation.templates.filter { $0.type == .night }.count, 7)
        XCTAssertEqual(rotation.templates.filter { $0.type == .day }.count, 7)
    }

    func testTwentyFourFortyEight() {
        let rotation = RotationPresets.twentyFourFortyEight(anchor: CalendarDate(year: 2026, month: 8, day: 10))
        let days = RosterEngine.shiftDays(
            startingAt: TestSupport.date(2026, 8, 10, 16, 0, tz: tz),
            count: 6,
            rotation: rotation,
            timeZone: tz
        )
        XCTAssertEqual(days.map(\.shiftType), [.day, .off, .off, .day, .off, .off])
        let shift = days[0].shift!
        XCTAssertEqual(shift.end.timeIntervalSince(shift.start), 24 * 3600)
    }

    func testPanamaTwoTwoThree() {
        let rotation = RotationPresets.panama223(anchor: CalendarDate(year: 2026, month: 8, day: 10))
        XCTAssertEqual(rotation.cycleLengthDays, 14)
        let days = RosterEngine.shiftDays(
            startingAt: TestSupport.date(2026, 8, 10, 16, 0, tz: tz),
            count: 14,
            rotation: rotation,
            timeZone: tz
        )
        let pattern = days.map { $0.shiftType == .night }
        XCTAssertEqual(pattern, [true, true, false, false, true, true, true,
                                 false, false, true, true, false, false, false])
    }

    func testFixedNightsLongRunLabel() {
        // A 1-day cycle (night every day) has no meaningful run boundaries;
        // the label degrades gracefully to the bare noun.
        let rotation = TestSupport.simpleNightRotation()
        let day = RosterEngine.resolveShiftDay(
            for: TestSupport.date(2026, 8, 16, 20, 0, tz: tz),
            rotation: rotation,
            timeZone: tz
        )
        XCTAssertEqual(day.label, "Night")
    }
}
