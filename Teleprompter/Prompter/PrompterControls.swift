import SwiftUI

struct PrompterControls: View {
    let title: String
    let controller: PrompterController
    var onClose: () -> Void
    var onSettings: () -> Void
    /// Called whenever the user touches a control, so auto-hide can be postponed.
    var onInteraction: () -> Void

    @Environment(SettingsStore.self) private var store

    var body: some View {
        @Bindable var store = store

        VStack(spacing: 0) {
            VStack(spacing: 8) {
                HStack {
                    iconButton("xmark", label: "Close", action: onClose)
                    Spacer()
                    Text(title)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    iconButton("gearshape", label: "Settings", action: onSettings)
                }
                ProgressView(value: controller.progress)
                    .tint(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal)
            .frame(maxWidth: 600)

            Spacer(minLength: 0)

            VStack(spacing: 12) {
                HStack(spacing: 16) {
                    iconButton("backward.end.fill", label: "Restart") {
                        controller.reset()
                    }
                    iconButton("textformat.size.smaller", label: "Smaller text") {
                        store.settings.adjustFontSize(by: -PrompterSettings.fontSizeStep)
                    }

                    Button {
                        controller.togglePlayPause()
                        onInteraction()
                    } label: {
                        Image(systemName: controller.isRunning ? "pause.fill" : "play.fill")
                            .font(.title)
                            .frame(width: 64, height: 64)
                            .background(Circle().fill(.white))
                            .foregroundStyle(.black)
                    }
                    .accessibilityLabel(controller.isRunning ? "Pause" : "Play")

                    iconButton("textformat.size.larger", label: "Larger text") {
                        store.settings.adjustFontSize(by: PrompterSettings.fontSizeStep)
                    }
                    iconButton(
                        "arrow.left.and.right.righttriangle.left.righttriangle.right.fill",
                        label: "Mirror",
                        isOn: store.settings.mirrorHorizontal
                    ) {
                        store.settings.mirrorHorizontal.toggle()
                    }
                }

                HStack(spacing: 10) {
                    Image(systemName: "tortoise.fill")
                        .accessibilityHidden(true)
                    Slider(
                        value: $store.settings.scrollSpeed,
                        in: PrompterSettings.speedRange,
                        step: 5
                    ) {
                        Text("Speed")
                    } onEditingChanged: { _ in
                        onInteraction()
                    }
                    Image(systemName: "hare.fill")
                        .accessibilityHidden(true)
                    Text("\(Int(store.settings.scrollSpeed))")
                        .monospacedDigit()
                        .frame(minWidth: 36, alignment: .trailing)
                }
                .font(.subheadline)
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
            .padding(.horizontal)
            .frame(maxWidth: 600)
        }
        .padding(.vertical, 8)
        .foregroundStyle(.white)
        .tint(.white)
        .environment(\.colorScheme, .dark)
    }

    private func iconButton(
        _ systemName: String,
        label: LocalizedStringKey,
        isOn: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            action()
            onInteraction()
        } label: {
            Image(systemName: systemName)
                .font(.title3.weight(.semibold))
                .frame(width: 44, height: 44)
                .background(isOn ? Color.white.opacity(0.25) : .clear, in: Circle())
        }
        .accessibilityLabel(Text(label))
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
