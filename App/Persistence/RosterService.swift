import Foundation
import Observation
import SwiftData
import RosterKit

/// App-side facade over RosterKit: loads the active rotation from SwiftData
/// and answers "what ShiftDay is it?" for every feature. All math is
/// delegated to the pure engine.
@Observable
final class RosterService {
    private let modelContext: ModelContext
    var timeZone: TimeZone

    init(modelContext: ModelContext, timeZone: TimeZone = .current) {
        self.modelContext = modelContext
        self.timeZone = timeZone
    }

    var activeRotationRecord: RotationRecord? {
        let descriptor = FetchDescriptor<RotationRecord>(predicate: #Predicate { $0.isActive })
        return try? modelContext.fetch(descriptor).first
    }

    var activeRotation: Rotation? { activeRotationRecord?.domain }
    var activeExceptions: [RosterException] { activeRotationRecord?.domainExceptions ?? [] }

    /// The ShiftDay containing `date` (default: now) on the active roster.
    func shiftDay(at date: Date = .now) -> ShiftDay? {
        guard let rotation = activeRotation else { return nil }
        return RosterEngine.resolveShiftDay(for: date, rotation: rotation, exceptions: activeExceptions, timeZone: timeZone)
    }

    /// Roster preview for the calendar screen (8 weeks by default).
    func upcomingDays(from date: Date = .now, count: Int = 56) -> [ShiftDay] {
        guard let rotation = activeRotation else { return [] }
        return RosterEngine.shiftDays(startingAt: date, count: count, rotation: rotation, exceptions: activeExceptions, timeZone: timeZone)
    }

    func nextShift(after date: Date = .now) -> ResolvedShift? {
        guard let rotation = activeRotation else { return nil }
        return RosterEngine.nextShift(after: date, rotation: rotation, exceptions: activeExceptions, timeZone: timeZone)
    }

    /// Tonight's (or the current) coach plan.
    func coachPlan(at date: Date = .now, preferences: CoachPreferences = CoachPreferences()) -> CoachPlan? {
        guard let rotation = activeRotation else { return nil }
        let shift = RosterEngine.currentShift(at: date, rotation: rotation, exceptions: activeExceptions, timeZone: timeZone)
            ?? RosterEngine.nextShift(after: date, rotation: rotation, exceptions: activeExceptions, timeZone: timeZone)
        return shift.map { TimingCoach.plan(for: $0, preferences: preferences) }
    }

    // MARK: - Mutations

    func activate(rotation: Rotation) {
        if let existing = activeRotationRecord {
            existing.isActive = false
        }
        modelContext.insert(RotationRecord(rotation: rotation))
        try? modelContext.save()
    }

    /// One-tap "my schedule changed": everything downstream (guidance,
    /// notifications, materialized days) derives from the engine, so adding
    /// the exception is the whole fix.
    func addException(_ exception: RosterException) {
        guard let record = activeRotationRecord else { return }
        record.exceptions.append(RosterExceptionRecord(exception: exception))
        try? modelContext.save()
    }

    /// Log food, pinning the ShiftDay id at write time (§7.2 invariant).
    @discardableResult
    func logFood(name: String, kcal: Double, protein: Double, carbs: Double, fat: Double, source: FoodLogSource, at timestamp: Date = .now) -> FoodLogRecord? {
        guard let day = shiftDay(at: timestamp) else { return nil }
        let record = FoodLogRecord(
            shiftDayID: day.id,
            timestamp: timestamp,
            name: name,
            kcal: kcal,
            protein: protein,
            carbs: carbs,
            fat: fat,
            source: source
        )
        modelContext.insert(record)
        updateStreak(habitType: "logging", on: day)
        try? modelContext.save()
        return record
    }

    func foodLogs(for shiftDayID: String) -> [FoodLogRecord] {
        let descriptor = FetchDescriptor<FoodLogRecord>(
            predicate: #Predicate { $0.shiftDayID == shiftDayID },
            sortBy: [SortDescriptor(\.timestamp)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func updateStreak(habitType: String, on day: ShiftDay) {
        let descriptor = FetchDescriptor<StreakRecord>(predicate: #Predicate { $0.habitType == habitType })
        let record = (try? modelContext.fetch(descriptor).first) ?? {
            let new = StreakRecord(habitType: habitType)
            modelContext.insert(new)
            return new
        }()
        let updated = StreakEngine.recordAchievement(
            on: day,
            streak: record.domain,
            calendar: RosterEngine.calendar(in: timeZone)
        )
        record.apply(updated)
    }
}
