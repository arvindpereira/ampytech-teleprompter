import SwiftUI
import SwiftData

@main
struct TeleprompterApp: App {
    @State private var settingsStore: SettingsStore
    @State private var remoteControl: RemoteControlService

    init() {
        let settingsStore = SettingsStore()
        _settingsStore = State(initialValue: settingsStore)
        _remoteControl = State(initialValue: RemoteControlService(settingsStore: settingsStore))
    }

    var body: some Scene {
        WindowGroup {
            ScriptListView()
                .environment(settingsStore)
                .environment(remoteControl)
        }
        .modelContainer(for: Script.self)
    }
}
