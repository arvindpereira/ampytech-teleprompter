import Foundation
import Observation
import WatchConnectivity

/// The watch's side of the link: sends commands to the iPhone and tracks the status it reports back.
@MainActor
@Observable
final class WatchRemoteModel: NSObject {
    private(set) var status: RemoteStatus?
    private(set) var isReachable = false

    @ObservationIgnored private let session: WCSession? = WCSession.isSupported() ? .default : nil

    override init() {
        super.init()
        session?.delegate = self
        session?.activate()
    }

    func send(_ command: RemoteCommand, value: Double? = nil) {
        guard let session, session.activationState == .activated, session.isReachable else { return }
        session.sendMessage(RemoteMessage.command(command, value: value), replyHandler: nil) { _ in
            Task { @MainActor in self.refreshReachability() }
        }
    }

    private func apply(_ message: [String: Any]) {
        if let status = RemoteMessage.parseStatus(message) {
            self.status = status
        }
    }

    private func refreshReachability() {
        isReachable = session?.isReachable ?? false
    }
}

extension WatchRemoteModel: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        let context = session.receivedApplicationContext
        Task { @MainActor in
            self.apply(context)
            self.refreshReachability()
            self.send(.requestStatus)
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.refreshReachability()
            if self.isReachable { self.send(.requestStatus) }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in self.apply(message) }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in self.apply(applicationContext) }
    }
}
