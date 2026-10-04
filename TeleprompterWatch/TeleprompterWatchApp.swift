import SwiftUI

@main
struct TeleprompterWatchApp: App {
    @State private var model = WatchRemoteModel()

    var body: some Scene {
        WindowGroup {
            RemoteView()
                .environment(model)
        }
    }
}
