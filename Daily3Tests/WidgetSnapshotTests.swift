import Foundation
import SwiftData
import Testing
@testable import Daily3

@MainActor
struct WidgetSnapshotTests {
    @Test func addingAppGroupsDoesNotChangeTheExistingDatabaseLocation() {
        let configuration = Daily3Storage.configuration
        #expect(configuration.groupAppContainerIdentifier == nil)
        #expect(configuration.url == URL.applicationSupportDirectory.appendingPathComponent("default.store"))
    }

    @Test func snapshotKeepsThreeOrderedSlotsAndIgnoresEmptyCompletion() {
        let snapshot = TodayWidgetSnapshot(day: .now, priorities: [
            WidgetPriority(slot: 3, title: "Review", isCompleted: false),
            WidgetPriority(slot: 1, title: "  Plan  ", isCompleted: true),
            WidgetPriority(slot: 2, title: " \n ", isCompleted: true),
            WidgetPriority(slot: 4, title: "Extra", isCompleted: true)
        ])

        #expect(snapshot.priorities.map(\.slot) == [1, 2, 3])
        #expect(snapshot.priorities.map(\.title) == ["Plan", "", "Review"])
        #expect(snapshot.completedCount == 1)
        #expect(!snapshot.priorities[1].isCompleted)
    }

    @Test func snapshotMapsSavedEntryWithoutChangingTasks() {
        let entry = DailyEntry(date: .now)
        entry.tasks[0].title = "Build"
        entry.tasks[0].isCompleted = true

        let snapshot = TodayWidgetSnapshot(entry: entry, date: .now)

        #expect(snapshot.priorities.count == 3)
        #expect(snapshot.priorities[0].title == "Build")
        #expect(snapshot.completedCount == entry.completedCount)
        #expect(entry.tasks.count == 3)
    }

    @Test func previousAndFutureDaysAreNeverShownAsToday() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let day = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 16)))
        let snapshot = TodayWidgetSnapshot(day: day, priorities: [
            WidgetPriority(slot: 1, title: "Yesterday's priority", isCompleted: true)
        ], calendar: calendar)
        let tomorrow = try #require(calendar.date(byAdding: .day, value: 1, to: day))
        let yesterday = try #require(calendar.date(byAdding: .day, value: -1, to: day))

        #expect(snapshot.forDay(day, calendar: calendar).completedCount == 1)
        for date in [yesterday, tomorrow] {
            let result = snapshot.forDay(date, calendar: calendar)
            #expect(result.priorities.count == 3)
            #expect(result.priorities.allSatisfy { $0.title.isEmpty })
            #expect(result.completedCount == 0)
        }
    }

    @Test func nextDayUsesCalendarAcrossDaylightSavingChange() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/New_York"))
        let day = try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: 8)))
        let snapshot = TodayWidgetSnapshot(day: day, calendar: calendar)
        let nextDay = snapshot.nextDay(calendar: calendar)

        #expect(calendar.component(.day, from: nextDay) == 9)
        #expect(calendar.component(.hour, from: nextDay) == 0)
        #expect(nextDay.timeIntervalSince(day) == 23 * 60 * 60)
    }

    @Test func storeRoundTripsAndSkipsUnchangedWrites() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = WidgetSnapshotStore(directory: directory)
        let now = Date.now
        let snapshot = TodayWidgetSnapshot(day: now, priorities: [
            WidgetPriority(slot: 2, title: "Write tests", isCompleted: true)
        ])

        #expect(try store.write(snapshot))
        #expect(try !store.write(snapshot))
        #expect(WidgetSnapshotStore(directory: directory).read(for: now) == snapshot)
        let nextDay = snapshot.nextDay()
        #expect(store.read(for: nextDay).completedCount == 0)
        #expect(store.read(for: nextDay).priorities.allSatisfy { $0.title.isEmpty })
    }

    @Test func missingCorruptOrUnavailableStorageShowsEmptySlots() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = WidgetSnapshotStore(directory: directory)
        #expect(store.read(for: .now).priorities.count == 3)

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("corrupt".utf8).write(to: directory.appendingPathComponent("today-widget.json"))
        #expect(store.read(for: .now).priorities.allSatisfy { $0.title.isEmpty })

        let unavailable = WidgetSnapshotStore(directory: nil)
        #expect(unavailable.read(for: .now).completedCount == 0)
        #expect(throws: CocoaError.self) { try unavailable.write(TodayWidgetSnapshot(day: .now)) }
    }
}
