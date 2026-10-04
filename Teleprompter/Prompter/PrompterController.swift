import UIKit
import Observation

/// Drives the auto-scroll: countdown, play/pause, and per-frame scrolling of the prompter's scroll view.
@MainActor
@Observable
final class PrompterController {
    enum State: Equatable {
        case idle
        case countingDown(Int)
        case playing
        case paused
        case finished
    }

    private(set) var state: State = .idle
    /// Fraction of the script that has scrolled past the reading line (0...1).
    private(set) var progress: Double = 0

    /// Points per second.
    var speed: Double = 60
    var countdownSeconds = 3

    var isRunning: Bool {
        switch state {
        case .playing, .countingDown: true
        default: false
        }
    }

    @ObservationIgnored weak var scrollView: UIScrollView?
    /// True while the user's finger is dragging the text, or it is still decelerating.
    @ObservationIgnored private(set) var isUserInteracting = false
    @ObservationIgnored private var displayLink: CADisplayLink?
    @ObservationIgnored private var lastTimestamp: CFTimeInterval?
    @ObservationIgnored private var countdownTask: Task<Void, Never>?
    /// Sub-pixel accurate offset; UIKit may round contentOffset, which would make slow speeds stutter.
    @ObservationIgnored private var exactOffset: CGFloat = 0

    // MARK: - Playback

    func togglePlayPause() {
        isRunning ? pause() : start()
    }

    func start() {
        if state == .finished { scrollToTop() }
        countdownTask?.cancel()

        let count = countdownSeconds
        guard count > 0 else {
            beginScrolling()
            return
        }
        // Set synchronously so an immediate pause() sees that the countdown is running.
        state = .countingDown(count)
        countdownTask = Task { [weak self] in
            var remaining = count
            while remaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard let self, !Task.isCancelled else { return }
                remaining -= 1
                if remaining > 0 {
                    self.state = .countingDown(remaining)
                } else {
                    self.beginScrolling()
                }
            }
        }
    }

    func pause() {
        let wasRunning = isRunning
        cancelCountdown()
        stopDisplayLink()
        if wasRunning { state = .paused }
    }

    /// Stops playback and jumps back to the beginning of the script.
    func reset() {
        cancelCountdown()
        stopDisplayLink()
        scrollToTop()
        state = .idle
    }

    /// Jumps forward (positive) or back (negative) by a fraction of the visible height.
    func jump(byScreens screens: CGFloat) {
        guard let scrollView else { return }
        let target = (scrollView.contentOffset.y + scrollView.bounds.height * screens)
            .clamped(to: scrollView.prompterMinOffset...scrollView.prompterMaxOffset)
        exactOffset = target
        scrollView.setContentOffset(CGPoint(x: 0, y: target), animated: true)
        if state == .finished, target < scrollView.prompterMaxOffset { state = .paused }
        updateProgress()
    }

    /// Scrolls to a fraction (0...1) of the script. Auto-scroll, if running, continues from there.
    func seek(toFraction fraction: Double) {
        guard let scrollView else { return }
        let minY = scrollView.prompterMinOffset
        let maxY = scrollView.prompterMaxOffset
        exactOffset = minY + CGFloat(fraction.clamped(to: 0...1)) * (maxY - minY)
        scrollView.setContentOffset(CGPoint(x: 0, y: exactOffset), animated: false)
        if state == .finished, exactOffset < maxY - 1 { state = .paused }
        updateProgress()
    }

    // MARK: - Scroll view callbacks

    func userInteractionBegan() {
        isUserInteracting = true
    }

    func userInteractionEnded() {
        isUserInteracting = false
        syncFromScrollView()
        if state == .finished, let scrollView, exactOffset < scrollView.prompterMaxOffset - 1 {
            state = .paused
        }
    }

    /// Re-reads the scroll position after the user scrolls or the layout changes (rotation, font size...).
    func syncFromScrollView() {
        guard let scrollView else { return }
        exactOffset = scrollView.contentOffset.y
        updateProgress()
    }

    // MARK: - Private

    private func beginScrolling() {
        countdownTask = nil
        state = .playing
        syncFromScrollView()
        startDisplayLink()
    }

    private func cancelCountdown() {
        countdownTask?.cancel()
        countdownTask = nil
    }

    private func startDisplayLink() {
        stopDisplayLink()
        lastTimestamp = nil
        let target = DisplayLinkTarget { [weak self] link in self?.tick(link) }
        let link = CADisplayLink(target: target, selector: #selector(DisplayLinkTarget.fire(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
        lastTimestamp = nil
    }

    private func tick(_ link: CADisplayLink) {
        defer { lastTimestamp = link.timestamp }
        guard state == .playing, let scrollView, let last = lastTimestamp else { return }
        guard !isUserInteracting else { return }

        // Cap dt so a hitch (or returning from background) doesn't cause a big jump.
        let dt = min(link.timestamp - last, 0.1)
        let maxOffset = scrollView.prompterMaxOffset
        exactOffset = min(exactOffset + CGFloat(speed * dt), maxOffset)
        scrollView.contentOffset = CGPoint(x: scrollView.contentOffset.x, y: exactOffset)
        updateProgress()

        if exactOffset >= maxOffset {
            stopDisplayLink()
            state = .finished
        }
    }

    private func scrollToTop() {
        guard let scrollView else {
            progress = 0
            return
        }
        exactOffset = scrollView.prompterMinOffset
        scrollView.setContentOffset(CGPoint(x: 0, y: exactOffset), animated: false)
        progress = 0
    }

    private func updateProgress() {
        guard let scrollView else { return }
        let newValue = Double(scrollView.prompterScrollFraction)
        // Avoid invalidating SwiftUI views every frame for imperceptible changes.
        if abs(newValue - progress) > 0.001 || newValue == 0 || newValue == 1 {
            progress = newValue
        }
    }
}

/// CADisplayLink retains its target strongly; this indirection avoids a retain cycle with the controller.
private final class DisplayLinkTarget: NSObject {
    let handler: @MainActor (CADisplayLink) -> Void

    init(handler: @escaping @MainActor (CADisplayLink) -> Void) {
        self.handler = handler
    }

    @objc func fire(_ link: CADisplayLink) {
        MainActor.assumeIsolated { handler(link) }
    }
}

extension UIScrollView {
    var prompterMinOffset: CGFloat { -adjustedContentInset.top }

    var prompterMaxOffset: CGFloat {
        max(prompterMinOffset, contentSize.height + adjustedContentInset.bottom - bounds.height)
    }

    var prompterScrollFraction: CGFloat {
        let range = prompterMaxOffset - prompterMinOffset
        guard range > 0 else { return 0 }
        return ((contentOffset.y - prompterMinOffset) / range).clamped(to: 0...1)
    }
}
