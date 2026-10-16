import Foundation
import UserNotifications

enum DailyReminder: String, CaseIterable, Identifiable {
    case morning
    case evening

    var id: String { rawValue }
    var requestIdentifier: String { "daily3.reminder.\(rawValue)" }
    var preferenceKey: String { "reminders.\(rawValue)" }

    var title: String {
        switch self {
        case .morning: return "Morning reminder"
        case .evening: return "Evening reminder"
        }
    }

    var defaultPreference: ReminderPreference {
        ReminderPreference(hour: self == .morning ? 9 : 20)
    }

    func request(for preference: ReminderPreference) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = self == .morning ? "Your daily three" : "A moment to look back"
        content.body = self == .morning
            ? "What are your three priorities for today?"
            : "Take a moment to review today's three priorities."
        content.sound = .default

        // Only hour and minute are matched, so the reminder repeats in local time.
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: DateComponents(hour: preference.hour, minute: preference.minute),
            repeats: true
        )
        return UNNotificationRequest(identifier: requestIdentifier, content: content, trigger: trigger)
    }
}

struct ReminderPreference: Codable, Equatable {
    var isEnabled = false
    var hour: Int
    var minute = 0

    var isValid: Bool {
        (0...23).contains(hour) && (0...59).contains(minute)
    }
}
