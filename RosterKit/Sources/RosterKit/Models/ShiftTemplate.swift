import Foundation

/// A shift occupying one day of a rotation cycle.
///
/// Times are stored as a start minute-of-day plus a duration in elapsed
/// minutes — never as two clock times — so shifts that cross midnight
/// (or a DST transition) are unambiguous.
public struct ShiftTemplate: Codable, Sendable, Equatable, Hashable, Identifiable {
    public let id: UUID
    public var dayIndexInCycle: Int
    public var label: String
    public var type: ShiftType
    /// Minutes after local midnight of the cycle day at which the shift starts (0..<1440).
    public var startMinuteOfDay: Int
    /// Elapsed duration of the shift in minutes. May carry the shift past midnight.
    public var durationMinutes: Int

    public init(
        id: UUID = UUID(),
        dayIndexInCycle: Int,
        label: String,
        type: ShiftType,
        startMinuteOfDay: Int,
        durationMinutes: Int
    ) {
        precondition((0..<1440).contains(startMinuteOfDay), "startMinuteOfDay must be within a single day")
        precondition(durationMinutes > 0 && durationMinutes <= 1440, "durationMinutes must be in 1...1440")
        self.id = id
        self.dayIndexInCycle = dayIndexInCycle
        self.label = label
        self.type = type
        self.startMinuteOfDay = startMinuteOfDay
        self.durationMinutes = durationMinutes
    }
}

/// A shift's concrete occurrence on a specific calendar day, with resolved instants.
public struct ResolvedShift: Codable, Sendable, Equatable, Hashable {
    public let label: String
    public let type: ShiftType
    public let start: Date
    public let end: Date

    public init(label: String, type: ShiftType, start: Date, end: Date) {
        self.label = label
        self.type = type
        self.start = start
        self.end = end
    }

    public var interval: DateInterval { DateInterval(start: start, end: end) }
}
