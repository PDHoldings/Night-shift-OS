import SwiftUI
import RosterKit

/// Tonight's plan: eat / caffeine / light / sleep rendered as a shift
/// timeline, not a midnight-anchored day.
struct CoachView: View {
    let rosterService: RosterService
    @State private var now = Date.now

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let plan = rosterService.coachPlan(at: now) {
                        shiftHeader(plan)
                        timeline(plan)
                        sleepCard(plan)
                    } else {
                        ContentUnavailableView(
                            "No upcoming shift",
                            systemImage: "moon.zzz",
                            description: Text("Your next plan appears when a shift is on the roster.")
                        )
                    }
                    Text(BrandConfig.wellnessDisclaimer)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding()
            }
            .navigationTitle("Coach")
            .refreshable { now = .now }
        }
    }

    private func shiftHeader(_ plan: CoachPlan) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(plan.shift.label)
                .font(.title2.bold())
            Text("\(plan.shift.start.formatted(date: .abbreviated, time: .shortened)) → \(plan.shift.end.formatted(date: .omitted, time: .shortened))")
                .foregroundStyle(.secondary)
        }
    }

    private func timeline(_ plan: CoachPlan) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(plan.cues) { cue in
                HStack(alignment: .top, spacing: 12) {
                    VStack(spacing: 0) {
                        Circle()
                            .fill(cue.time < now ? Color.secondary : Color.accentColor)
                            .frame(width: 10, height: 10)
                        if cue.id != plan.cues.last?.id {
                            Rectangle()
                                .fill(Color.secondary.opacity(0.3))
                                .frame(width: 2)
                        }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(cue.time.formatted(date: .omitted, time: .shortened))
                            .font(.caption.bold())
                        Text(cue.message)
                            .font(.subheadline)
                            .foregroundStyle(cue.time < now ? .secondary : .primary)
                            .padding(.bottom, 16)
                    }
                }
            }
        }
    }

    private func sleepCard(_ plan: CoachPlan) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Anchor sleep", systemImage: "bed.double.fill")
                .font(.headline)
            Text("\(plan.sleepWindow.start.formatted(date: .omitted, time: .shortened)) – \(plan.sleepWindow.end.formatted(date: .omitted, time: .shortened))")
            Text("Notifications stay quiet during this window.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
