import Foundation

/// A repeating pattern of shifts over an N-day cycle, anchored to a calendar date.
///
/// The anchor date is a *local calendar date* (year/month/day, no time) that is
/// defined to be cycle day 0. Storing it as components rather than a `Date`
/// keeps the cycle mapping stable across time zones and DST.
public struct Rotation: Codable, Sendable, Equatable, Hashable, Identifiable {
    public let id: UUID
    public var name: String
    public var cycleLengthDays: Int
    /// Local calendar date (year, month, day) that is cycle day 0.
    public var anchorDate: CalendarDate
    public var dayBoundaryRule: DayBoundaryRule
    /// Shifts keyed by day index in the cycle. Cycle days with no template are off days.
    public var templates: [ShiftTemplate]

    public init(
        id: UUID = UUID(),
        name: String,
        cycleLengthDays: Int,
        anchorDate: CalendarDate,
        dayBoundaryRule: DayBoundaryRule = .default,
        templates: [ShiftTemplate]
    ) {
        precondition(cycleLengthDays >= 1, "cycleLengthDays must be >= 1")
        self.id = id
        self.name = name
        self.cycleLengthDays = cycleLengthDays
        self.anchorDate = anchorDate
        self.dayBoundaryRule = dayBoundaryRule
        self.templates = templates
    }

    /// The template for a given cycle day index, or nil for an off day.
    public func template(forDayIndex index: Int) -> ShiftTemplate? {
        templates.first { $0.dayIndexInCycle == index }
    }
}

/// A time-zone-independent calendar date (year, month, day).
public struct CalendarDate: Codable, Sendable, Equatable, Hashable, Comparable, CustomStringConvertible {
    public var year: Int
    public var month: Int
    public var day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    public init?(from date: Date, in timeZone: TimeZone) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        guard let y = comps.year, let m = comps.month, let d = comps.day else { return nil }
        self.init(year: y, month: m, day: d)
    }

    public var description: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    public static func < (lhs: CalendarDate, rhs: CalendarDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}
