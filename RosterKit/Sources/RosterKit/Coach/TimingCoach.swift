import Foundation

/// User-tunable knobs for the rules-based circadian timing coach.
public struct CoachPreferences: Codable, Sendable, Equatable {
    /// Minimum hours between the last caffeine dose and intended sleep.
    public var caffeineGapHours: Double
    public var commuteMinutes: Int
    public var windDownMinutes: Int
    public var targetSleepHours: Double

    public init(caffeineGapHours: Double = 8, commuteMinutes: Int = 30, windDownMinutes: Int = 30, targetSleepHours: Double = 7) {
        self.caffeineGapHours = caffeineGapHours
        self.commuteMinutes = commuteMinutes
        self.windDownMinutes = windDownMinutes
        self.targetSleepHours = targetSleepHours
    }
}

/// One actionable cue on the shift timeline.
public struct CoachCue: Codable, Sendable, Equatable, Identifiable, Hashable {
    public enum Kind: String, Codable, Sendable {
        case mainMeal
        case snack
        case avoidLargeMeal
        case caffeineCutoff
        case brightLight
        case dimLight
        case windDown
        case sleepStart
    }

    public let kind: Kind
    public let time: Date
    public let message: String

    public var id: String { "\(kind.rawValue)@\(time.timeIntervalSinceReferenceDate)" }

    public init(kind: Kind, time: Date, message: String) {
        self.kind = kind
        self.time = time
        self.message = message
    }
}

/// The coach's plan around one shift: an ordered timeline of cues plus the
/// suggested anchor-sleep window. Rendered as a horizontal shift timeline,
/// not a midnight-anchored day.
public struct CoachPlan: Codable, Sendable, Equatable {
    public let shift: ResolvedShift
    public let cues: [CoachCue]
    public let sleepWindow: DateInterval

    public init(shift: ResolvedShift, cues: [CoachCue], sleepWindow: DateInterval) {
        self.shift = shift
        self.cues = cues
        self.sleepWindow = sleepWindow
    }

    public var caffeineCutoff: Date? {
        cues.first { $0.kind == .caffeineCutoff }?.time
    }
}

/// Deterministic, rules-based v1 of the circadian timing coach.
/// General-wellness guidance only — no diagnosis or treatment claims.
public enum TimingCoach {

    /// Build the plan for one upcoming (or in-progress) shift.
    public static func plan(for shift: ResolvedShift, preferences: CoachPreferences = CoachPreferences()) -> CoachPlan {
        let commute = TimeInterval(preferences.commuteMinutes) * 60
        let windDown = TimeInterval(preferences.windDownMinutes) * 60
        let shiftLength = shift.end.timeIntervalSince(shift.start)

        // Sleep placement: a shift ending in the night-worker pattern
        // (overnight or into the early morning) means main sleep comes after
        // the shift; a classic day shift means sleep precedes the next one.
        let sleepStart: Date
        if endsOvernight(shift) {
            sleepStart = shift.end.addingTimeInterval(commute + windDown)
        } else {
            // Day/swing pattern: in bed ~3h after the shift ends (commute,
            // dinner, wind-down). A Phase 1 simplification, refined when real
            // sleep data arrives in Phase 3.
            sleepStart = shift.end.addingTimeInterval(3 * 3600)
        }
        let sleepWindow = DateInterval(start: sleepStart, duration: preferences.targetSleepHours * 3600)

        var cues: [CoachCue] = []

        cues.append(CoachCue(
            kind: .mainMeal,
            time: shift.start.addingTimeInterval(-90 * 60),
            message: "Main meal now — eat your biggest meal before the shift, not during it."
        ))
        cues.append(CoachCue(
            kind: .brightLight,
            time: shift.start,
            message: "Seek bright light for the first half of your shift to stay alert."
        ))
        cues.append(CoachCue(
            kind: .snack,
            time: shift.start.addingTimeInterval(shiftLength * 0.4),
            message: "Light protein snack — keep it small to avoid the mid-shift slump."
        ))
        cues.append(CoachCue(
            kind: .avoidLargeMeal,
            time: shift.start.addingTimeInterval(shiftLength * 2 / 3),
            message: "Final stretch — skip large meals from here; digestion fights your body clock."
        ))
        cues.append(CoachCue(
            kind: .caffeineCutoff,
            time: sleepStart.addingTimeInterval(-preferences.caffeineGapHours * 3600),
            message: "Caffeine cutoff — last dose now so it's clear of your sleep window."
        ))
        if endsOvernight(shift) {
            cues.append(CoachCue(
                kind: .dimLight,
                time: shift.end,
                message: "Dim light from here — sunglasses on the commute home protect your sleep."
            ))
        }
        cues.append(CoachCue(
            kind: .windDown,
            time: sleepStart.addingTimeInterval(-windDown),
            message: "Wind down — screens off, room dark and cool."
        ))
        cues.append(CoachCue(
            kind: .sleepStart,
            time: sleepStart,
            message: "Anchor sleep window starts — protect it like a shift."
        ))

        return CoachPlan(
            shift: shift,
            cues: cues.sorted { $0.time < $1.time },
            sleepWindow: sleepWindow
        )
    }

    /// Whether the shift ends in the "sleep afterwards" pattern: it crosses
    /// midnight or ends in the early morning (before 10:00 local is treated
    /// as an overnight pattern by callers that pass local hour context).
    static func endsOvernight(_ shift: ResolvedShift) -> Bool {
        shift.type == .night || shift.end.timeIntervalSince(shift.start) >= 16 * 3600
    }
}
