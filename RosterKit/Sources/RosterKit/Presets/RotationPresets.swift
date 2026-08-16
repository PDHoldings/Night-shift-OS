import Foundation

/// Factory for the rotation presets offered in the rotation builder.
///
/// Every preset takes an anchor date (cycle day 0). Times and patterns are
/// starting points the user refines in the builder.
public enum RotationPresets {

    /// Fixed nights, 5 on / 2 off, 23:00–07:00. Anchor = first night of the work block.
    public static func fixedNights(anchor: CalendarDate) -> Rotation {
        let nights = (0..<5).map { day in
            ShiftTemplate(dayIndexInCycle: day, label: "Night", type: .night, startMinuteOfDay: 23 * 60, durationMinutes: 8 * 60)
        }
        return Rotation(name: "Fixed Nights", cycleLengthDays: 7, anchorDate: anchor, templates: nights)
    }

    /// 2-2-3 "Panama": 14-day cycle of 12-hour nights — 2 on, 2 off, 3 on,
    /// 2 off, 2 on, 3 off. Anchor = first working day of the cycle.
    public static func panama223(anchor: CalendarDate, nightShift: Bool = true) -> Rotation {
        let workingDays = [0, 1, 4, 5, 6, 9, 10]
        let startMinute = nightShift ? 18 * 60 : 6 * 60
        let type: ShiftType = nightShift ? .night : .day
        let templates = workingDays.map { day in
            ShiftTemplate(dayIndexInCycle: day, label: type.labelNoun, type: type, startMinuteOfDay: startMinute, durationMinutes: 12 * 60)
        }
        return Rotation(name: "2-2-3 (Panama)", cycleLengthDays: 14, anchorDate: anchor, templates: templates)
    }

    /// 4 on / 4 off, 12-hour nights. Anchor = first night of the on-block.
    public static func fourOnFourOff(anchor: CalendarDate) -> Rotation {
        let templates = (0..<4).map { day in
            ShiftTemplate(dayIndexInCycle: day, label: "Night", type: .night, startMinuteOfDay: 18 * 60, durationMinutes: 12 * 60)
        }
        return Rotation(name: "4 on 4 off", cycleLengthDays: 8, anchorDate: anchor, templates: templates)
    }

    /// DuPont schedule: 28-day cycle of 12-hour shifts —
    /// 4 nights, 3 off, 3 days, 1 off, 3 nights, 3 off, 4 days, 7 off.
    /// (The classic DuPont pattern is a 4-week cycle; the architecture doc's
    /// "21-day" mention is corrected here to the standard 28.)
    public static func dupont(anchor: CalendarDate) -> Rotation {
        var templates: [ShiftTemplate] = []
        func add(_ range: Range<Int>, _ type: ShiftType) {
            let startMinute = type == .night ? 18 * 60 : 6 * 60
            for day in range {
                templates.append(ShiftTemplate(dayIndexInCycle: day, label: type.labelNoun, type: type, startMinuteOfDay: startMinute, durationMinutes: 12 * 60))
            }
        }
        add(0..<4, .night)   // 4 nights
        // 3 off (4..<7)
        add(7..<10, .day)    // 3 days
        // 1 off (10)
        add(11..<14, .night) // 3 nights
        // 3 off (14..<17)
        add(17..<21, .day)   // 4 days
        // 7 off (21..<28)
        return Rotation(name: "DuPont", cycleLengthDays: 28, anchorDate: anchor, templates: templates)
    }

    /// Firefighter 24/48: 3-day cycle, one 24-hour shift starting 08:00, two days off.
    public static func twentyFourFortyEight(anchor: CalendarDate) -> Rotation {
        let shift = ShiftTemplate(dayIndexInCycle: 0, label: "24-hour", type: .day, startMinuteOfDay: 8 * 60, durationMinutes: 24 * 60)
        return Rotation(name: "24/48", cycleLengthDays: 3, anchorDate: anchor, templates: [shift])
    }

    /// The founder's Alcon A/B-week pattern: 14-day cycle of 18:00–06:30 nights.
    /// A-week: Mon, Tue, Fri, Sat, Sun. B-week: Wed, Thu.
    /// Anchor must be the A-week Monday.
    public static func alconAB(anchorMonday: CalendarDate) -> Rotation {
        let workingDays = [0, 1, 4, 5, 6, 9, 10] // A: Mon Tue Fri Sat Sun; B: Wed Thu
        let templates = workingDays.map { day in
            ShiftTemplate(
                dayIndexInCycle: day,
                label: "Night",
                type: .night,
                startMinuteOfDay: 18 * 60,
                durationMinutes: 12 * 60 + 30 // 18:00–06:30
            )
        }
        return Rotation(name: "Alcon A/B", cycleLengthDays: 14, anchorDate: anchorMonday, templates: templates)
    }
}
