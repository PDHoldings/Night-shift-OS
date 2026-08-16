import Foundation

/// A time-restricted-eating window aligned to the user's ShiftDay — not to
/// midnight. The eating window is expressed as an offset from the start of
/// the ShiftDay plus a duration; everything outside it is the fast.
public struct FastingWindow: Codable, Sendable, Equatable, Hashable {
    /// Minutes after the ShiftDay boundary at which eating opens.
    public var eatingStartOffsetMinutes: Int
    /// Length of the eating window in minutes (e.g. 480 for 16:8).
    public var eatingDurationMinutes: Int

    public init(eatingStartOffsetMinutes: Int, eatingDurationMinutes: Int) {
        precondition(eatingDurationMinutes > 0 && eatingDurationMinutes < 24 * 60, "eating window must be shorter than a day")
        self.eatingStartOffsetMinutes = eatingStartOffsetMinutes
        self.eatingDurationMinutes = eatingDurationMinutes
    }

    /// A 16:8 window opening at the ShiftDay boundary (eat during the first
    /// 8 hours of the user's day).
    public static let sixteenEight = FastingWindow(eatingStartOffsetMinutes: 0, eatingDurationMinutes: 8 * 60)
}

public enum FastingState: Equatable, Sendable {
    case eating(until: Date)
    case fasting(until: Date)
}

public enum FastingTimer {

    /// The eating interval for a given ShiftDay.
    public static func eatingInterval(for window: FastingWindow, on shiftDay: ShiftDay) -> DateInterval {
        let start = shiftDay.start.addingTimeInterval(TimeInterval(window.eatingStartOffsetMinutes) * 60)
        return DateInterval(start: start, duration: TimeInterval(window.eatingDurationMinutes) * 60)
    }

    /// Whether the user is eating or fasting at `timestamp`, and when the
    /// current state ends. `nextShiftDay` supplies the following day's window
    /// so a fast's end can be reported across the day boundary.
    public static func state(
        at timestamp: Date,
        window: FastingWindow,
        shiftDay: ShiftDay,
        nextShiftDay: ShiftDay? = nil
    ) -> FastingState {
        let eating = eatingInterval(for: window, on: shiftDay)
        if timestamp < eating.start {
            return .fasting(until: eating.start)
        }
        if timestamp < eating.end {
            return .eating(until: eating.end)
        }
        if let next = nextShiftDay {
            return .fasting(until: eatingInterval(for: window, on: next).start)
        }
        return .fasting(until: eating.start.addingTimeInterval(24 * 3600))
    }

    /// Elapsed fraction of the current fast (0...1), for the ring UI.
    public static func fastProgress(
        at timestamp: Date,
        window: FastingWindow,
        shiftDay: ShiftDay,
        nextShiftDay: ShiftDay?
    ) -> Double? {
        let eating = eatingInterval(for: window, on: shiftDay)
        guard timestamp >= eating.end, let next = nextShiftDay else { return nil }
        let nextEating = eatingInterval(for: window, on: next)
        let total = nextEating.start.timeIntervalSince(eating.end)
        guard total > 0 else { return nil }
        return min(1, max(0, timestamp.timeIntervalSince(eating.end) / total))
    }
}
