import SwiftUI
import RosterKit

/// Rotation calendar 8 weeks out, with tap-to-edit exceptions —
/// the one-tap "my schedule changed" flow.
struct RosterView: View {
    let rosterService: RosterService
    @State private var editingDay: ShiftDay?

    var body: some View {
        NavigationStack {
            List {
                ForEach(weeks, id: \.first?.id) { week in
                    Section {
                        ForEach(week) { day in
                            Button {
                                editingDay = day
                            } label: {
                                row(for: day)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("Roster")
            .sheet(item: $editingDay) { day in
                ExceptionEditorView(rosterService: rosterService, day: day)
            }
        }
    }

    private var weeks: [[ShiftDay]] {
        let days = rosterService.upcomingDays(count: 56)
        return stride(from: 0, to: days.count, by: 7).map { Array(days[$0..<min($0 + 7, days.count)]) }
    }

    private func row(for day: ShiftDay) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(day.calendarDate.description)
                    .font(.subheadline)
                Text(day.label)
                    .font(.headline)
            }
            Spacer()
            if let shift = day.shift {
                Text("\(shift.start.formatted(date: .omitted, time: .shortened))–\(shift.end.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Circle()
                .fill(color(for: day.shiftType))
                .frame(width: 10, height: 10)
        }
    }

    private func color(for type: ShiftType) -> Color {
        switch type {
        case .night: return .indigo
        case .day: return .yellow
        case .swing: return .orange
        case .off: return .green
        case .oncall: return .red
        }
    }
}

/// "My schedule changed" — swap the shift, add overtime, or call off.
struct ExceptionEditorView: View {
    let rosterService: RosterService
    let day: ShiftDay
    @Environment(\.dismiss) private var dismiss

    @State private var mode: Mode = .swap
    @State private var startMinute = 18 * 60
    @State private var durationMinutes = 12 * 60
    @State private var shiftType: ShiftType = .night
    @State private var note = ""

    enum Mode: String, CaseIterable, Identifiable {
        case swap = "Different shift"
        case callOff = "Off (call-off)"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(day.calendarDate.description) {
                    Picker("Change", selection: $mode) {
                        ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                if mode == .swap {
                    Section("Replacement shift") {
                        Picker("Type", selection: $shiftType) {
                            ForEach([ShiftType.night, .day, .swing, .oncall], id: \.self) {
                                Text($0.labelNoun).tag($0)
                            }
                        }
                        Stepper("Starts \(timeString(startMinute))", value: $startMinute, in: 0...1439, step: 30)
                        Stepper("Length \(durationMinutes / 60)h \(durationMinutes % 60)m", value: $durationMinutes, in: 60...1440, step: 30)
                    }
                }
                Section {
                    TextField("Note (optional)", text: $note)
                }
            }
            .navigationTitle("Schedule change")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func timeString(_ minute: Int) -> String {
        String(format: "%02d:%02d", minute / 60, minute % 60)
    }

    private func save() {
        let replacement: ShiftOverride? = mode == .swap
            ? ShiftOverride(label: "\(shiftType.labelNoun) (changed)", type: shiftType, startMinuteOfDay: startMinute, durationMinutes: durationMinutes)
            : nil
        rosterService.addException(RosterException(
            date: day.calendarDate,
            replacement: replacement,
            note: note.isEmpty ? nil : note
        ))
        dismiss()
    }
}
