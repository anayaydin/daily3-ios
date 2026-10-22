import Foundation
import SwiftData
import Testing
@testable import Daily3

@MainActor
struct WatchSyncTests {
    private let now = Calendar.current.startOfDay(for: Date.now).addingTimeInterval(12 * 60 * 60)

    @Test func completionUpdatesTheSavedPriority() throws {
        let fixture = try Fixture(day: now)
        var watch = WatchLocalState()
        watch.receive(try fixture.processor.makeState(now: now))
        let change = try toggle(&watch)

        #expect(try fixture.processor.process(change, now: now).status == .accepted)
        #expect(fixture.entry.sortedTasks[0].isCompleted)
        let reloaded = ModelContext(fixture.container)
        #expect(try reloaded.fetch(FetchDescriptor<DailyEntry>()).first?.completedCount == 1)
        watch.receive(try fixture.processor.makeState(now: now))
        #expect(watch.pending.isEmpty)
        #expect(watch.snapshot(for: now).completedCount == 1)
    }

    @Test func delayedAndDuplicateCommandsCannotUndoANewerChangeAfterRelaunch() throws {
        let fixture = try Fixture(day: now)
        var watch = WatchLocalState()
        watch.receive(try fixture.processor.makeState(now: now))
        let first = try toggle(&watch)
        let second = try toggle(&watch)

        #expect(try fixture.processor.process(second, now: now).status == .accepted)
        let relaunched = WatchCommandProcessor(context: fixture.context, defaults: fixture.defaults)
        #expect(try relaunched.process(first, now: now).status == .outdated)
        #expect(try relaunched.process(second, now: now).status == .outdated)
        #expect(!fixture.entry.sortedTasks[0].isCompleted)
        #expect(relaunched.phoneID == fixture.processor.phoneID)
    }

    @Test func pastAndFutureCommandsCannotEditHistory() throws {
        let fixture = try Fixture(day: now)
        for offset in [-1, 1] {
            let day = try #require(Calendar.current.date(byAdding: .day, value: offset, to: now))
            let historical = DailyEntry(date: day)
            historical.sortedTasks[0].title = "Build"
            fixture.context.insert(historical)
            try fixture.context.save()
            let change = fixture.change(day: day)
            #expect(try fixture.processor.process(change, now: now).status == .differentDay)
            #expect(!historical.sortedTasks[0].isCompleted)
        }
        #expect(!fixture.entry.sortedTasks[0].isCompleted)
    }

    @Test func changedEmptyAndInvalidPrioritiesAreRejected() throws {
        let fixture = try Fixture(day: now)
        #expect(try fixture.processor.process(fixture.change(title: "Old title"), now: now).status == .differentPriority)
        #expect(try fixture.processor.process(fixture.change(slot: 2, title: ""), now: now).status == .differentPriority)
        #expect(try fixture.processor.process(fixture.change(slot: 4), now: now).status == .invalid)
        #expect(try fixture.processor.process(fixture.change(sequence: 0), now: now).status == .invalid)
        #expect(try fixture.processor.process(fixture.change(phoneID: UUID()), now: now).status == .differentPhone)
        #expect(fixture.entry.completedCount == 0)
    }

    @Test func unavailableDailyEntryIsNotCreatedByAWatchCommand() throws {
        let fixture = try Fixture(day: now)
        fixture.context.delete(fixture.entry)
        try fixture.context.save()
        #expect(try fixture.processor.process(fixture.change(), now: now).status == .differentPriority)
        #expect(try fixture.context.fetchCount(FetchDescriptor<DailyEntry>()) == 0)
    }

    @Test func offlineChangesSurviveEncodingAndOnlyTheLatestPerSlotRemains() throws {
        var watch = WatchLocalState()
        watch.receive(state(revision: 1))
        _ = try toggle(&watch)
        let latest = try toggle(&watch)
        #expect(watch.pending.count == 1)
        #expect(!watch.snapshot(for: now).priorities[0].isCompleted)

        let restored = try JSONDecoder().decode(WatchLocalState.self, from: JSONEncoder().encode(watch))
        #expect(restored.sourceID == watch.sourceID)
        #expect(restored.pending == [latest])
        #expect(restored.sequence == 2)
    }

    @Test func oldSnapshotsCannotRollBackNewerStateOrClearPendingChanges() throws {
        var watch = WatchLocalState()
        let initial = state(revision: 2)
        watch.receive(initial)
        let change = try toggle(&watch)
        let old = WatchSyncState(phoneID: initial.phoneID, revision: 1, snapshot: initial.snapshot,
                                 receipts: [WatchChangeReceipt(id: change.id, status: .accepted)])
        let didReceive = watch.receive(old)
        #expect(!didReceive)
        #expect(watch.pending == [change])
        #expect(watch.snapshot(for: now).completedCount == 1)
    }

