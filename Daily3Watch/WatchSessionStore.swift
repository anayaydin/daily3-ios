import Foundation
import Observation
@preconcurrency import WatchConnectivity

@MainActor
@Observable
final class WatchSessionStore: NSObject, WCSessionDelegate {
    private var local: WatchLocalState
    private let defaults: UserDefaults
    private let session = WCSession.default
    private(set) var isReachable = false
    private(set) var errorMessage: String?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        local = defaults.data(forKey: "watch.localState")
            .flatMap { try? JSONDecoder().decode(WatchLocalState.self, from: $0) }
            ?? WatchLocalState()
        super.init()
        session.delegate = self
        session.activate()
    }

    func snapshot(for date: Date) -> TodayWidgetSnapshot {
        local.snapshot(for: date)
    }

    func status(for date: Date) -> String {
        if let errorMessage { return errorMessage }
        if !local.currentPending(for: date).isEmpty { return "Sync pending" }
        guard let received = local.received,
              Calendar.current.isDate(received.snapshot.day, inSameDayAs: date) else {
            return "Open Daily 3 on iPhone"
        }
        return isReachable ? "Up to date" : "Saved on Watch"
    }

    func toggle(slot: Int) {
        let previous = local
        guard let change = local.toggle(slot: slot, date: .now) else { return }
        guard persist() else { local = previous; return }
        errorMessage = nil
        deliver(change)
    }

    func refresh() {
        guard session.activationState == .activated else { return }
        isReachable = session.isReachable
        if let data = session.receivedApplicationContext[WatchSyncMessage.payloadKey] as? Data {
            receive(data)
        }
        for change in local.currentPending(for: .now) { deliver(change) }
        if isReachable { send(.requestSnapshot) }
    }

    private func deliver(_ change: WatchCompletionChange) {
        guard session.activationState == .activated else { return }
        if session.isReachable {
            send(.completion(change), fallback: change)
        } else {
            queue(change)
        }
    }

    private func send(_ message: WatchSyncMessage, fallback: WatchCompletionChange? = nil) {
        guard let data = try? JSONEncoder().encode(message) else { return }
        session.sendMessageData(data) { [weak self] reply in
            Task { @MainActor in self?.receive(reply) }
        } errorHandler: { [weak self] _ in
            Task { @MainActor in
                self?.isReachable = false
                if let fallback { self?.queue(fallback) }
            }
        }
    }

    private func queue(_ change: WatchCompletionChange) {
        // Watch Connectivity background user-info transfers require real devices.
        #if !targetEnvironment(simulator)
        let alreadyQueued = session.outstandingUserInfoTransfers.contains { transfer in
            guard let data = transfer.userInfo[WatchSyncMessage.payloadKey] as? Data,
                  let message = try? JSONDecoder().decode(WatchSyncMessage.self, from: data),
                  case .completion(let queued) = message else { return false }
            return queued.id == change.id
        }
        guard !alreadyQueued, let data = try? JSONEncoder().encode(WatchSyncMessage.completion(change)) else { return }
        session.transferUserInfo([WatchSyncMessage.payloadKey: data])
        #endif
    }

    private func receive(_ data: Data) {
        guard let message = try? JSONDecoder().decode(WatchSyncMessage.self, from: data) else { return }
        switch message {
        case .state(let state):
            let pendingIDs = Set(local.pending.map(\.id))
            let rejected = state.receipts.contains {
                pendingIDs.contains($0.id) && $0.status != .accepted && $0.status != .outdated
            }
            guard local.receive(state) else { return }
            errorMessage = rejected ? "Priorities changed on iPhone. Review and try again." : nil
            _ = persist()
        case .unavailable:
            errorMessage = "The iPhone could not save this update."
        default:
            break
        }
    }

    @discardableResult
    private func persist() -> Bool {
        do {
            defaults.set(try JSONEncoder().encode(local), forKey: "watch.localState")
            return true
        } catch {
            errorMessage = "Changes could not be saved on Watch."
            return false
        }
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor [weak self] in self?.refresh() }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor [weak self] in self?.refresh() }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let data = applicationContext[WatchSyncMessage.payloadKey] as? Data else { return }
        Task { @MainActor [weak self] in self?.receive(data) }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessageData messageData: Data) {
        Task { @MainActor [weak self] in self?.receive(messageData) }
    }
}
