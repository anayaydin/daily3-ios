import Foundation
import SwiftData

@MainActor
final class WatchCommandProcessor {
    let phoneID: UUID
    private let context: ModelContext
    private let defaults: UserDefaults
    private var ledger: Ledger

    private struct Ledger: Codable {
        var day: Date
        var sequences: [String: Int] = [:]
        var receipts: [WatchChangeReceipt] = []
    }

    init(context: ModelContext, defaults: UserDefaults = .standard) {
        self.context = context
        self.defaults = defaults
        if let stored = defaults.string(forKey: "watch.phoneID"), let id = UUID(uuidString: stored) {
            phoneID = id
        } else {
            let id = UUID()
            phoneID = id
            defaults.set(id.uuidString, forKey: "watch.phoneID")
        }
        ledger = defaults.data(forKey: "watch.ledger")
            .flatMap { try? JSONDecoder().decode(Ledger.self, from: $0) }
            ?? Ledger(day: .now)
    }

    func makeState(now: Date = .now) throws -> WatchSyncState {
        resetLedgerIfNeeded(now)
        let revision = defaults.integer(forKey: "watch.revision") + 1
        defaults.set(revision, forKey: "watch.revision")
        return WatchSyncState(
            phoneID: phoneID, revision: revision,
            snapshot: TodayWidgetSnapshot(entry: try entry(for: now), date: now),
            receipts: ledger.receipts
        )
    }

    @discardableResult
    func process(_ change: WatchCompletionChange, now: Date = .now) throws -> WatchChangeReceipt {
        resetLedgerIfNeeded(now)
        let key = "\(change.sourceID.uuidString):\(change.slot)"
        let status: WatchChangeStatus

        if change.phoneID != phoneID {
            status = .differentPhone
        } else if !Calendar.current.isDate(change.day, inSameDayAs: now) {
            status = .differentDay
        } else if !(1...3).contains(change.slot) || change.sequence <= 0 {
            status = .invalid
        } else if change.sequence <= (ledger.sequences[key] ?? 0) {
            status = .outdated
        } else {
            if let entry = try entry(for: now),
               let task = entry.tasks.first(where: { $0.slot == change.slot }),
               task.isFilled,
               task.title.trimmingCharacters(in: .whitespacesAndNewlines) == change.expectedTitle {
                let previous = task.isCompleted
                task.isCompleted = change.isCompleted
                do {
                    try context.save()
                } catch {
                    task.isCompleted = previous
                    throw error
                }
                status = .accepted
            } else {
                status = .differentPriority
            }
            // Ignore retries or delayed older changes even after app relaunch.
            ledger.sequences[key] = change.sequence
        }

        let receipt = WatchChangeReceipt(id: change.id, status: status)
        ledger.receipts.removeAll { $0.id == change.id }
        ledger.receipts.append(receipt)
        ledger.receipts = Array(ledger.receipts.suffix(64))
        defaults.set(try JSONEncoder().encode(ledger), forKey: "watch.ledger")
        return receipt
    }

    private func entry(for date: Date) throws -> DailyEntry? {
        let start = Calendar.current.startOfDay(for: date)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        let descriptor = FetchDescriptor<DailyEntry>(predicate: #Predicate {
            $0.date >= start && $0.date < end
        })
        return try context.fetch(descriptor).first
    }

    private func resetLedgerIfNeeded(_ date: Date) {
        if !Calendar.current.isDate(ledger.day, inSameDayAs: date) {
            ledger = Ledger(day: Calendar.current.startOfDay(for: date))
        }
    }
}
