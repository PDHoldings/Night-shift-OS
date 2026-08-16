import Foundation
import XCTest
@testable import RosterKit

enum TestSupport {
    static let chicago = TimeZone(identifier: "America/Chicago")!
    static let tokyo = TimeZone(identifier: "Asia/Tokyo")!
    static let london = TimeZone(identifier: "Europe/London")!

    /// Build an instant from local wall-clock components in a zone.
    static func date(
        _ year: Int, _ month: Int, _ day: Int,
        _ hour: Int = 0, _ minute: Int = 0, _ second: Int = 0,
        tz: TimeZone
    ) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tz
        let comps = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second)
        guard let date = calendar.date(from: comps) else {
            fatalError("Bad test date \(year)-\(month)-\(day) \(hour):\(minute)")
        }
        return date
    }

    /// A simple fixed-nights rotation: nights every day, 18:00 + 12.5h,
    /// with a fixed 15:00 personal day boundary. Anchor 2026-08-10 (Monday).
    static func simpleNightRotation(boundary: DayBoundaryRule = .fixedTime(minuteOfDay: 15 * 60)) -> Rotation {
        let template = ShiftTemplate(
            dayIndexInCycle: 0,
            label: "Night",
            type: .night,
            startMinuteOfDay: 18 * 60,
            durationMinutes: 750
        )
        return Rotation(
            name: "Test Nights",
            cycleLengthDays: 1,
            anchorDate: CalendarDate(year: 2026, month: 8, day: 10),
            dayBoundaryRule: boundary,
            templates: [template]
        )
    }

    static func alcon() -> Rotation {
        RotationPresets.alconAB(anchorMonday: CalendarDate(year: 2026, month: 8, day: 10))
    }
}
