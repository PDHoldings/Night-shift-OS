import Foundation

/// The user's personal day boundary — when *their* day begins.
///
/// This is the flagship concept of the product: every log, target, streak,
/// and summary aggregates to the ShiftDay this rule defines, never to a
/// calendar date at midnight.
public enum DayBoundaryRule: Codable, Sendable, Equatable, Hashable {
    /// The day begins at a fixed local clock time (minutes after midnight, 0..<1440).
    case fixedTime(minuteOfDay: Int)

    /// The day begins at an offset from the day's shift start (e.g. shift-start − 4h
    /// is `offsetMinutes: -240`). Days with no shift fall back to a fixed clock time.
    case shiftRelative(offsetMinutes: Int, offDayFallbackMinuteOfDay: Int)

    // Phase 3 adds `.wakeBased` driven by sleep logs / HealthKit.

    /// A sensible default until the user chooses: 15:00, mid-afternoon, which is
    /// "when I wake" for a typical night worker.
    public static let `default` = DayBoundaryRule.fixedTime(minuteOfDay: 15 * 60)
}
