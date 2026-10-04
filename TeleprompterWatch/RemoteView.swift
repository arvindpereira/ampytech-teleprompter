import SwiftUI
import WatchKit

/// The remote: tap to play/pause, swipe up/down for speed, swipe left/right to jump,
/// and turn the Digital Crown to scroll to any point in the script.
struct RemoteView: View {
    @Environment(WatchRemoteModel.self) private var model

    var body: some View {
        if let status = model.status, model.isReachable {
            if !status.isEnabled {
                MessageView(
                    systemImage: "applewatch.slash",
                    text: "Turn on Apple Watch Remote in the iPhone app's Settings."
                )
            } else {
                RemoteControlsView(status: status)
            }
        } else {
            MessageView(systemImage: "iphone", text: "Open Teleprompter on your iPhone.")
        }
    }
}

private struct RemoteControlsView: View {
    let status: RemoteStatus

    @Environment(WatchRemoteModel.self) private var model
    @State private var crownValue = 0.0
    @State private var isCrowning = false
    @State private var lastSeekSent = Date.distantPast
    @State private var feedback: Feedback?
    @State private var feedbackTask: Task<Void, Never>?

    private struct Feedback: Equatable {
        var systemImage: String
        var text: String
    }

    private var displayedProgress: Double {
        isCrowning ? crownValue : status.progress
    }

    var body: some View {
        VStack(spacing: 6) {
            Text(status.isPrompterOpen ? status.scriptTitle : String(localized: "Open a script on iPhone"))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            ZStack {
                Circle()
                    .stroke(.white.opacity(0.15), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: displayedProgress)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.25), value: displayedProgress)
                playButton
                    .padding(10)
            }
            .frame(maxWidth: 110, maxHeight: 110)

            HStack {
                Button {
                    send(.toggleMirror, haptic: .click)
                } label: {
                    Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right.fill")
                        .foregroundStyle(status.isMirrored ? Color.accentColor : .white)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(status.isMirrored ? "Mirroring on" : "Mirroring off")

                Spacer()

                if let feedback {
                    Label(feedback.text, systemImage: feedback.systemImage)
                        .font(.caption2)
                        .lineLimit(1)
                        .transition(.opacity)
                } else {
                    Text("\(Int(displayedProgress * 100))%")
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Label("\(Int(status.speed))", systemImage: "speedometer")
                    .font(.caption2)
                    .monospacedDigit()
                    .labelStyle(.titleAndIcon)
                    .accessibilityLabel("Speed \(Int(status.speed))")
            }
            .padding(.horizontal, 4)
        }
        .contentShape(Rectangle())
        .simultaneousGesture(DragGesture(minimumDistance: 20).onEnded(handleSwipe))
        .focusable(status.isPrompterOpen)
        .digitalCrownRotation(
            detent: $crownValue,
            from: 0,
            through: 1,
            by: 0.01,
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: true,
            onChange: crownChanged,
            onIdle: crownIdle
        )
        .onAppear { crownValue = status.progress }
        .onChange(of: status.progress) { _, progress in
            if !isCrowning { crownValue = progress }
        }
    }

    @ViewBuilder
    private var playButton: some View {
        let button = Button {
            send(.togglePlay, haptic: status.isRunning ? .stop : .start)
        } label: {
            Group {
                if status.state == .countingDown {
                    Text("\(status.countdown)")
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .contentTransition(.numericText(countsDown: true))
                } else {
                    Image(systemName: status.isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 30, weight: .bold))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Circle().fill(status.isPrompterOpen ? .white : .gray.opacity(0.4)))
            .foregroundStyle(.black)
        }
        .buttonStyle(.plain)
        .disabled(!status.isPrompterOpen)
        .accessibilityLabel(status.isRunning ? "Pause" : "Play")

        // Double-tap (pinch) on supported watches toggles playback without touching the screen.
        if #available(watchOS 11.0, *) {
            button.handGestureShortcut(.primaryAction)
        } else {
            button
        }
    }

    // MARK: - Gestures

    private func handleSwipe(_ value: DragGesture.Value) {
        let dx = value.translation.width
        let dy = value.translation.height
        if abs(dx) > abs(dy) {
            // Swipe left moves forward through the script, like turning a page.
            if dx < 0 {
                send(.jumpForward, haptic: .directionUp, feedback: Feedback(systemImage: "forward.fill", text: "Forward"))
            } else {
                send(.jumpBack, haptic: .directionDown, feedback: Feedback(systemImage: "backward.fill", text: "Back"))
            }
        } else if dy < 0 {
            send(.speedUp, haptic: .directionUp, feedback: Feedback(systemImage: "hare.fill", text: "Faster"))
        } else {
            send(.slowDown, haptic: .directionDown, feedback: Feedback(systemImage: "tortoise.fill", text: "Slower"))
        }
    }

    private func crownChanged(_ event: DigitalCrownEvent) {
        guard status.isPrompterOpen else { return }
        isCrowning = true
        // Throttle so a fast spin doesn't flood the connection.
        let now = Date.now
        if now.timeIntervalSince(lastSeekSent) > 0.08 {
            model.send(.seek, value: event.offset)
            lastSeekSent = now
        }
    }

    private func crownIdle() {
        guard isCrowning else { return }
        model.send(.seek, value: crownValue)
        // Give the phone a moment to report the new position before following its progress again.
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            isCrowning = false
        }
    }

    private func send(_ command: RemoteCommand, haptic: WKHapticType, feedback: Feedback? = nil) {
        model.send(command)
        WKInterfaceDevice.current().play(haptic)
        guard let feedback else { return }
        feedbackTask?.cancel()
        withAnimation { self.feedback = feedback }
        feedbackTask = Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            withAnimation { self.feedback = nil }
        }
    }
}

private struct MessageView: View {
    let systemImage: String
    let text: LocalizedStringKey

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(text)
                .font(.footnote)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

#Preview {
    RemoteView()
        .environment(WatchRemoteModel())
}
