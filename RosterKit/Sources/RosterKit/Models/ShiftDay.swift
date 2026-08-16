import Foundation

/// The atomic unit of the app: one of the user's days, bounded by their
/// personal day boundary rather than midnight.
///
/// Every log, target, streak, and summary aggregates to a ShiftDay. The `id`
/// is stable and deterministic (rotation + cycle calendar date) so log rows
/// can pin to it at write time and never be orphaned by later roster edits.
public struct ShiftDay: Codable, Sendable, Equatable, Hashable, Identifiable {
    /// Stable identifier: `<rotationID>#<yyyy-mm-dd>` of the cycle day.
    public let id: String
    public let rotationID: UUID
    /// The local calendar date of the cycle day this ShiftDay belongs to.
    public let calendarDate: CalendarDate
    public let dayIndexInCycle: Int
    /// The instant the user's day begins (their personal day boundary).
    public let start: Date
    /// The instant the next ShiftDay begins.
    public let end: Date
    public let shiftType: ShiftType
    /// Roster-aware label, e.g. "Night 2 of 4" or "Off 1 of 3".
    public let label: String
    /// The resolved shift occurring on this ShiftDay, if it is a working day.
    public let shift: ResolvedShift?

    public init(
        rotationID: UUID,
        calendarDate: CalendarDate,
        dayIndexInCycle: Int,
        start: Date,
        end: Date,
        shiftType: ShiftType,
        label: String,
        shift: ResolvedShift?
    ) {
        self.id = "\(rotationID.uuidString)#\(calendarDate)"
        self.rotationID = rotationID
        self.calendarDate = calendarDate
        self.dayIndexInCycle = dayIndexInCycle
        self.start = start
        self.end = end
        self.shiftType = shiftType
        self.label = label
        self.shift = shift
    }

    public var interval: DateInterval { DateInterval(start: start, end: end) }

    public func contains(_ timestamp: Date) -> Bool {
        timestamp >= start && timestamp < end
    }
}
