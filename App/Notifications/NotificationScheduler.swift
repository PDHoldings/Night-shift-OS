import Foundation
import UserNotifications
import RosterKit

/// Schedules local notifications from the roster over a 72-hour rolling
/// window, recomputed on app open and on any roster change. Notifications
/// are quiet during the user's sleep window — even though that's daytime.
struct NotificationScheduler {
    let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// Replace all pending roster notifications with the next 72h of cues.
    func reschedule(
        rotation: Rotation,
        exceptions: [RosterException],
        timeZone: TimeZone,
        preferences: CoachPreferences = CoachPreferences(),
        now: Date = .now
    ) async {
        center.removeAllPendingNotificationRequests()

        let horizon = now.addingTimeInterval(72 * 3600)
        var shiftStart = now
        var sleepWindows: [DateInterval] = []
        var requests: [UNNotificationRequest] = []

        // Walk shifts inside the window, planning cues for each.
        while let shift = RosterEngine.nextShift(after: shiftStart, rotation: rotation, exceptions: exceptions, timeZone: timeZone),
              shift.start < horizon {
            let plan = TimingCoach.plan(for: shift, preferences: preferences)
            sleepWindows.append(plan.sleepWindow)
            for cue in plan.cues where cue.time > now && cue.time < horizon {
                requests.append(request(for: cue))
            }
            shiftStart = shift.start.addingTimeInterval(60)
        }

        // Drop anything that would fire inside a sleep window: protect
        // daytime sleep like it's a shift.
        let quiet = sleepWindows
        for request in requests where !quiet.contains(where: { interval in
            if let trigger = request.trigger as? UNTimeIntervalNotificationTrigger,
               let fireDate = trigger.nextTriggerDate() {
                return interval.contains(fireDate)
            }
            return false
        }) {
            try? await center.add(request)
        }
    }

    private func request(for cue: CoachCue) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = title(for: cue.kind)
        content.body = cue.message
        content.sound = .default
        let interval = max(1, cue.time.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        return UNNotificationRequest(identifier: cue.id, content: content, trigger: trigger)
    }

    private func title(for kind: CoachCue.Kind) -> String {
        switch kind {
        case .mainMeal: return "Pre-shift meal"
        case .snack: return "Snack window"
        case .avoidLargeMeal: return "Ease off the food"
        case .caffeineCutoff: return "Caffeine cutoff"
        case .brightLight: return "Light up"
        case .dimLight: return "Wind the light down"
        case .windDown: return "Wind down"
        case .sleepStart: return "Sleep window"
        }
    }
}
