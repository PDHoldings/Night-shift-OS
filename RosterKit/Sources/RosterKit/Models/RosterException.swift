import Foundation

/// A one-off deviation from the rotation on a specific cycle day:
/// a swapped shift, overtime, or a call-off.
///
/// Exceptions are keyed to the *local calendar date* of the cycle day they
/// replace. Applying one regenerates downstream guidance from that point
/// forward; historical logs are unaffected because every log row pins its
/// `shiftDayID` at write time.
public struct RosterException: Codable, Sendable, Equatable, Hashable, Identifiable {
    public let id: UUID
    /// The cycle day (local calendar date) this exception applies to.
    public var date: CalendarDate
    /// The shift that replaces the template that day. `nil` means the day
    /// becomes an off day (call-off).
    public var replacement: ShiftOverride?
    public var note: String?

    public init(id: UUID = UUID(), date: CalendarDate, replacement: ShiftOverride?, note: String? = nil) {
        self.id = id
        self.date = date
        self.replacement = replacement
        self.note = note
    }
}

/// The shape of a replacement shift inside a `RosterException`.
public struct ShiftOverride: Codable, Sendable, Equatable, Hashable {
    public var label: String
    public var type: ShiftType
    public var startMinuteOfDay: Int
    public var durationMinutes: Int

    public init(label: String, type: ShiftType, startMinuteOfDay: Int, durationMinutes: Int) {
        precondition((0..<1440).contains(startMinuteOfDay), "startMinuteOfDay must be within a single day")
        precondition(durationMinutes > 0 && durationMinutes <= 1440, "durationMinutes must be in 1...1440")
        self.label = label
        self.type = type
        self.startMinuteOfDay = startMinuteOfDay
        self.durationMinutes = durationMinutes
    }
}
