import SwiftUI
import RosterKit

/// Rotation setup → day boundary → goal → targets. Under 4 minutes,
/// skippable depth.
struct OnboardingView: View {
    let rosterService: RosterService

    @State private var step = 0
    @State private var selectedPreset: Preset = .fixedNights
    @State private var anchorDate = Date.now
    @State private var boundaryChoice: BoundaryChoice = .fixed3pm
    @State private var goal: GoalObjective = .maintain

    enum Preset: String, CaseIterable, Identifiable {
        case fixedNights = "Fixed nights"
        case panama = "2-2-3 (Panama)"
        case fourOnFourOff = "4 on / 4 off"
        case dupont = "DuPont"
        case twentyFourFortyEight = "24/48"
        case alcon = "A/B weeks (Alcon-style)"
        var id: String { rawValue }
    }

    enum BoundaryChoice: String, CaseIterable, Identifiable {
        case fixed3pm = "When I usually wake (3 PM)"
        case fourBeforeShift = "4 hours before my shift"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            TabView(selection: $step) {
                welcome.tag(0)
                rotationStep.tag(1)
                boundaryStep.tag(2)
                goalStep.tag(3)
            }
            .tabViewStyle(.page)
            .navigationTitle("Welcome")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var welcome: some View {
        VStack(spacing: 16) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 64))
                .foregroundStyle(.indigo)
            Text("Built for your roster")
                .font(.largeTitle.bold())
            Text("Your day doesn't reset at midnight, and neither do we. Set up your rotation once — meals, streaks, and sleep guidance follow your actual schedule.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Get started") { step = 1 }
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var rotationStep: some View {
        Form {
            Section("Your rotation") {
                Picker("Pattern", selection: $selectedPreset) {
                    ForEach(Preset.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.inline)
                DatePicker("First day of a cycle", selection: $anchorDate, displayedComponents: .date)
            }
            Section {
                Button("Next: day boundary") { step = 2 }
            } footer: {
                Text("Pick the closest pattern — you can fine-tune every shift afterwards.")
            }
        }
    }

    private var boundaryStep: some View {
        Form {
            Section("When does your day start?") {
                Picker("Day starts", selection: $boundaryChoice) {
                    ForEach(BoundaryChoice.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.inline)
            }
            Section {
                Button("Next: your goal") { step = 3 }
            } footer: {
                Text("Everything — calories, streaks, summaries — counts against *your* day, not the calendar's.")
            }
        }
    }

    private var goalStep: some View {
        Form {
            Section("Goal") {
                Picker("Objective", selection: $goal) {
                    Text("Lose weight").tag(GoalObjective.lose)
                    Text("Maintain").tag(GoalObjective.maintain)
                    Text("Gain muscle").tag(GoalObjective.gain)
                    Text("More energy").tag(GoalObjective.energy)
                }
                .pickerStyle(.inline)
            }
            Section {
                Button("Finish") { finish() }
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    private func finish() {
        guard let anchor = CalendarDate(from: anchorDate, in: .current) else { return }
        var rotation: Rotation
        switch selectedPreset {
        case .fixedNights: rotation = RotationPresets.fixedNights(anchor: anchor)
        case .panama: rotation = RotationPresets.panama223(anchor: anchor)
        case .fourOnFourOff: rotation = RotationPresets.fourOnFourOff(anchor: anchor)
        case .dupont: rotation = RotationPresets.dupont(anchor: anchor)
        case .twentyFourFortyEight: rotation = RotationPresets.twentyFourFortyEight(anchor: anchor)
        case .alcon: rotation = RotationPresets.alconAB(anchorMonday: anchor)
        }
        switch boundaryChoice {
        case .fixed3pm:
            rotation.dayBoundaryRule = .fixedTime(minuteOfDay: 15 * 60)
        case .fourBeforeShift:
            rotation.dayBoundaryRule = .shiftRelative(offsetMinutes: -240, offDayFallbackMinuteOfDay: 15 * 60)
        }
        rosterService.activate(rotation: rotation)
    }
}
