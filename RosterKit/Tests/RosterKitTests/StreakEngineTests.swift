import Foundation
import XCTest
@testable import RosterKit

final class StreakEngineTests: XCTestCase {
    let tz = TestSupport.chicago

    private func shiftDay(_ month: Int, _ day: Int) -> ShiftDay {
        RosterEngine.resolveShiftDay(
            for: TestSupport.date(2026, month, day, 20, 0, tz: tz),
            rotation: TestSupport.simpleNightRotation(),
            timeZone: tz
        )
    }

    func testConsecutiveShiftDaysExtendStreak() {
        let calendar = RosterEngine.calendar(in: tz)
        var streak = Streak(habitType: "logging")
        for d in 10...14 {
            streak = StreakEngine.recordAchievement(on: shiftDay(8, d), streak: streak, calendar: calendar)
        }
        XCTAssertEqual(streak.currentCount, 5)
        XCTAssertEqual(streak.bestCount, 5)
    }

    func testSameShiftDayIsIdempotent() {
        let calendar = RosterEngine.calendar(in: tz)
        var streak = Streak(habitType: "logging")
        streak = StreakEngine.recordAchievement(on: shiftDay(8, 10), streak: streak, calendar: calendar)
        streak = StreakEngine.recordAchievement(on: shiftDay(8, 10), streak: streak, calendar: calendar)
        XCTAssertEqual(streak.currentCount, 1)
    }

    func testGapResetsCurrentKeepsBest() {
        let calendar = RosterEngine.calendar(in: tz)
        var streak = Streak(habitType: "logging")
        for d in 10...12 {
            streak = StreakEngine.recordAchievement(on: shiftDay(8, d), streak: streak, calendar: calendar)
        }
        streak = StreakEngine.recordAchievement(on: shiftDay(8, 15), streak: streak, calendar: calendar) // gap: 13, 14 missed
        XCTAssertEqual(streak.currentCount, 1)
        XCTAssertEqual(streak.bestCount, 3)
    }

    func testMonthRolloverDoesNotBreakStreak() {
        let calendar = RosterEngine.calendar(in: tz)
        var streak = Streak(habitType: "logging")
        streak = StreakEngine.recordAchievement(on: shiftDay(8, 31), streak: streak, calendar: calendar)
        streak = StreakEngine.recordAchievement(on: shiftDay(9, 1), streak: streak, calendar: calendar)
        XCTAssertEqual(streak.currentCount, 2)
    }

    func testIsAlive() {
        let calendar = RosterEngine.calendar(in: tz)
        var streak = Streak(habitType: "logging")
        streak = StreakEngine.recordAchievement(on: shiftDay(8, 10), streak: streak, calendar: calendar)
        XCTAssertTrue(StreakEngine.isAlive(streak, asOf: shiftDay(8, 11), calendar: calendar))
        XCTAssertFalse(StreakEngine.isAlive(streak, asOf: shiftDay(8, 12), calendar: calendar))
    }

    func testComputeFromHistory() {
        let calendar = RosterEngine.calendar(in: tz)
        let history: [(date: CalendarDate, achieved: Bool)] = [
            (CalendarDate(year: 2026, month: 8, day: 10), true),
            (CalendarDate(year: 2026, month: 8, day: 11), true),
            (CalendarDate(year: 2026, month: 8, day: 12), false),
            (CalendarDate(year: 2026, month: 8, day: 13), true),
            (CalendarDate(year: 2026, month: 8, day: 14), true),
            (CalendarDate(year: 2026, month: 8, day: 15), true),
        ]
        let streak = StreakEngine.compute(habitType: "logging", history: history, calendar: calendar)
        XCTAssertEqual(streak.currentCount, 3)
        XCTAssertEqual(streak.bestCount, 3)
        XCTAssertEqual(streak.lastCalendarDate, CalendarDate(year: 2026, month: 8, day: 15))
    }
}
