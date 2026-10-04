import Testing
import UIKit
@testable import Teleprompter

@MainActor
struct PrompterControllerTests {
    @Test func startWithoutCountdownPlaysImmediately() {
        let controller = PrompterController()
        controller.countdownSeconds = 0
        controller.start()
        #expect(controller.state == .playing)

        controller.togglePlayPause()
        #expect(controller.state == .paused)
    }

    @Test func startWithCountdownCountsDownThenPlays() async throws {
        let controller = PrompterController()
        controller.countdownSeconds = 2
        controller.start()
        #expect(controller.state == .countingDown(2))

        try await Task.sleep(for: .seconds(1.2))
        #expect(controller.state == .countingDown(1))

        try await Task.sleep(for: .seconds(1.2))
        #expect(controller.state == .playing)
        controller.pause()
    }

    @Test func pausingDuringCountdownCancelsIt() async throws {
        let controller = PrompterController()
        controller.countdownSeconds = 1
        controller.start()
        controller.pause()
        #expect(controller.state == .paused)

        try await Task.sleep(for: .seconds(1.3))
        #expect(controller.state == .paused)
    }

    @Test func autoScrollAdvancesAndFinishes() async throws {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 300, height: 400))
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.contentSize = CGSize(width: 300, height: 450)
        let controller = PrompterController()
        controller.scrollView = scrollView
        controller.countdownSeconds = 0
        controller.speed = 400

        controller.start()
        try await Task.sleep(for: .seconds(0.5))

        #expect(controller.state == .finished)
        #expect(scrollView.contentOffset.y == scrollView.prompterMaxOffset)
        #expect(controller.progress == 1)

        controller.reset()
        #expect(controller.state == .idle)
        #expect(scrollView.contentOffset.y == scrollView.prompterMinOffset)
        #expect(controller.progress == 0)
    }
}
