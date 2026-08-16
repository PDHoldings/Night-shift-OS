import Foundation
import SwiftData
import RosterKit

// SwiftData records. Domain math lives in RosterKit; these classes are
// storage + conversion only. Every log row denormalizes `shiftDayID`,
// resolved at write time — the §7.2 invariant that keeps history stable
// across roster edits.

@Model
final class RotationRecord {
    @Attribute(.unique) var id: UUID
    var name: String
    var cycleLengthDays: Int
    var anchorYear: Int
    var anchorMonth: Int
    var anchorDay: Int
    /// Encoded `DayBoundaryRule` (JSON) — small, versioned enum.
    var dayBoundaryRuleData: Data
    var isActive: Bool
    @Relationship(deleteRule: .cascade) var templates: [ShiftTemplateRecord]
    @Relationship(deleteRule: .cascade) var exceptions: [RosterExceptionRecord]

    init(rotation: Rotation, isActive: Bool = true) {
        self.id = rotation.id
        self.name = rotation.name
        self.cycleLengthDays = rotation.cycleLengthDays
        self.anchorYear = rotation.anchorDate.year
        self.anchorMonth = rotation.anchorDate.month
        self.anchorDay = rotation.anchorDate.day
        self.dayBoundaryRuleData = (try? JSONEncoder().encode(rotation.dayBoundaryRule)) ?? Data()
        self.isActive = isActive
        self.templates = rotation.templates.map(ShiftTemplateRecord.init)
        self.exceptions = []
    }

    var domain: Rotation {
        Rotation(
            id: id,
            name: name,
            cycleLengthDays: cycleLengthDays,
            anchorDate: CalendarDate(year: anchorYear, month: anchorMonth, day: anchorDay),
            dayBoundaryRule: (try? JSONDecoder().decode(DayBoundaryRule.self, from: dayBoundaryRuleData)) ?? .default,
            templates: templates.map(\.domain)
        )
    }

    var domainExceptions: [RosterException] {
        exceptions.map(\.domain)
    }
}

@Model
final class ShiftTemplateRecord {
    @Attribute(.unique) var id: UUID
    var dayIndexInCycle: Int
    var label: String
    var typeRaw: String
    var startMinuteOfDay: Int
    var durationMinutes: Int

    init(template: ShiftTemplate) {
        self.id = template.id
        self.dayIndexInCycle = template.dayIndexInCycle
        self.label = template.label
        self.typeRaw = template.type.rawValue
        self.startMinuteOfDay = template.startMinuteOfDay
        self.durationMinutes = template.durationMinutes
    }

    var domain: ShiftTemplate {
        ShiftTemplate(
            id: id,
            dayIndexInCycle: dayIndexInCycle,
            label: label,
            type: ShiftType(rawValue: typeRaw) ?? .off,
            startMinuteOfDay: startMinuteOfDay,
            durationMinutes: durationMinutes
        )
    }
}

@Model
final class RosterExceptionRecord {
    @Attribute(.unique) var id: UUID
    var year: Int
    var month: Int
    var day: Int
    /// Encoded `ShiftOverride?` (JSON); nil/empty = call-off.
    var replacementData: Data?
    var note: String?

    init(exception: RosterException) {
        self.id = exception.id
        self.year = exception.date.year
        self.month = exception.date.month
        self.day = exception.date.day
        self.replacementData = exception.replacement.flatMap { try? JSONEncoder().encode($0) }
        self.note = exception.note
    }

    var domain: RosterException {
        RosterException(
            id: id,
            date: CalendarDate(year: year, month: month, day: day),
            replacement: replacementData.flatMap { try? JSONDecoder().decode(ShiftOverride.self, from: $0) },
            note: note
        )
    }
}

enum FoodLogSource: String, Codable {
    case manual, barcode, photo
}

@Model
final class FoodLogRecord {
    @Attribute(.unique) var id: UUID
    /// Resolved at write time; never recomputed. The §7.2 invariant.
    var shiftDayID: String
    var timestamp: Date
    var name: String
    var kcal: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var sourceRaw: String
    var photoRef: String?
    var confidence: Double?

