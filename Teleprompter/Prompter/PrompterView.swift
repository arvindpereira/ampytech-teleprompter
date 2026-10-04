import SwiftUI

/// Full-screen prompter: scrolling text, countdown, reading guide, and auto-hiding controls.
struct PrompterView: View {
    let script: Script

    @Environment(SettingsStore.self) private var store
    @Environment(RemoteControlService.self) private var remoteControl
    @Environment(\.dismiss) private var dismiss
    @State private var controller = PrompterController()
    @State private var showControls = true
    @State private var showSettings = false
    @State private var hideControlsTask: Task<Void, Never>?
    @FocusState private var isFocused: Bool

    var body: some View {
        let settings = store.settings

        ZStack {
            Color(settings.theme.backgroundColor)
                .ignoresSafeArea()

            PrompterTextView(
                text: script.body,
                settings: settings,
                controller: controller,
                onTap: toggleControls
            )
            .ignoresSafeArea(edges: .vertical)

            if settings.showReadingGuide {
                ReadingGuide(
                    position: settings.mirrorVertical
                        ? 1 - settings.readingGuidePosition
                        : settings.readingGuidePosition
                )
                .ignoresSafeArea(edges: .vertical)
                .allowsHitTesting(false)
            }

            if case .countingDown(let number) = controller.state {
                CountdownOverlay(number: number, settings: settings)
                    .allowsHitTesting(false)
            }

            if showControls {
                PrompterControls(
                    title: script.displayTitle,
                    controller: controller,
                    onClose: { dismiss() },
                    onSettings: { showSettings = true },
                    onInteraction: scheduleAutoHide
                )
                .transition(.opacity)
            }
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .focusable()
        .focused($isFocused)
        .focusEffectDisabled()
        .onKeyPress(keys: [.space, .return]) { _ in
            controller.togglePlayPause()
            return .handled
        }
        .onKeyPress(keys: [.upArrow, .downArrow]) { press in
            store.settings.adjustSpeed(by: press.key == .upArrow ? PrompterSettings.speedStep : -PrompterSettings.speedStep)
            return .handled
        }
        .onKeyPress(keys: [.leftArrow, .pageUp]) { _ in
            controller.jump(byScreens: -0.33)
            return .handled
        }
        .onKeyPress(keys: [.rightArrow, .pageDown]) { _ in
            controller.jump(byScreens: 0.33)
            return .handled
        }
        .onKeyPress("r") {
            controller.reset()
            return .handled
        }
        .onKeyPress(.escape) {
            dismiss()
            return .handled
        }
        .onChange(of: settings.scrollSpeed, initial: true) { _, speed in
            controller.speed = speed
        }
        .onChange(of: settings.countdownSeconds, initial: true) { _, seconds in
            controller.countdownSeconds = seconds
        }
        .onChange(of: controller.state) { _, state in
            switch state {
            case .playing:
                scheduleAutoHide()
            case .countingDown:
                hideControlsTask?.cancel()
                withAnimation { showControls = false }
            case .idle, .paused, .finished:
                hideControlsTask?.cancel()
                withAnimation { showControls = true }
            }
        }
        .onAppear {
            isFocused = true
            UIApplication.shared.isIdleTimerDisabled = true
            remoteControl.attach(controller, scriptTitle: script.displayTitle)
        }
        .onDisappear {
            controller.pause()
            remoteControl.detach(controller)
            hideControlsTask?.cancel()
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .sheet(isPresented: $showSettings, onDismiss: { isFocused = true }) {
            NavigationStack {
                SettingsView()
            }
            .presentationDetents([.medium, .large])
            .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        }
    }

    private func toggleControls() {
        withAnimation { showControls.toggle() }
        if showControls { scheduleAutoHide() }
    }

    private func scheduleAutoHide() {
        hideControlsTask?.cancel()
        guard controller.state == .playing else { return }
        hideControlsTask = Task {
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled, controller.state == .playing else { return }
            withAnimation { showControls = false }
        }
    }
}

/// Arrow markers at the reading line so the speaker knows where to look.
private struct ReadingGuide: View {
    let position: Double

    var body: some View {
        GeometryReader { proxy in
            let y = proxy.size.height * position
            ZStack {
                Rectangle()
                    .fill(Color.red.opacity(0.18))
                    .frame(height: 2)
                    .position(x: proxy.size.width / 2, y: y)
                Image(systemName: "arrowtriangle.right.fill")
                    .foregroundStyle(.red)
                    .position(x: 10, y: y)
                Image(systemName: "arrowtriangle.left.fill")
                    .foregroundStyle(.red)
                    .position(x: proxy.size.width - 10, y: y)
            }
        }
    }
}

private struct CountdownOverlay: View {
    let number: Int
    let settings: PrompterSettings

    var body: some View {
        ZStack {
            Color(settings.theme.backgroundColor).opacity(0.6)
                .ignoresSafeArea()
            Text("\(number)")
                .font(.system(size: 220, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color(settings.theme.textColor))
                .id(number)
                .transition(.scale(scale: 1.6).combined(with: .opacity))
        }
        // The countdown is read through the same glass as the script, so mirror it too.
        .scaleEffect(x: settings.mirrorHorizontal ? -1 : 1, y: settings.mirrorVertical ? -1 : 1)
        .animation(.easeOut(duration: 0.35), value: number)
        .accessibilityLabel(Text("Starting in \(number)"))
    }
}
