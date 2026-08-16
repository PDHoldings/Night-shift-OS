import Foundation

/// Pure, deterministic roster math. No state, no I/O, no UI.
///
/// The single most important function in the product is
/// `resolveShiftDay(for:rotation:exceptions:timeZone:)`: given any instant,
/// it returns the ShiftDay that instant belongs to on the user's roster.
/// Midnight is never a boundary unless the user says so.
public enum RosterEngine {

    // MARK: - Public API

    /// Resolve the ShiftDay containing `timestamp`.
    ///
    /// Deterministic across DST transitions, time-zone travel, and
    /// mid-rotation edits (exceptions are consulted at resolution time;
    /// already-written logs keep the `shiftDayID` they resolved to).
    public static func resolveShiftDay(
        for timestamp: Date,
        rotation: Rotation,
        exceptions: [RosterException] = [],
        timeZone: TimeZone
    ) -> ShiftDay {
        let calendar = self.calendar(in: timeZone)
        guard let localDate = CalendarDate(from: timestamp, in: timeZone) else {
            preconditionFailure("Could not decompose timestamp into a calendar date")
        }

        // The boundary of cycle day D can land up to ±1 day away from D itself
        // (night shifts, shift-relative offsets), so scan a window of cycle
        // days around the timestamp and find the one whose
        // [boundary(D), boundary(D+1)) interval contains it.
        for offset in -3...3 {
            let dayDate = addDays(offset, to: localDate, calendar: calendar)
            let dayStart = boundary(onDay: dayDate, rotation: rotation, exceptions: exceptions, calendar: calendar)
            let nextDate = addDays(1, to: dayDate, calendar: calendar)
            let dayEnd = boundary(onDay: nextDate, rotation: rotation, exceptions: exceptions, calendar: calendar)
            guard dayStart < dayEnd else { continue } // degenerate config; skip empty day
            if timestamp >= dayStart && timestamp < dayEnd {
                return makeShiftDay(
                    date: dayDate,
                    start: dayStart,
                    end: dayEnd,
                    rotation: rotation,
                    exceptions: exceptions,
                    calendar: calendar
                )
            }
        }

        // Unreachable for sane configurations; fall back to the local date's day.
        let dayStart = boundary(onDay: localDate, rotation: rotation, exceptions: exceptions, calendar: calendar)
        let dayEnd = boundary(onDay: addDays(1, to: localDate, calendar: calendar), rotation: rotation, exceptions: exceptions, calendar: calendar)
        return makeShiftDay(
            date: localDate,
            start: dayStart,
            end: max(dayEnd, dayStart.addingTimeInterval(60)),
            rotation: rotation,
            exceptions: exceptions,
            calendar: calendar
        )
    }

    /// Materialize consecutive ShiftDays starting with the one containing `date`.
    /// Used to cache the roster forward (e.g. 60 days) and to render the
    /// roster calendar 8 weeks out.
    public static func shiftDays(
        startingAt date: Date,
        count: Int,
        rotation: Rotation,
        exceptions: [RosterException] = [],
        timeZone: TimeZone
    ) -> [ShiftDay] {
        let calendar = self.calendar(in: timeZone)
        let first = resolveShiftDay(for: date, rotation: rotation, exceptions: exceptions, timeZone: timeZone)
        var result: [ShiftDay] = [first]
        var currentDate = first.calendarDate
        for _ in 1..<max(count, 1) {
            let nextDate = addDays(1, to: currentDate, calendar: calendar)
            let start = boundary(onDay: nextDate, rotation: rotation, exceptions: exceptions, calendar: calendar)
            let end = boundary(onDay: addDays(2, to: currentDate, calendar: calendar), rotation: rotation, exceptions: exceptions, calendar: calendar)
            result.append(makeShiftDay(
                date: nextDate,
                start: start,
                end: end,
                rotation: rotation,
                exceptions: exceptions,
                calendar: calendar
            ))
            currentDate = nextDate
        }
        return result
    }