    init(
        shiftDayID: String,
        timestamp: Date,
        name: String,
        kcal: Double,
        protein: Double,
        carbs: Double,
        fat: Double,
        source: FoodLogSource,
        photoRef: String? = nil,
        confidence: Double? = nil
    ) {
        self.id = UUID()
        self.shiftDayID = shiftDayID
        self.timestamp = timestamp
        self.name = name
        self.kcal = kcal
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.sourceRaw = source.rawValue
        self.photoRef = photoRef
        self.confidence = confidence
    }
}

@Model
final class EnergyCheckInRecord {
    @Attribute(.unique) var id: UUID
    var shiftDayID: String
    var timestamp: Date
    var score1to5: Int

    init(shiftDayID: String, timestamp: Date, score1to5: Int) {
        self.id = UUID()
        self.shiftDayID = shiftDayID
        self.timestamp = timestamp
        self.score1to5 = min(5, max(1, score1to5))
    }
}

enum GoalObjective: String, Codable, CaseIterable {
    case lose, maintain, gain, energy
}

@Model
final class GoalProfileRecord {
    @Attribute(.unique) var id: UUID
    var objectiveRaw: String
    /// kcal targets keyed by `ShiftType.rawValue` — targets can differ on
    /// shift days vs. off days.
    var targetKcalByShiftTypeData: Data
    var proteinGrams: Double
    var carbsGrams: Double
    var fatGrams: Double
    /// Encoded `FastingWindow?`.
    var fastingWindowData: Data?

    init(objective: GoalObjective, targetKcalByShiftType: [String: Double], proteinGrams: Double, carbsGrams: Double, fatGrams: Double, fastingWindow: FastingWindow?) {
        self.id = UUID()
        self.objectiveRaw = objective.rawValue
        self.targetKcalByShiftTypeData = (try? JSONEncoder().encode(targetKcalByShiftType)) ?? Data()
        self.proteinGrams = proteinGrams
        self.carbsGrams = carbsGrams
        self.fatGrams = fatGrams
        self.fastingWindowData = fastingWindow.flatMap { try? JSONEncoder().encode($0) }
    }

    var targetKcalByShiftType: [String: Double] {
        (try? JSONDecoder().decode([String: Double].self, from: targetKcalByShiftTypeData)) ?? [:]
    }

    var fastingWindow: FastingWindow? {
        fastingWindowData.flatMap { try? JSONDecoder().decode(FastingWindow.self, from: $0) }
    }

    func targetKcal(for shiftType: ShiftType) -> Double {
        targetKcalByShiftType[shiftType.rawValue]
            ?? targetKcalByShiftType[ShiftType.day.rawValue]
            ?? 2000
    }
}

@Model
final class StreakRecord {
    @Attribute(.unique) var habitType: String
    var currentCount: Int
    var bestCount: Int
    var lastShiftDayID: String?
    var lastYear: Int?
    var lastMonth: Int?
    var lastDay: Int?

    init(habitType: String) {
        self.habitType = habitType
        self.currentCount = 0
        self.bestCount = 0
    }

    var domain: Streak {
        var lastDate: CalendarDate?
        if let y = lastYear, let m = lastMonth, let d = lastDay {
            lastDate = CalendarDate(year: y, month: m, day: d)
        }
        return Streak(habitType: habitType, currentCount: currentCount, bestCount: bestCount, lastShiftDayID: lastShiftDayID, lastCalendarDate: lastDate)
    }

    func apply(_ streak: Streak) {
        currentCount = streak.currentCount
        bestCount = streak.bestCount
        lastShiftDayID = streak.lastShiftDayID
        lastYear = streak.lastCalendarDate?.year
        lastMonth = streak.lastCalendarDate?.month
        lastDay = streak.lastCalendarDate?.day
    }
}

/// User-created foods for quick re-logging (the local food library).
@Model
final class UserFoodRecord {
    @Attribute(.unique) var id: UUID
    var name: String
    var kcal: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var barcode: String?
    var lastUsed: Date

    init(name: String, kcal: Double, protein: Double, carbs: Double, fat: Double, barcode: String? = nil) {
        self.id = UUID()
        self.name = name
        self.kcal = kcal
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.barcode = barcode
        self.lastUsed = .now
    }
}
