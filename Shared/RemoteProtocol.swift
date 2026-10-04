import Foundation

// Message format shared by the iPhone app and the Apple Watch remote.
// Messages travel over WatchConnectivity, which picks Bluetooth or Wi-Fi automatically.

enum RemoteCommand: String, Codable, CaseIterable {
    case togglePlay
    case speedUp
    case slowDown
    case jumpBack
    case jumpForward
    case toggleMirror
    case restart
    /// Scroll to a fraction (0...1) of the script; carries a `value`.
    case seek
    /// Ask the phone to send its current status.
    case requestStatus
}

enum RemotePlaybackState: String, Codable {
    case idle
    case countingDown
    case playing
    case paused
    case finished
}

/// Snapshot of the prompter, sent from the phone to the watch.
struct RemoteStatus: Codable, Equatable {
    /// False when the user has turned off the watch remote on the phone.
    var isEnabled = true
    /// True while a script is open in the prompter.
    var isPrompterOpen = false
    var scriptTitle = ""
    var state: RemotePlaybackState = .idle
    var countdown = 0
    var speed: Double = 0
    var progress: Double = 0
    var isMirrored = false

    var isRunning: Bool { state == .playing || state == .countingDown }

    /// The same status with progress excluded, used to decide when a change is worth a
    /// (rate-limited) application-context update rather than just a live message.
    var withoutProgress: RemoteStatus {
        var copy = self
        copy.progress = 0
        return copy
    }
}

enum RemoteMessage {
    private static let commandKey = "command"
    private static let valueKey = "value"
    private static let statusKey = "status"

    static func command(_ command: RemoteCommand, value: Double? = nil) -> [String: Any] {
        var message: [String: Any] = [commandKey: command.rawValue]
        if let value { message[valueKey] = value }
        return message
    }

    static func parseCommand(_ message: [String: Any]) -> (command: RemoteCommand, value: Double?)? {
        guard let raw = message[commandKey] as? String,
              let command = RemoteCommand(rawValue: raw) else { return nil }
        return (command, message[valueKey] as? Double)
    }

    static func status(_ status: RemoteStatus) -> [String: Any] {
        guard let data = try? JSONEncoder().encode(status) else { return [:] }
        return [statusKey: data]
    }

    static func parseStatus(_ message: [String: Any]) -> RemoteStatus? {
        guard let data = message[statusKey] as? Data else { return nil }
        return try? JSONDecoder().decode(RemoteStatus.self, from: data)
    }
}