    /// The next working shift starting at or after `timestamp`. Drives the
    /// timing coach and notification scheduling.
    public static func nextShift(
        after timestamp: Date,
        rotation: Rotation,
        exceptions: [RosterException] = [],
        timeZone: TimeZone,
        searchLimitDays: Int = 60
    ) -> ResolvedShift? {
        let calendar = self.calendar(in: timeZone)
        guard var date = CalendarDate(from: timestamp, in: timeZone) else { return nil }
        // A night shift that started yesterday may still be the "next" relevant
        // shift if it hasn't started yet relative to `timestamp`; start one day back.
        date = addDays(-1, to: date, calendar: calendar)
        for _ in 0...searchLimitDays {
            if let shift = effectiveShift(onDay: date, rotation: rotation, exceptions: exceptions, calendar: calendar),
               shift.start >= timestamp {
                return shift
            }
            date = addDays(1, to: date, calendar: calendar)
        }
        return nil
    }

    /// The working shift in progress at `timestamp`, if any.
    public static func currentShift(
        at timestamp: Date,
        rotation: Rotation,
        exceptions: [RosterException] = [],
        timeZone: TimeZone
    ) -> ResolvedShift? {
        let calendar = self.calendar(in: timeZone)
        guard let localDate = CalendarDate(from: timestamp, in: timeZone) else { return nil }
        for offset in -1...1 {
            let date = addDays(offset, to: localDate, calendar: calendar)
            if let shift = effectiveShift(onDay: date, rotation: rotation, exceptions: exceptions, calendar: calendar),
               shift.start <= timestamp, timestamp < shift.end {
                return shift
            }
        }
        return nil
    }

    /// Days between the rotation anchor and `date` (may be negative), un-modded.
    public static func dayNumber(of date: CalendarDate, in rotation: Rotation, calendar: Calendar) -> Int {
        let anchorNoon = noon(on: rotation.anchorDate, calendar: calendar)
        let dateNoon = noon(on: date, calendar: calendar)
        return calendar.dateComponents([.day], from: anchorNoon, to: dateNoon).day ?? 0
    }

    /// Cycle day index (0..<cycleLengthDays) for a calendar date.
    public static func dayIndexInCycle(of date: CalendarDate, in rotation: Rotation, calendar: Calendar) -> Int {
        floorMod(dayNumber(of: date, in: rotation, calendar: calendar), rotation.cycleLengthDays)
    }

    /// The effective (exception-aware) shift on a cycle day, with resolved instants.
    public static func effectiveShift(
        onDay date: CalendarDate,
        rotation: Rotation,
        exceptions: [RosterException],
        calendar: Calendar
    ) -> ResolvedShift? {
        if let exception = exceptions.first(where: { $0.date == date }) {
            guard let replacement = exception.replacement else { return nil } // call-off
            let start = instant(atMinuteOfDay: replacement.startMinuteOfDay, onDay: date, calendar: calendar)
            return ResolvedShift(
                label: replacement.label,
                type: replacement.type,
                start: start,
                end: start.addingTimeInterval(TimeInterval(replacement.durationMinutes) * 60)
            )
        }
        let index = dayIndexInCycle(of: date, in: rotation, calendar: calendar)
        guard let template = rotation.template(forDayIndex: index), template.type.isWorking else { return nil }
        let start = instant(atMinuteOfDay: template.startMinuteOfDay, onDay: date, calendar: calendar)
        return ResolvedShift(
            label: template.label,
            type: template.type,
            start: start,
            end: start.addingTimeInterval(TimeInterval(template.durationMinutes) * 60)
        )
    }

    /// The instant the user's day begins on a given cycle day.
    public static func boundary(
        onDay date: CalendarDate,
        rotation: Rotation,
        exceptions: [RosterException],
        calendar: Calendar
    ) -> Date {
        switch rotation.dayBoundaryRule {
        case .fixedTime(let minuteOfDay):
            return instant(atMinuteOfDay: minuteOfDay, onDay: date, calendar: calendar)
        case .shiftRelative(let offsetMinutes, let fallbackMinuteOfDay):
            if let shift = effectiveShift(onDay: date, rotation: rotation, exceptions: exceptions, calendar: calendar) {
                return shift.start.addingTimeInterval(TimeInterval(offsetMinutes) * 60)
            }
            return instant(atMinuteOfDay: fallbackMinuteOfDay, onDay: date, calendar: calendar)
        }
    }

