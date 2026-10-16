import Foundation
import Observation
import UserNotifications

@MainActor
protocol ReminderNotificationClient {
    func authorizationStatus() async -> UNAuthorizationStatus
    func requestAuthorization() async throws -> Bool
    func add(_ request: UNNotificationRequest) async throws
    func removePendingRequests(withIdentifiers identifiers: [String])
}

struct SystemReminderNotifications: ReminderNotificationClient {
    private let center = UNUserNotificationCenter.current()

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound])
    }

    func add(_ request: UNNotificationRequest) async throws {
        try await center.add(request)
    }

    func removePendingRequests(withIdentifiers identifiers: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}

@MainActor
@Observable
final class ReminderSettings {
    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    private(set) var isUpdating = false
    private(set) var errorMessage: String?
    private var preferences: [DailyReminder: ReminderPreference]
    private let defaults: UserDefaults
    private let client: any ReminderNotificationClient

    init(defaults: UserDefaults = .standard, client: (any ReminderNotificationClient)? = nil) {
        self.defaults = defaults
        self.client = client ?? SystemReminderNotifications()
        preferences = Dictionary(uniqueKeysWithValues: DailyReminder.allCases.map { reminder in
            let stored = defaults.data(forKey: reminder.preferenceKey)
                .flatMap { try? JSONDecoder().decode(ReminderPreference.self, from: $0) }
            let preference = stored.flatMap { $0.isValid ? $0 : nil } ?? reminder.defaultPreference
            return (reminder, preference)
        })
    }

    var canSchedule: Bool {
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral: return true
        default: return false
        }
    }

    func preference(for reminder: DailyReminder) -> ReminderPreference {
        preferences[reminder] ?? reminder.defaultPreference
    }

    func refresh() async {
        guard !isUpdating else { return }
        isUpdating = true
        errorMessage = nil
        defer { isUpdating = false }

        authorizationStatus = await client.authorizationStatus()
        for reminder in DailyReminder.allCases {
            let preference = preference(for: reminder)
            if preference.isEnabled && canSchedule {
                do {
                    try await client.add(reminder.request(for: preference))
                } catch {
                    errorMessage = "Your reminders could not be scheduled. Please try again."
                }
            } else {
                client.removePendingRequests(withIdentifiers: [reminder.requestIdentifier])
            }
        }
    }

    func setEnabled(_ enabled: Bool, for reminder: DailyReminder) async {
        guard !isUpdating else { return }
        isUpdating = true
        errorMessage = nil
        defer { isUpdating = false }

        var updated = preference(for: reminder)
        updated.isEnabled = enabled
        do {
            if enabled {
                authorizationStatus = await client.authorizationStatus()
                if authorizationStatus == .notDetermined {
                    let granted = try await client.requestAuthorization()
                    authorizationStatus = await client.authorizationStatus()
                    guard granted else { return }
                }
                guard canSchedule else { return }
                try await client.add(reminder.request(for: updated))
            } else {
                client.removePendingRequests(withIdentifiers: [reminder.requestIdentifier])
            }
            try save(updated, for: reminder)
        } catch {
            errorMessage = "This reminder could not be updated. Please try again."
        }
    }

    func setTime(hour: Int, minute: Int, for reminder: DailyReminder) async {
        guard !isUpdating, (0...23).contains(hour), (0...59).contains(minute) else { return }
        isUpdating = true
        errorMessage = nil
        defer { isUpdating = false }

        var updated = preference(for: reminder)
        updated.hour = hour
        updated.minute = minute
        do {
            if updated.isEnabled {
                authorizationStatus = await client.authorizationStatus()
                if canSchedule {
                    try await client.add(reminder.request(for: updated))
                } else {
                    client.removePendingRequests(withIdentifiers: [reminder.requestIdentifier])
                }
            }
            try save(updated, for: reminder)
        } catch {
            errorMessage = "The reminder time could not be updated. Please try again."
        }
    }

    func clearError() {
        errorMessage = nil
    }

    private func save(_ preference: ReminderPreference, for reminder: DailyReminder) throws {
        let data = try JSONEncoder().encode(preference)
        defaults.set(data, forKey: reminder.preferenceKey)
        preferences[reminder] = preference
    }
}
