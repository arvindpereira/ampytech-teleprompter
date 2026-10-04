import Foundation
import Testing
import UIKit
@testable import Teleprompter

struct RemoteProtocolTests {
    @Test func commandRoundTrips() throws {
        let message = RemoteMessage.command(.seek, value: 0.42)
        let parsed = try #require(RemoteMessage.parseCommand(message))
        #expect(parsed.command == .seek)
        #expect(parsed.value == 0.42)

        let noValue = try #require(RemoteMessage.parseCommand(RemoteMessage.command(.togglePlay)))
        #expect(noValue.command == .togglePlay)
        #expect(noValue.value == nil)
    }

    @Test func unknownCommandIsIgnored() {
        #expect(RemoteMessage.parseCommand(["command": "selfDestruct"]) == nil)
        #expect(RemoteMessage.parseCommand([:]) == nil)
    }

    @Test func statusRoundTrips() {
        var status = RemoteStatus()
        status.isPrompterOpen = true
        status.scriptTitle = "Keynote"
        status.state = .countingDown
        status.countdown = 2
        status.speed = 80
        status.progress = 0.5
        status.isMirrored = true
        #expect(RemoteMessage.parseStatus(RemoteMessage.status(status)) == status)
    }
}

@MainActor
struct RemoteControlServiceTests {
    private func makeService() -> (RemoteControlService, SettingsStore) {
        let defaults = UserDefaults(suiteName: "RemoteControlServiceTests.\(UUID().uuidString)")!
        let store = SettingsStore(defaults: defaults)
        let service = RemoteControlService(settingsStore: store, defaults: defaults, activateSession: false)
        return (service, store)
    }

    private func makeController() -> (PrompterController, UIScrollView) {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 300, height: 400))
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.contentSize = CGSize(width: 300, height: 2400)
        let controller = PrompterController()
        controller.scrollView = scrollView
        controller.countdownSeconds = 0
        return (controller, scrollView)
    }

    @Test func speedAndMirrorWorkWithoutAScriptOpen() {
        let (service, store) = makeService()
        let speed = store.settings.scrollSpeed

        service.handle(.speedUp)
        #expect(store.settings.scrollSpeed == speed + PrompterSettings.speedStep)
        service.handle(.slowDown)
        service.handle(.slowDown)
        #expect(store.settings.scrollSpeed == speed - PrompterSettings.speedStep)

        service.handle(.toggleMirror)
        #expect(store.settings.mirrorHorizontal)
        #expect(service.currentStatus.isMirrored)
        #expect(!service.currentStatus.isPrompterOpen)
    }

    @Test func playbackCommandsDriveTheAttachedPrompter() {
        let (service, _) = makeService()
        let (controller, scrollView) = makeController()
        service.attach(controller, scriptTitle: "Keynote")

        service.handle(.togglePlay)
        #expect(controller.state == .playing)
        #expect(service.currentStatus.state == .playing)
        #expect(service.currentStatus.scriptTitle == "Keynote")

        service.handle(.togglePlay)
        #expect(controller.state == .paused)

        service.handle(.seek, value: 0.5)
        #expect(abs(controller.progress - 0.5) < 0.01)
        #expect(abs(scrollView.prompterScrollFraction - 0.5) < 0.01)

        let before = scrollView.contentOffset.y
        service.handle(.jumpForward)
        #expect(scrollView.contentOffset.y > before)

        service.handle(.restart)
        #expect(controller.state == .idle)
        #expect(controller.progress == 0)

        service.detach(controller)
        #expect(!service.currentStatus.isPrompterOpen)
    }

    @Test func disabledRemoteIgnoresCommands() {
        let (service, store) = makeService()
        let (controller, _) = makeController()
        service.attach(controller, scriptTitle: "Keynote")
        service.isEnabled = false

        service.handle(.togglePlay)
        service.handle(.speedUp)
        #expect(controller.state == .idle)
        #expect(store.settings.scrollSpeed == PrompterSettings().scrollSpeed)
        #expect(!service.currentStatus.isEnabled)
        #expect(!service.currentStatus.isPrompterOpen)
    }
}
