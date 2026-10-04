import Foundation
import Observation
import WatchConnectivity

/// Receives commands from the Apple Watch remote and keeps the watch updated with the prompter's status.
@MainActor
@Observable
final class RemoteControlService: NSObject {
    var isEnabled: Bool {
        didSet {
            guard isEnabled != oldValue else { return }
            defaults.set(isEnabled, forKey: Self.enabledKey)
            pushStatus(force: true)
        }
    }

    private(set) var isPaired = false
    private(set) var isWatchAppInstalled = false
    private(set) var isReachable = false

    var statusDescription: String {
        guard WCSession.isSupported() else { return String(localized: "Not supported") }
        if !isPaired { return String(localized: "No Apple Watch paired") }
        if !isWatchAppInstalled { return String(localized: "Watch app not installed") }
        return isReachable ? String(localized: "Connected") : String(localized: "Open the app on your watch")
    }

    @ObservationIgnored private let settingsStore: SettingsStore
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let session: WCSession?
    @ObservationIgnored private weak var controller: PrompterController?
    @ObservationIgnored private var scriptTitle = ""
    @ObservationIgnored private var lastSentStatus: RemoteStatus?
    @ObservationIgnored private var lastContextStatus: RemoteStatus?
    @ObservationIgnored private var statusLoop: Task<Void, Never>?

    static let enabledKey = "watchRemoteEnabled"

    init(settingsStore: SettingsStore, defaults: UserDefaults = .standard, activateSession: Bool = true) {
        self.settingsStore = settingsStore
        self.defaults = defaults
        self.isEnabled = defaults.object(forKey: Self.enabledKey) as? Bool ?? true
        self.session = activateSession && WCSession.isSupported() ? WCSession.default : nil
        super.init()
        session?.delegate = self
        session?.activate()
    }

    // MARK: - Prompter lifecycle

    func attach(_ controller: PrompterController, scriptTitle: String) {
        self.controller = controller
        self.scriptTitle = scriptTitle
        startStatusLoop()
    }

    func detach(_ controller: PrompterController) {
        guard self.controller === controller else { return }
        self.controller = nil
        scriptTitle = ""
        statusLoop?.cancel()
        statusLoop = nil
        pushStatus(force: true)
    }

    // MARK: - Commands

    func handle(_ command: RemoteCommand, value: Double? = nil) {
        guard isEnabled || command == .requestStatus else { return }
        switch command {
        case .togglePlay: controller?.togglePlayPause()
        case .speedUp: settingsStore.settings.adjustSpeed(by: PrompterSettings.speedStep)
        case .slowDown: settingsStore.settings.adjustSpeed(by: -PrompterSettings.speedStep)
        case .jumpBack: controller?.jump(byScreens: -0.33)
        case .jumpForward: controller?.jump(byScreens: 0.33)
        case .toggleMirror: settingsStore.settings.mirrorHorizontal.toggle()
        case .restart: controller?.reset()
        case .seek: if let value { controller?.seek(toFraction: value) }
        case .requestStatus: break
        }
        pushStatus(force: true)
    }

    var currentStatus: RemoteStatus {
        var status = RemoteStatus()
        status.isEnabled = isEnabled
        status.speed = settingsStore.settings.scrollSpeed
        status.isMirrored = settingsStore.settings.mirrorHorizontal
        guard isEnabled, let controller else { return status }
        status.isPrompterOpen = true
        status.scriptTitle = scriptTitle
        status.progress = controller.progress
        switch controller.state {
        case .idle: status.state = .idle
        case .countingDown(let n):
            status.state = .countingDown
            status.countdown = n
        case .playing: status.state = .playing
        case .paused: status.state = .paused
        case .finished: status.state = .finished
        }
        return status
    }

    // MARK: - Status updates

    /// While a script is open, poll the prompter a few times a second and send the watch anything that changed.
    private func startStatusLoop() {
        statusLoop?.cancel()
        statusLoop = Task { [weak self] in
            while !Task.isCancelled {
                self?.pushStatus()
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
    }

    private func pushStatus(force: Bool = false) {
        guard let session, session.activationState == .activated, session.isPaired, session.isWatchAppInstalled else {
            return
        }
        let status = currentStatus
        if session.isReachable, force || status != lastSentStatus {
            session.sendMessage(RemoteMessage.status(status), replyHandler: nil, errorHandler: nil)
            lastSentStatus = status
        }
        // Application context reaches the watch even when its app isn't running, so it's
        // up to date on launch. It's rate-limited by the system, so skip progress-only changes.
        if force || status.withoutProgress != lastContextStatus?.withoutProgress {
            try? session.updateApplicationContext(RemoteMessage.status(status))
            lastContextStatus = status
        }
    }

    private func refreshSessionState() {
        guard let session else { return }
        isPaired = session.isPaired
        isWatchAppInstalled = session.isWatchAppInstalled
        isReachable = session.isReachable
    }
}

// WCSession calls its delegate on a background queue; hop to the main actor for everything.
extension RemoteControlService: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            self.refreshSessionState()
            self.pushStatus(force: true)
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // The user switched to a different watch; reconnect to the new one.
        session.activate()
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        // Fires when the watch app is installed or removed while the phone app is running.
        Task { @MainActor in
            self.refreshSessionState()
            self.pushStatus(force: true)
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.refreshSessionState()
            self.pushStatus(force: true)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let parsed = RemoteMessage.parseCommand(message) else { return }
        Task { @MainActor in self.handle(parsed.command, value: parsed.value) }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        guard let parsed = RemoteMessage.parseCommand(message) else {
            replyHandler([:])
            return
        }
        Task { @MainActor in
            self.handle(parsed.command, value: parsed.value)
            replyHandler(RemoteMessage.status(self.currentStatus))
        }
    }
}
