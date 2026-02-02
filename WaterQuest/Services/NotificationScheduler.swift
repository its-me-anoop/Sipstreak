import Foundation
import UserNotifications

@MainActor
final class NotificationScheduler: ObservableObject {
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined

    func requestAuthorization() async {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            authorizationStatus = granted ? .authorized : .denied
        } catch {
            authorizationStatus = .denied
        }
    }

    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    func scheduleReminders(profile: UserProfile) {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        guard profile.remindersEnabled else { return }

        let times = reminderTimes(wakeMinutes: profile.wakeMinutes, sleepMinutes: profile.sleepMinutes, count: profile.dailyReminderCount)
        for (index, minutes) in times.enumerated() {
            var dateComponents = DateComponents()
            dateComponents.hour = minutes / 60
            dateComponents.minute = minutes % 60

            let content = UNMutableNotificationContent()
            content.title = "Hydration Quest"
            content.body = reminderMessage(index: index)
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(identifier: "waterquest.reminder.\(index)", content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request)
        }
    }

    private func reminderTimes(wakeMinutes: Int, sleepMinutes: Int, count: Int) -> [Int] {
        let adjustedCount = max(1, min(12, count))
        let span = max(1, sleepMinutes - wakeMinutes)
        let gap = span / adjustedCount
        return (0..<adjustedCount).map { wakeMinutes + $0 * gap }
    }

    private func reminderMessage(index: Int) -> String {
        let messages = [
            "Sip time! Your future self is cheering.",
            "Take a water break and claim some XP.",
            "Quest check-in: a few sips goes far.",
            "Hydrate to keep your streak alive.",
            "Tiny sip, big win. Let's go!"
        ]
        return messages[index % messages.count]
    }
}
