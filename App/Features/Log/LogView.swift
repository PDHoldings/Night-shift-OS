import SwiftUI
import SwiftData
import RosterKit

/// Manual + barcode food logging. Whatever the clock says, the entry lands on
/// the current ShiftDay — resolved once, at write time.
struct LogView: View {
    let rosterService: RosterService
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UserFoodRecord.lastUsed, order: .reverse) private var recentFoods: [UserFoodRecord]

    @State private var searchText = ""
    @State private var showingManualEntry = false

    var body: some View {
        NavigationStack {
            List {
                if let day = rosterService.shiftDay() {
                    Section {
                        Label(day.label, systemImage: "moon.zzz")
                            .font(.headline)
                    } footer: {
                        Text("Logging to this shift-day (ends \(day.end.formatted(date: .omitted, time: .shortened))).")
                    }

                    Section("Recent") {
                        ForEach(filteredRecents) { food in
                            Button {
                                relog(food)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(food.name)
                                        Text("\(Int(food.kcal)) kcal · P\(Int(food.protein)) C\(Int(food.carbs)) F\(Int(food.fat))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "plus.circle")
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Section("Today's log") {
                        ForEach(rosterService.foodLogs(for: day.id), id: \.id) { log in
                            HStack {
                                Text(log.name)
                                Spacer()
                                Text("\(Int(log.kcal)) kcal")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search foods")
            .navigationTitle("Log")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingManualEntry = true
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                }
                // Phase 1 also ships barcode scanning (Open Food Facts);
                // camera estimation is Phase 2.
            }
            .sheet(isPresented: $showingManualEntry) {
                ManualFoodEntryView(rosterService: rosterService)
            }
        }
    }

    private var filteredRecents: [UserFoodRecord] {
        guard !searchText.isEmpty else { return Array(recentFoods.prefix(10)) }
        return recentFoods.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private func relog(_ food: UserFoodRecord) {
        rosterService.logFood(name: food.name, kcal: food.kcal, protein: food.protein, carbs: food.carbs, fat: food.fat, source: .manual)
        food.lastUsed = .now
    }
}

struct ManualFoodEntryView: View {
    let rosterService: RosterService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var kcal = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""
    @State private var saveToLibrary = true

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                TextField("Calories", text: $kcal)
                    .keyboardType(.decimalPad)
                TextField("Protein (g)", text: $protein)
                    .keyboardType(.decimalPad)
                TextField("Carbs (g)", text: $carbs)
                    .keyboardType(.decimalPad)
                TextField("Fat (g)", text: $fat)
                    .keyboardType(.decimalPad)
                Toggle("Save to my foods", isOn: $saveToLibrary)
            }
            .navigationTitle("Add food")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Log") { save() }
                        .disabled(name.isEmpty || Double(kcal) == nil)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func save() {
        let kcalValue = Double(kcal) ?? 0
        let proteinValue = Double(protein) ?? 0
        let carbsValue = Double(carbs) ?? 0
        let fatValue = Double(fat) ?? 0
        rosterService.logFood(name: name, kcal: kcalValue, protein: proteinValue, carbs: carbsValue, fat: fatValue, source: .manual)
        if saveToLibrary {
            modelContext.insert(UserFoodRecord(name: name, kcal: kcalValue, protein: proteinValue, carbs: carbsValue, fat: fatValue))
        }
        dismiss()
    }
}