    // MARK: - ShiftDay construction

    private static func makeShiftDay(
        date: CalendarDate,
        start: Date,
        end: Date,
        rotation: Rotation,
        exceptions: [RosterException],
        calendar: Calendar
    ) -> ShiftDay {
        let shift = effectiveShift(onDay: date, rotation: rotation, exceptions: exceptions, calendar: calendar)
        let type = shift?.type ?? .off
        return ShiftDay(
            rotationID: rotation.id,
            calendarDate: date,
            dayIndexInCycle: dayIndexInCycle(of: date, in: rotation, calendar: calendar),
            start: start,
            end: end,
            shiftType: type,
            label: label(forDay: date, type: type, rotation: rotation, exceptions: exceptions, calendar: calendar),
            shift: shift
        )
    }

    /// Roster-aware label: position within the current run of same-type days,
    /// e.g. "Night 2 of 4" or "Off 1 of 3".
    static func label(
        forDay date: CalendarDate,
        type: ShiftType,
        rotation: Rotation,
        exceptions: [RosterException],
        calendar: Calendar,
        walkLimit: Int = 45
    ) -> String {
        func dayType(_ d: CalendarDate) -> ShiftType {
            effectiveShift(onDay: d, rotation: rotation, exceptions: exceptions, calendar: calendar)?.type ?? .off
        }
        var before = 0
        var cursor = addDays(-1, to: date, calendar: calendar)
        while before < walkLimit, dayType(cursor) == type {
            before += 1
            cursor = addDays(-1, to: cursor, calendar: calendar)
        }
        var after = 0
        cursor = addDays(1, to: date, calendar: calendar)
        while after < walkLimit, dayType(cursor) == type {
            after += 1
            cursor = addDays(1, to: cursor, calendar: calendar)
        }
        let position = before + 1
        let total = before + after + 1
        if total >= walkLimit {
            // A permanent schedule (e.g. fixed nights, every day) has no
            // meaningful run boundaries; use the bare noun.
            return type.labelNoun
        }
        return "\(type.labelNoun) \(position) of \(total)"
    }

    // MARK: - Calendar/date helpers

    public static func calendar(in timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    /// The instant at `minuteOfDay` on a local calendar day. DST-safe:
    /// Foundation adjusts nonexistent times (spring-forward gap) forward and
    /// resolves ambiguous times (fall-back overlap) deterministically.
    static func instant(atMinuteOfDay minuteOfDay: Int, onDay date: CalendarDate, calendar: Calendar) -> Date {
        var comps = DateComponents()
        comps.year = date.year
        comps.month = date.month
        comps.day = date.day
        comps.hour = minuteOfDay / 60
        comps.minute = minuteOfDay % 60
        guard let instant = calendar.date(from: comps) else {
            preconditionFailure("Could not construct instant for \(date) at minute \(minuteOfDay)")
        }
        return instant
    }

    /// Noon on a local calendar day — always exists (DST transitions occur at
    /// night in every current zone), used for stable day arithmetic.
    static func noon(on date: CalendarDate, calendar: Calendar) -> Date {
        instant(atMinuteOfDay: 12 * 60, onDay: date, calendar: calendar)
    }

    static func addDays(_ days: Int, to date: CalendarDate, calendar: Calendar) -> CalendarDate {
        guard let shifted = calendar.date(byAdding: .day, value: days, to: noon(on: date, calendar: calendar)) else {
            preconditionFailure("Date arithmetic failed for \(date) + \(days)d")
        }
        let comps = calendar.dateComponents([.year, .month, .day], from: shifted)
        return CalendarDate(year: comps.year!, month: comps.month!, day: comps.day!)
    }

    static func floorMod(_ a: Int, _ n: Int) -> Int {
        let r = a % n
        return r >= 0 ? r : r + n
    }
}
