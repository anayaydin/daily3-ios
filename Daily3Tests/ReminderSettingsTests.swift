import Foundation
import Testing
import UserNotifications
@testable import Daily3

@MainActor
struct ReminderSettingsTests {
    @Test func launchDoesNotRequestPermissionAndRemindersStartDisabled() async throws {
        let fixture = try ReminderFixture()
        defer { fixture.cleanUp() }

        await fixture.settings.refresh()

        #expect(!fixture.settings.preference(for: .morning).isEnabled)
        #expect(!fixture.settings.preference(for: .evening).isEnabled)
        #expect(fixture.settings.preference(for: .morning).hour == 9)
        #expect(fixture.settings.preference(for: .evening).hour == 20)
        #expect(fixture.client.authorizationRequests == 0)
        #expect(fixture.client.pending.isEmpty)
    }

    @Test func enablingRequestsPermissionAndSavesDailyLocalTimeTrigger() async throws {
        let fixture = try ReminderFixture()
        defer { fixture.cleanUp() }

        await fixture.settings.setEnabled(true, for: .morning)

        #expect(fixture.client.authorizationRequests == 1)
        #expect(fixture.settings.canSchedule)
        let request = try #require(fixture.client.pending[DailyReminder.morning.requestIdentifier])
        let trigger = try #require(request.trigger as? UNCalendarNotificationTrigger)
        #expect(trigger.repeats)
        #expect(trigger.dateComponents.hour == 9)
        #expect(trigger.dateComponents.minute == 0)
        #expect(trigger.dateComponents.day == nil)
        #expect(trigger.dateComponents.timeZone == nil)
        #expect(request.content.body == "What are your three priorities for today?")

        let reloaded = ReminderSettings(defaults: fixture.defaults, client: fixture.client)
        #expect(reloaded.preference(for: .morning).isEnabled)
        #expect(!reloaded.preference(for: .evening).isEnabled)
    }

    @Test func changingTimeReplacesRequestAndDisablingOnlyRemovesThatReminder() async throws {
        let fixture = try ReminderFixture()
        defer { fixture.cleanUp() }
        fixture.client.status = .authorized

        await fixture.settings.setEnabled(true, for: .morning)
        await fixture.settings.setEnabled(true, for: .evening)
        await fixture.settings.setTime(hour: 10, minute: 45, for: .morning)

        #expect(fixture.client.pending.count == 2)
        let trigger = try #require(fixture.client.pending[DailyReminder.morning.requestIdentifier]?.trigger as? UNCalendarNotificationTrigger)
        #expect(trigger.dateComponents.hour == 10)
        #expect(trigger.dateComponents.minute == 45)

        await fixture.settings.setEnabled(false, for: .morning)

        #expect(fixture.client.pending[DailyReminder.morning.requestIdentifier] == nil)
        #expect(fixture.client.pending[DailyReminder.evening.requestIdentifier] != nil)
        #expect(!fixture.settings.preference(for: .morning).isEnabled)
        #expect(fixture.client.authorizationRequests == 0)
    }

    @Test func choosingTimeWhileDisabledSavesWithoutPermission() async throws {
        let fixture = try ReminderFixture()
        defer { fixture.cleanUp() }

        await fixture.settings.setTime(hour: 22, minute: 15, for: .evening)

        let reloaded = ReminderSettings(defaults: fixture.defaults, client: fixture.client)
        #expect(reloaded.preference(for: .evening) == ReminderPreference(hour: 22, minute: 15))
        #expect(fixture.client.authorizationRequests == 0)
        #expect(fixture.client.pending.isEmpty)
    }

    @Test func deniedPermissionDoesNotEnableOrRepeatedlyAsk() async throws {
        let fixture = try ReminderFixture()
        defer { fixture.cleanUp() }
        fixture.client.grantsPermission = false

        await fixture.settings.setEnabled(true, for: .morning)
        await fixture.settings.setEnabled(true, for: .morning)

        #expect(fixture.client.authorizationRequests == 1)
        #expect(fixture.settings.authorizationStatus == .denied)
        #expect(!fixture.settings.preference(for: .morning).isEnabled)
        #expect(fixture.client.pending.isEmpty)
    }

