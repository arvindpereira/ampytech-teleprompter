import SwiftUI

struct SettingsView: View {
    @Environment(SettingsStore.self) private var store
    @Environment(RemoteControlService.self) private var remoteControl
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var store = store
        @Bindable var remoteControl = remoteControl

        Form {
            Section {
                SettingsPreview(settings: store.settings)
                    .listRowInsets(EdgeInsets())
            }

            Section("Text") {
                Picker("Font", selection: $store.settings.font) {
                    ForEach(PrompterFont.allCases) { font in
                        Text(font.displayName)
                            .font(Font(font.uiFont(size: 17, bold: false)))
                            .tag(font)
                    }
                }
                .pickerStyle(.navigationLink)

                LabeledSlider(
                    "Size",
                    value: $store.settings.fontSize,
                    in: PrompterSettings.fontSizeRange,
                    step: 2,
                    format: { "\(Int($0)) pt" }
                )
                Toggle("Bold", isOn: $store.settings.isBold)
                LabeledSlider(
                    "Line Spacing",
                    value: $store.settings.lineSpacing,
                    in: PrompterSettings.lineSpacingRange,
                    step: 0.1,
                    format: { String(format: "%.1f×", $0) }
                )
                LabeledSlider(
                    "Side Margins",
                    value: $store.settings.horizontalMargin,
                    in: PrompterSettings.marginRange,
                    step: 0.01,
                    format: { "\(Int(($0 * 100).rounded()))%" }
                )
                Picker("Alignment", selection: $store.settings.alignment) {
                    ForEach(PrompterAlignment.allCases) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            Section("Colors") {
                Picker("Theme", selection: $store.settings.theme) {
                    ForEach(PrompterTheme.allCases) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
            }

            Section {
                LabeledSlider(
                    "Speed",
                    value: $store.settings.scrollSpeed,
                    in: PrompterSettings.speedRange,
                    step: 5,
                    format: { "\(Int($0))" }
                )
                Picker("Countdown", selection: $store.settings.countdownSeconds) {
                    ForEach(PrompterSettings.countdownOptions, id: \.self) { seconds in
                        Text(seconds == 0 ? "Off" : "\(seconds) seconds").tag(seconds)
                    }
                }
            } header: {
                Text("Scrolling")
            } footer: {
                Text("While prompting you can also drag the text to jump ahead or back.")
            }

            Section {
                Toggle("Show Reading Guide", isOn: $store.settings.showReadingGuide)
                LabeledSlider(
                    "Guide Position",
                    value: $store.settings.readingGuidePosition,
                    in: PrompterSettings.readingGuideRange,
                    step: 0.05,
                    format: { "\(Int(($0 * 100).rounded()))%" }
                )
            } header: {
                Text("Reading Guide")
            } footer: {
                Text("The line your eyes should follow. Each line of the script scrolls up to this point.")
            }

            Section {
                Toggle("Mirror Horizontally", isOn: $store.settings.mirrorHorizontal)
                Toggle("Flip Vertically", isOn: $store.settings.mirrorVertical)
            } header: {
                Text("Mirroring")
            } footer: {
                Text("Turn on horizontal mirroring when using a beam-splitter glass teleprompter rig, so the reflection reads correctly.")
            }

            Section {
                Toggle("Apple Watch Remote", isOn: $remoteControl.isEnabled)
                if remoteControl.isEnabled {
                    LabeledContent("Status", value: remoteControl.statusDescription)
                }
            } header: {
                Text("Remote Control")
            } footer: {
                Text("Control the prompter with the Teleprompter app on your Apple Watch: tap to play or pause, swipe up or down to change speed, swipe left or right to jump, and turn the Digital Crown to scroll. It connects automatically over Bluetooth or Wi-Fi.")
            }

            Section {
                Button("Reset to Defaults", role: .destructive) {
                    store.resetToDefaults()
                }
            }

            Section {
                LabeledContent("Version", value: Bundle.main.appVersion)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }
}

private struct LabeledSlider: View {
    let title: LocalizedStringKey
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: (Double) -> String

    init(
        _ title: LocalizedStringKey,
        value: Binding<Double>,
        in range: ClosedRange<Double>,
        step: Double,
        format: @escaping (Double) -> String
    ) {
        self.title = title
        self._value = value
        self.range = range
        self.step = step
        self.format = format
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            LabeledContent(title, value: format(value))
            Slider(value: $value, in: range, step: step) {
                Text(title)
            }
        }
    }
}

/// A small live sample of the prompter text with the current settings applied.
private struct SettingsPreview: View {
    let settings: PrompterSettings

    var body: some View {
        Text("The quick brown fox jumps over the lazy dog.")
            .font(Font(settings.font.uiFont(size: min(settings.fontSize, 34), bold: settings.isBold)))
            .lineSpacing(CGFloat(settings.lineSpacing - 1) * 20)
            .multilineTextAlignment(settings.alignment == .center ? .center : .leading)
            .foregroundStyle(Color(settings.theme.textColor))
            .frame(maxWidth: .infinity, alignment: settings.alignment == .center ? .center : .leading)
            .padding()
            .scaleEffect(x: settings.mirrorHorizontal ? -1 : 1, y: settings.mirrorVertical ? -1 : 1)
            .background(Color(settings.theme.backgroundColor))
            .accessibilityLabel("Preview")
    }
}

private extension Bundle {
    var appVersion: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}

#Preview {
    let store = SettingsStore()
    NavigationStack {
        SettingsView()
    }
    .environment(store)
    .environment(RemoteControlService(settingsStore: store, activateSession: false))
}
