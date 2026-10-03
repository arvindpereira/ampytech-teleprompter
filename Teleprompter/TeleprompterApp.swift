import SwiftUI
import SwiftData

@main
struct TeleprompterApp: App {
    @State private var settingsStore = SettingsStore()

    var body: some Scene {
        WindowGroup {
            ScriptListView()
                .environment(settingsStore)
        }
        .modelContainer(for: Script.self)
    }
}
