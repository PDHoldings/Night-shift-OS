import Foundation

/// A habit streak counted in consecutive ShiftDays — never broken by a
/// calendar rollover, DST transition, or time-zone travel, because
/// adjacency is defined on cycle calendar dates, not wall-clock time.
public struct Streak: Codable, Sendable, Equatable, Hashable {
    public var habitType: String
    public var currentCount: Int
    public var bestCount: Int
    public var lastShiftDayID: String?
    /// Cycle calendar date of the last ShiftDay counted, for adjacency checks.
    public var lastCalendarDate: CalendarDate?

    public init(habitType: String, currentCount: Int = 0, bestCount: Int = 0, lastShiftDayID: String? = nil, lastCalendarDate: CalendarDate? = nil) {
        self.habitType = habitType
        self.currentCount = currentCount
        self.bestCount = bestCount
        self.lastShiftDayID = lastShiftDayID
        self.lastCalendarDate = lastCalendarDate
    }
}

public enum StreakEngine {

    /// Record that the habit was achieved on `shiftDay`, returning the updated streak.
    ///
    /// - Achieving on the ShiftDay immediately after the last counted one extends the streak.
    /// - Achieving again on the same ShiftDay is a no-op (idempotent).
    /// - A gap of one or more ShiftDays resets the current count to 1.
    public static func recordAchievement(on shiftDay: ShiftDay, streak: Streak, calendar: Calendar) -> Streak {
        var updated = streak
        if let last = streak.lastCalendarDate {
            if last == shiftDay.calendarDate {
                return streak // already counted this ShiftDay
            }
            let next = RosterEngine.addDays(1, to: last, calendar: calendar)
            if next == shiftDay.calendarDate {
                updated.currentCount += 1
            } else if shiftDay.calendarDate > last {
                updated.currentCount = 1
            } else {
                return streak // out-of-order backfill; ignore for v1
            }
        } else {
            updated.currentCount = 1
        }
        updated.bestCount = max(updated.bestCount, updated.currentCount)
        updated.lastShiftDayID = shiftDay.id
        updated.lastCalendarDate = shiftDay.calendarDate
        return updated
    }

    /// Whether the streak is still alive as of `shiftDay` (i.e. the last
    /// achievement was on this ShiftDay or the one before it).
    public static func isAlive(_ streak: Streak, asOf shiftDay: ShiftDay, calendar: Calendar) -> Bool {
        guard let last = streak.lastCalendarDate, streak.currentCount > 0 else { return false }
        if last == shiftDay.calendarDate { return true }
        return RosterEngine.addDays(1, to: last, calendar: calendar) == shiftDay.calendarDate
    }

    /// Recompute a streak from full history — (calendarDate, achieved) pairs
    /// in any order. Source of truth for repair/migration.
    public static func compute(habitType: String, history: [(date: CalendarDate, achieved: Bool)], calendar: Calendar) -> Streak {
        let achievedDates = history.filter(\.achieved).map(\.date).sorted()
        var streak = Streak(habitType: habitType)
        var previous: CalendarDate?
        var run = 0
        for date in achievedDates {
            if let prev = previous, date == prev { continue }
            if let prev = previous, RosterEngine.addDays(1, to: prev, calendar: calendar) == date {
                run += 1
            } else {
                run = 1
            }
            streak.bestCount = max(streak.bestCount, run)
            previous = date
        }
        streak.currentCount = run
        streak.lastCalendarDate = previous
        return streak
    }
}