    @Test func schedulingFailureKeepsPreviousPreferenceAndCanBeRetried() async throws {
        let fixture = try ReminderFixture()
        defer { fixture.cleanUp() }
        fixture.client.status = .authorized
        fixture.client.failsScheduling = true

        await fixture.settings.setEnabled(true, for: .morning)
        #expect(!fixture.settings.preference(for: .morning).isEnabled)
        #expect(fixture.settings.errorMessage != nil)
        #expect(!fixture.settings.isUpdating)

        fixture.client.failsScheduling = false
        await fixture.settings.setEnabled(true, for: .morning)
        #expect(fixture.settings.errorMessage == nil)
        fixture.client.failsScheduling = true
        await fixture.settings.setTime(hour: 11, minute: 30, for: .morning)

        #expect(fixture.settings.preference(for: .morning).hour == 9)
        let trigger = try #require(fixture.client.pending[DailyReminder.morning.requestIdentifier]?.trigger as? UNCalendarNotificationTrigger)
        #expect(trigger.dateComponents.hour == 9)
        #expect(fixture.settings.errorMessage != nil)
    }

    @Test func refreshRestoresSchedulesAfterPermissionChangesWithoutPrompting() async throws {
        let fixture = try ReminderFixture()
        defer { fixture.cleanUp() }
        fixture.client.status = .authorized
        await fixture.settings.setEnabled(true, for: .evening)

        fixture.client.status = .denied
        await fixture.settings.refresh()
        #expect(fixture.client.pending.isEmpty)
        #expect(fixture.settings.preference(for: .evening).isEnabled)

        fixture.client.status = .authorized
        let reloaded = ReminderSettings(defaults: fixture.defaults, client: fixture.client)
        await reloaded.refresh()
        #expect(fixture.client.pending.count == 1)
        #expect(fixture.client.pending[DailyReminder.evening.requestIdentifier] != nil)
        #expect(fixture.client.authorizationRequests == 0)
    }

    @Test func invalidStoredPreferencesFallBackToDisabledDefaults() throws {
        let fixture = try ReminderFixture()
        defer { fixture.cleanUp() }
        fixture.defaults.set(Data("invalid json".utf8), forKey: DailyReminder.morning.preferenceKey)
        fixture.defaults.set(
            try JSONEncoder().encode(ReminderPreference(isEnabled: true, hour: 25, minute: 80)),
            forKey: DailyReminder.evening.preferenceKey
        )

        let reloaded = ReminderSettings(defaults: fixture.defaults, client: fixture.client)
        #expect(reloaded.preference(for: .morning) == DailyReminder.morning.defaultPreference)
        #expect(reloaded.preference(for: .evening) == DailyReminder.evening.defaultPreference)
    }
}

@MainActor
private struct ReminderFixture {
    let suiteName: String
    let defaults: UserDefaults
    let client: FakeReminderNotifications
    let settings: ReminderSettings

    init() throws {
        let name = "Daily3.ReminderTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        let client = FakeReminderNotifications()
        suiteName = name
        self.defaults = defaults
        self.client = client
        settings = ReminderSettings(defaults: defaults, client: client)
    }

    func cleanUp() {
        defaults.removePersistentDomain(forName: suiteName)
    }
}

@MainActor
private final class FakeReminderNotifications: ReminderNotificationClient {
    var status: UNAuthorizationStatus = .notDetermined
    var grantsPermission = true
    var failsScheduling = false
    var authorizationRequests = 0
    var pending: [String: UNNotificationRequest] = [:]

    func authorizationStatus() async -> UNAuthorizationStatus { status }

    func requestAuthorization() async throws -> Bool {
        authorizationRequests += 1
        status = grantsPermission ? .authorized : .denied
        return grantsPermission
    }

    func add(_ request: UNNotificationRequest) async throws {
        if failsScheduling { throw CocoaError(.coderInvalidValue) }
        pending[request.identifier] = request
    }

    func removePendingRequests(withIdentifiers identifiers: [String]) {
        for identifier in identifiers { pending[identifier] = nil }
    }
}
