import SwiftUI
import UIKit
import UserNotifications

struct SettingsView: View {
    let settings: ReminderSettings
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            Form {
                Section("Notifications") {
                    LabeledContent("Permission", value: permissionText)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Notification permission")
                        .accessibilityValue(permissionText)
                        .accessibilityIdentifier("reminder.permission")
                    if settings.authorizationStatus != .notDetermined {
                        Button("System Settings", systemImage: "arrow.up.forward.app") {
                            if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                                openURL(url)
                            }
                        }
                    }
                    if settings.authorizationStatus == .denied {
                        Text("Notifications are disabled in iOS Settings.")
                            .foregroundStyle(.secondary)
                    }
                }

                ForEach(DailyReminder.allCases) { reminder in
                    Section {
                        Toggle(isOn: enabledBinding(for: reminder)) {
                            Label(reminder.title, systemImage: reminder == .morning ? "sun.max" : "moon")
                        }
                        .accessibilityIdentifier("reminder.\(reminder.rawValue).enabled")

                        DatePicker("Time", selection: timeBinding(for: reminder), displayedComponents: .hourAndMinute)
                            .accessibilityIdentifier("reminder.\(reminder.rawValue).time")
                    }
                }
            }
            .disabled(settings.isUpdating)
            .navigationTitle("Settings")
            .alert("Reminder update failed", isPresented: Binding(
                get: { settings.errorMessage != nil },
                set: { if !$0 { settings.clearError() } }
            )) {
                Button("OK", role: .cancel) { settings.clearError() }
            } message: {
                Text(settings.errorMessage ?? "")
            }
        }
    }

    private var permissionText: String {
        switch settings.authorizationStatus {
        case .notDetermined: return "Not requested"
        case .denied: return "Off in Settings"
        case .authorized, .ephemeral: return "Allowed"
        case .provisional: return "Quiet delivery"
        @unknown default: return "Unavailable"
        }
    }

    private func enabledBinding(for reminder: DailyReminder) -> Binding<Bool> {
        Binding(
            get: { settings.preference(for: reminder).isEnabled },
            set: { enabled in Task { await settings.setEnabled(enabled, for: reminder) } }
        )
    }

    private func timeBinding(for reminder: DailyReminder) -> Binding<Date> {
        Binding(
            get: {
                let preference = settings.preference(for: reminder)
                return Calendar.current.date(bySettingHour: preference.hour, minute: preference.minute, second: 0, of: .now) ?? .now
            },
            set: { date in
                let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                guard let hour = components.hour, let minute = components.minute else { return }
                Task { await settings.setTime(hour: hour, minute: minute, for: reminder) }
            }
        )
    }
}
