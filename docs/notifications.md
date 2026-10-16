# Daily Reminders

Daily 3 offers two independent, optional reminders: a morning reminder to
choose priorities and an evening reminder to review them. Both start off.
Their initial times are 09:00 and 20:00, using the device's local time.

## Why Local Notifications?

The schedule is chosen on the device, so no server or Apple Push
Notification service integration is needed. UserNotifications hands a
notification request to iOS, which can deliver it while the app is not
running. Local reminders do not require the Push Notifications capability.

These are recurring reminders with fixed text, not task-aware messages.
They still run when the day's priorities are already complete. Task titles
are not included in the notification's lock-screen content.

## How the Code Fits Together

- `DailyReminder` defines each reminder's identifier, default time and text.
- `ReminderPreference` stores whether it is enabled and its hour and minute.
- `ReminderSettings` manages permission, scheduling, cancellation and storage.
- `SystemReminderNotifications` calls Apple's notification center.
- `SettingsView` displays switches, time pickers and the permission status.
- `ContentView` owns the observable settings and refreshes them on launch
  and when the app becomes active.

The notification client is a protocol so tests can substitute a fake
notification center. Tests can exercise a refusal or scheduling failure
without changing the device's real permissions or waiting until tomorrow.

## Why UserDefaults Instead of SwiftData?

Daily entries and tasks are related records, which belong in SwiftData.
Two reminder preferences are small app settings, so UserDefaults is enough.
Each preference is encoded as JSON with Codable. Invalid stored values fall
back to the disabled defaults.

Hours and minutes are stored rather than a full Date because a recurring
09:00 reminder represents a time of day, not a particular calendar date.

## Permission and Scheduling

Opening the app or changing a disabled reminder's time does not request
permission. Turning a reminder on requests alert and sound permission if
the user has not yet made that decision.

If permission is denied, the reminder is not enabled. The Settings screen
shows the blocked status and provides a System Settings button. iOS will
not show the same permission prompt again after a refusal.

An enabled reminder uses a repeating `UNCalendarNotificationTrigger` with
only hour and minute components. Its stable request identifier lets a new
time replace the previous request instead of adding duplicate reminders.
Turning it off removes its pending request without affecting the other
reminder. Scheduling errors are shown instead of silently saving an
unscheduled preference.

If permission is later revoked in iOS Settings, the app keeps the user's
saved preferences but removes pending schedules when it next becomes
active. If permission is restored, that refresh schedules enabled reminders
again without asking for permission a second time.

## Manual Check

1. Open Settings in Daily 3. Both reminders should initially be off.
2. Change a reminder's time while it is off. No permission prompt should appear.
3. Turn a reminder on and allow notifications when iOS asks.
4. Set its time a few minutes ahead, then put the app in the background.
5. Confirm that the notification arrives and opens Daily 3 when tapped.
6. Reopen the app and confirm the chosen time and switch are preserved.
7. Turn the reminder off before its next scheduled time and confirm no
   notification arrives for it.
8. Disable notifications in iOS Settings, return to Daily 3 and check the
   blocked status. Restore permission and check that saved preferences remain.

Foreground banners are not requested by this implementation. Test delivery
with the app in the background. Focus modes, Scheduled Summary and system
notification settings can affect when and how iOS presents a notification.

## Topics to Explore

Swift protocols and dependency injection; async/await; MainActor;
Observation and `@Observable`; SwiftUI `@State`, Binding, Toggle and
DatePicker; UserDefaults and Codable; notification authorization;
`UNNotificationRequest`; `UNCalendarNotificationTrigger`; scene lifecycle.

## Apple Documentation

- [Asking permission to use notifications](https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications)
- [Scheduling a notification locally from your app](https://developer.apple.com/documentation/usernotifications/scheduling-a-notification-locally-from-your-app)
