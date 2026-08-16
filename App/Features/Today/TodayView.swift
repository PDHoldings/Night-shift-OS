import Combine
import SwiftUI
import SwiftData
import RosterKit

/// Home screen: shift-day header ("Night 2 of 4 · day ends 15:00"), kcal and
/// protein rings for *this ShiftDay*, the next timing cue, and quick-log.
struct TodayView: View {
    let rosterService: RosterService
    @State private var now = Date.now

    private let refresh = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let day = rosterService.shiftDay(at: now) {
                        header(for: day)
                        rings(for: day)
                        nextCue()
                        quickLog()
                    } else {
                        ContentUnavailableView(
                            "No roster yet",
                            systemImage: "calendar.badge.exclamationmark",
                            description: Text("Set up your rotation to get started.")
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("Today")
            .onReceive(refresh) { now = $0 }
        }
    }

    private func header(for day: ShiftDay) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(day.label)
                .font(.largeTitle.bold())
            Text("Day ends \(day.end.formatted(date: .omitted, time: .shortened))")
                .foregroundStyle(.secondary)
            if let shift = day.shift {
                Text("Shift \(shift.start.formatted(date: .omitted, time: .shortened))–\(shift.end.formatted(date: .omitted, time: .shortened))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func rings(for day: ShiftDay) -> some View {
        let logs = rosterService.foodLogs(for: day.id)
        let kcal = logs.reduce(0) { $0 + $1.kcal }
        let protein = logs.reduce(0) { $0 + $1.protein }
        return HStack(spacing: 24) {
            RingView(value: kcal, target: 2200, unit: "kcal", tint: .orange)
            RingView(value: protein, target: 150, unit: "g protein", tint: .blue)
        }
    }

    private func nextCue() -> some View {
        Group {
            if let plan = rosterService.coachPlan(at: now),
               let cue = plan.cues.first(where: { $0.time > now }) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(cue.time, style: .relative)
                        .font(.headline)
                    Text(cue.message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func quickLog() -> some View {
        NavigationLink {
            LogView(rosterService: rosterService)
        } label: {
            Label("Log food", systemImage: "plus.circle.fill")
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

struct RingView: View {
    let value: Double
    let target: Double
    let unit: String
    let tint: Color

    var body: some View {
        VStack {
            ZStack {
                Circle()
                    .stroke(tint.opacity(0.2), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: min(1, value / max(target, 1)))
                    .stroke(tint, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(value))")
                    .font(.title3.bold())
            }
            .frame(width: 96, height: 96)
            Text(unit)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
