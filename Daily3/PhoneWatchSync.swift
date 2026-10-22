import Foundation
import OSLog
import SwiftData
@preconcurrency import WatchConnectivity

@MainActor
final class PhoneWatchSync: NSObject, WCSessionDelegate {
    private let context: ModelContext
    private let processor: WatchCommandProcessor
    private let session: WCSession?
    private let logger = Logger(subsystem: "com.anayaydin.Daily3", category: "Watch")

    init(context: ModelContext) {
        self.context = context
        processor = WatchCommandProcessor(context: context)
        session = WCSession.isSupported() ? .default : nil
        super.init()
        session?.delegate = self
        session?.activate()
    }

    func publishCurrent() {
        guard let session, session.activationState == .activated,
              session.isPaired, session.isWatchAppInstalled else { return }
        do {
            try context.save()
            let message = WatchSyncMessage.state(try processor.makeState())
            let data = try JSONEncoder().encode(message)
            try session.updateApplicationContext([WatchSyncMessage.payloadKey: data])
            if session.isReachable {
                session.sendMessageData(data, replyHandler: nil, errorHandler: nil)
            }
        } catch {
            logger.error("Could not publish Watch state: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func handle(_ data: Data) -> Data {
        do {
            let message = try JSONDecoder().decode(WatchSyncMessage.self, from: data)
            switch message {
            case .requestSnapshot:
                try context.save()
            case .completion(let change):
                try processor.process(change)
                let snapshot = try processor.makeState().snapshot
                WidgetSync.publish(snapshot, context: context)
            default:
                return try JSONEncoder().encode(WatchSyncMessage.unavailable)
            }
            publishCurrent()
            return try JSONEncoder().encode(WatchSyncMessage.state(try processor.makeState()))
        } catch {
            logger.error("Could not process Watch request: \(error.localizedDescription, privacy: .public)")
            return (try? JSONEncoder().encode(WatchSyncMessage.unavailable)) ?? Data()
        }
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor [weak self] in self?.publishCurrent() }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor [weak self] in self?.publishCurrent() }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessageData messageData: Data, replyHandler: @escaping (Data) -> Void) {
        Task { @MainActor [weak self] in
            replyHandler(self?.handle(messageData) ?? Data())
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        guard let data = userInfo[WatchSyncMessage.payloadKey] as? Data else { return }
        Task { @MainActor [weak self] in _ = self?.handle(data) }
    }
}
