import Foundation

struct WatchCompletionChange: Codable, Equatable, Identifiable {
    let id: UUID
    let phoneID: UUID
    let sourceID: UUID
    let sequence: Int
    let day: Date
    let slot: Int
    let expectedTitle: String
    let isCompleted: Bool
}

enum WatchChangeStatus: String, Codable {
    case accepted
    case outdated
    case differentDay
    case differentPriority
    case differentPhone
    case invalid
}

struct WatchChangeReceipt: Codable, Equatable {
    let id: UUID
    let status: WatchChangeStatus
}

struct WatchSyncState: Codable, Equatable {
    let phoneID: UUID
    let revision: Int
    let snapshot: TodayWidgetSnapshot
    let receipts: [WatchChangeReceipt]
}

enum WatchSyncMessage: Codable {
    case requestSnapshot
    case completion(WatchCompletionChange)
    case state(WatchSyncState)
    case unavailable

    nonisolated static let payloadKey = "daily3.watch.data"
}

struct WatchLocalState: Codable {
    private(set) var sourceID = UUID()
    private(set) var sequence = 0
    private(set) var received: WatchSyncState?
    private(set) var pending: [WatchCompletionChange] = []

    func snapshot(for date: Date, calendar: Calendar = .current) -> TodayWidgetSnapshot {
        let base = received?.snapshot.forDay(date, calendar: calendar) ?? TodayWidgetSnapshot(day: date, calendar: calendar)
        let priorities = base.priorities.map { priority in
            let change = pending.last {
                $0.slot == priority.slot && $0.phoneID == received?.phoneID &&
                calendar.isDate($0.day, inSameDayAs: date) && $0.expectedTitle == priority.title
            }
            return WidgetPriority(slot: priority.slot, title: priority.title, isCompleted: change?.isCompleted ?? priority.isCompleted)
        }
        return TodayWidgetSnapshot(day: date, priorities: priorities, calendar: calendar)
    }

    func currentPending(for date: Date, calendar: Calendar = .current) -> [WatchCompletionChange] {
        pending.filter { calendar.isDate($0.day, inSameDayAs: date) }
    }

    mutating func toggle(slot: Int, date: Date, calendar: Calendar = .current) -> WatchCompletionChange? {
        guard let received, calendar.isDate(received.snapshot.day, inSameDayAs: date),
              let priority = snapshot(for: date, calendar: calendar).priorities.first(where: { $0.slot == slot }),
              !priority.title.isEmpty else { return nil }

        sequence += 1
        let change = WatchCompletionChange(
            id: UUID(), phoneID: received.phoneID, sourceID: sourceID,
            sequence: sequence, day: received.snapshot.day, slot: slot,
            expectedTitle: priority.title, isCompleted: !priority.isCompleted
        )
        pending.removeAll { $0.slot == slot || !calendar.isDate($0.day, inSameDayAs: date) }
        pending.append(change)
        return change
    }

    @discardableResult
    mutating func receive(_ state: WatchSyncState) -> Bool {
        if let received, received.phoneID == state.phoneID, state.revision <= received.revision {
            return false
        }
        let acknowledged = Set(state.receipts.map(\.id))
        pending.removeAll { change in
            change.phoneID != state.phoneID || acknowledged.contains(change.id) ||
            change.day != state.snapshot.day ||
            !state.snapshot.priorities.contains { $0.slot == change.slot && $0.title == change.expectedTitle }
        }
        received = state
        return true
    }
}