    @Test func changedPriorityOrPhoneDiscardsIncompatiblePendingChanges() throws {
        var watch = WatchLocalState()
        let initial = state(revision: 1)
        watch.receive(initial)
        _ = try toggle(&watch)
        watch.receive(WatchSyncState(phoneID: initial.phoneID, revision: 2,
                                    snapshot: TodayWidgetSnapshot(day: now), receipts: []))
        #expect(watch.pending.isEmpty)
        let emptyToggle = watch.toggle(slot: 1, date: now)
        #expect(emptyToggle == nil)
        watch.receive(state(revision: 1))
        #expect(watch.received?.revision == 1)
    }

    @Test func nextDayIsBlankAndCannotToggleYesterday() throws {
        var watch = WatchLocalState()
        watch.receive(state(revision: 1))
        _ = try toggle(&watch)
        let tomorrow = try #require(Calendar.current.date(byAdding: .day, value: 1, to: now))
        #expect(watch.snapshot(for: tomorrow).completedCount == 0)
        #expect(watch.snapshot(for: tomorrow).priorities.allSatisfy { $0.title.isEmpty })
        #expect(watch.currentPending(for: tomorrow).isEmpty)
        let tomorrowToggle = watch.toggle(slot: 1, date: tomorrow)
        #expect(tomorrowToggle == nil)
    }

    @Test func acknowledgingAnOlderToggleKeepsTheLatestOptimisticValue() throws {
        var watch = WatchLocalState()
        let initial = state(revision: 1)
        watch.receive(initial)
        let first = try toggle(&watch)
        let latest = try toggle(&watch)
        let completed = TodayWidgetSnapshot(day: now, priorities: [
            WidgetPriority(slot: 1, title: "Build", isCompleted: true)
        ])
        watch.receive(WatchSyncState(phoneID: initial.phoneID, revision: 2, snapshot: completed,
                                    receipts: [WatchChangeReceipt(id: first.id, status: .accepted)]))
        #expect(watch.pending == [latest])
        #expect(watch.snapshot(for: now).completedCount == 0)
    }

    @Test func differentPhoneDiscardsOldPendingCommandsEvenWithALowerRevision() throws {
        var watch = WatchLocalState()
        watch.receive(state(revision: 100))
        _ = try toggle(&watch)
        let otherPhone = state(revision: 1)
        watch.receive(otherPhone)
        #expect(watch.pending.isEmpty)
        #expect(watch.received?.phoneID == otherPhone.phoneID)
    }

    @Test func messagesRoundTripWithoutModelObjects() throws {
        var watch = WatchLocalState()
        watch.receive(state(revision: 1))
        let change = try toggle(&watch)
        let encoded = try JSONEncoder().encode(WatchSyncMessage.completion(change))
        let decoded = try JSONDecoder().decode(WatchSyncMessage.self, from: encoded)
        guard case .completion(let received) = decoded else {
            Issue.record("Expected completion message")
            return
        }
        #expect(received == change)
    }

    private func toggle(_ watch: inout WatchLocalState) throws -> WatchCompletionChange {
        let change = watch.toggle(slot: 1, date: now)
        return try #require(change)
    }

    private func state(revision: Int) -> WatchSyncState {
        WatchSyncState(phoneID: UUID(), revision: revision, snapshot: TodayWidgetSnapshot(day: now, priorities: [
            WidgetPriority(slot: 1, title: "Build", isCompleted: false)
        ]), receipts: [])
    }

    @MainActor
    private final class Fixture {
        let container: ModelContainer
        let context: ModelContext
        let defaults: UserDefaults
        let suite = "WatchSyncTests.\(UUID().uuidString)"
        let processor: WatchCommandProcessor
        let entry: DailyEntry

        init(day: Date) throws {
            container = try ModelContainer(for: DailyEntry.self, DailyTaskItem.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
            context = container.mainContext
            defaults = UserDefaults(suiteName: suite)!
            processor = WatchCommandProcessor(context: context, defaults: defaults)
            entry = DailyEntry(date: day)
            entry.sortedTasks[0].title = "  Build  "
            context.insert(entry)
            try context.save()
        }

        deinit { defaults.removePersistentDomain(forName: suite) }

        func change(day: Date? = nil, slot: Int = 1, title: String = "Build", sequence: Int = 1, phoneID: UUID? = nil) -> WatchCompletionChange {
            WatchCompletionChange(id: UUID(), phoneID: phoneID ?? processor.phoneID, sourceID: UUID(),
                                  sequence: sequence, day: day ?? entry.date, slot: slot,
                                  expectedTitle: title, isCompleted: true)
        }
    }
}
