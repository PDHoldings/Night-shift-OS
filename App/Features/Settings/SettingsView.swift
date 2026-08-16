import SwiftUI
import RosterKit

/// Day-boundary rule, targets by shift type, notifications, CSV export —
/// the trust feature for a skeptical audience.
struct SettingsView: View {
    let rosterService: RosterService
    @State private var boundaryMode: BoundaryMode = .fixed
    @State private var fixedMinute = 15 * 60
    @State private var offsetHours = -4
    @State private var exportURL: URL?

    enum BoundaryMode: String, CaseIterable, Identifiable {
        case fixed = "Fixed time"
        case shiftRelative = "Before my shift"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("My day starts", selection: $boundaryMode) {
                        ForEach(BoundaryMode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    switch boundaryMode {
                    case .fixed:
                        Stepper("At \(timeString(fixedMinute))", value: $fixedMinute, in: 0...1439, step: 30)
                    case .shiftRelative:
                        Stepper("\(-offsetHours)h before shift start", value: $offsetHours, in: -12...0)
                    }
                    Button("Apply day boundary") { applyBoundary() }
                } header: {
                    Text("Personal day boundary")
                } footer: {
                    Text("Your day never resets at midnight. It starts when you say it does.")
                }

                Section("Notifications") {
                    NavigationLink("Shift-aware reminders") {
                        Text("Reminders are computed from your roster and stay quiet during your sleep window.")
                            .padding()
                    }
                }

                Section("Data") {
                    Button("Export logs as CSV") { exportCSV() }
                    if let url = exportURL {
                        ShareLink(item: url) { Label("Share export", systemImage: "square.and.arrow.up") }
                    }
                }

                Section("About") {
                    LabeledContent("App", value: BrandConfig.appName)
                    Text(BrandConfig.wellnessDisclaimer)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .onAppear(perform: loadCurrentRule)
        }
    }

    private func timeString(_ minute: Int) -> String {
        String(format: "%02d:%02d", minute / 60, minute % 60)
    }

    private func loadCurrentRule() {
        switch rosterService.activeRotation?.dayBoundaryRule {
        case .fixedTime(let minute):
            boundaryMode = .fixed
            fixedMinute = minute
        case .shiftRelative(let offset, _):
            boundaryMode = .shiftRelative
            offsetHours = offset / 60
        case nil:
            break
        }
    }

    private func applyBoundary() {
        guard var rotation = rosterService.activeRotation else { return }
        switch boundaryMode {
        case .fixed:
            rotation.dayBoundaryRule = .fixedTime(minuteOfDay: fixedMinute)
        case .shiftRelative:
            rotation.dayBoundaryRule = .shiftRelative(offsetMinutes: offsetHours * 60, offDayFallbackMinuteOfDay: fixedMinute)
        }
        rosterService.activate(rotation: rotation)
    }

    private func exportCSV() {
        guard let day = rosterService.shiftDay() else { return }
        var csv = "shiftDayID,timestamp,name,kcal,protein,carbs,fat,source\n"
        // Phase 1 exports the recent window; full-history export lands with
        // the data-management pass.
        for offset in stride(from: -30, through: 0, by: 1) {
            let date = day.start.addingTimeInterval(TimeInterval(offset) * 86400)
            guard let pastDay = rosterService.shiftDay(at: date) else { continue }
            for log in rosterService.foodLogs(for: pastDay.id) {
                let fields = [log.shiftDayID, log.timestamp.ISO8601Format(), log.name,
                              "\(log.kcal)", "\(log.protein)", "\(log.carbs)", "\(log.fat)", log.sourceRaw]
                csv += fields.map { $0.replacingOccurrences(of: ",", with: ";") }.joined(separator: ",") + "\n"
            }
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("nightshift-export.csv")
        try? csv.write(to: url, atomically: true, encoding: .utf8)
        exportURL = url
    }
}
