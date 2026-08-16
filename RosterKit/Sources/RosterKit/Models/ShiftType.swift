import Foundation

/// The kind of shift occupying a cycle day.
public enum ShiftType: String, Codable, Sendable, CaseIterable, Hashable {
    case night
    case day
    case swing
    case off
    case oncall

    /// Whether this shift type counts as a working day.
    public var isWorking: Bool {
        switch self {
        case .off: return false
        case .night, .day, .swing, .oncall: return true
        }
    }

    /// Human-readable noun used in shift-day labels ("Night 2 of 4").
    public var labelNoun: String {
        switch self {
        case .night: return "Night"
        case .day: return "Day"
        case .swing: return "Swing"
        case .off: return "Off"
        case .oncall: return "On-call"
        }
    }
}
