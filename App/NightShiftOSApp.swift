import SwiftUI
import SwiftData

@main
struct NightShiftOSApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(
                for: RotationRecord.self,
                ShiftTemplateRecord.self,
                RosterExceptionRecord.self,
                FoodLogRecord.self,
                EnergyCheckInRecord.self,
                GoalProfileRecord.self,
                StreakRecord.self,
                UserFoodRecord.self
            )
        } catch {
            fatalError("Failed to create model container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}

/// Routes to onboarding until a rotation exists, then the main tabs.
struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var rosterService: RosterService?

    var body: some View {
        Group {
            if let service = rosterService {
                if service.activeRotation == nil {
                    OnboardingView(rosterService: service)
                } else {
                    MainTabView(rosterService: service)
                }
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if rosterService == nil {
                rosterService = RosterService(modelContext: modelContext)
            }
        }
    }
}

struct MainTabView: View {
    let rosterService: RosterService

    var body: some View {
        TabView {
            TodayView(rosterService: rosterService)
                .tabItem { Label("Today", systemImage: "sun.haze") }
            RosterView(rosterService: rosterService)
                .tabItem { Label("Roster", systemImage: "calendar") }
            LogView(rosterService: rosterService)
                .tabItem { Label("Log", systemImage: "plus.circle") }
            CoachView(rosterService: rosterService)
                .tabItem { Label("Coach", systemImage: "moon.stars") }
            SettingsView(rosterService: rosterService)
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}
