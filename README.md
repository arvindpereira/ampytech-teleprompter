# ampytech-teleprompter
Teleprompter that does not require In-app purchases for everything.

A native SwiftUI teleprompter for iPhone and iPad (iOS 17+).

## Features

- **Scripts** — write, paste, or import `.txt` / `.rtf` files; stored on-device with SwiftData; searchable list with word count and estimated read time.
- **Smooth auto-scroll** — CADisplayLink-driven at up to 120Hz (ProMotion), with sub-pixel accuracy so even slow speeds don't stutter.
- **3-2-1 countdown** before scrolling starts (configurable: off / 3 / 5 / 10 seconds). The countdown is mirrored along with the text.
- **Mirroring** — horizontal (for beam-splitter glass rigs) and vertical flip.
- **Fonts** — 10 typefaces, size 20–160pt, bold, line spacing, side margins, left/center alignment, 4 color themes.
- **Live controls** — play/pause, restart, text size, mirror, and speed slider; auto-hide while scrolling, tap the text to bring them back. Settings open as a half-height sheet so you can tweak while watching the text.
- **Drag to reposition** — drag the text at any time; auto-scroll resumes from where you let go. Reading position is preserved across font changes and rotation.
- **Reading guide** — red arrows marking the line to read, adjustable height.
- **Keyboard / Bluetooth remote** — Space/Return: play/pause · ↑/↓: speed · ←/→ or Page Up/Down: jump back/forward · R: restart · Esc: close.
- Screen stays awake while prompting. Portrait and landscape.

## Building

Requires Xcode 26+. The `Makefile` points `DEVELOPER_DIR` at `/Applications/Xcode.app`, so it works even if `xcode-select` is set to the Command Line Tools.

```sh
make open    # open in Xcode
make build   # build for the simulator (SIMULATOR="iPhone 17 Pro" by default)
make test    # run unit tests
make run     # build, install and launch in the simulator
make icon    # regenerate the placeholder app icon
```

The project uses Xcode's synchronized folders: any file added under `Teleprompter/` or `TeleprompterTests/` is picked up automatically, with no project-file edits needed.

## Running on your iPhone

1. `make open`, select the **Teleprompter** target → *Signing & Capabilities* → choose your Team.
2. Plug in your iPhone (enable *Developer Mode* in Settings → Privacy & Security), select it as the run destination, and press ⌘R.

## App Store checklist

Already in place: bundle ID `com.ampytech.teleprompter`, app icon (placeholder), privacy manifest (`PrivacyInfo.xcprivacy`, UserDefaults reason CA92.1), `ITSAppUsesNonExemptEncryption = NO`, generated launch screen, Productivity category.

Still to do:
- Join the Apple Developer Program, set `DEVELOPMENT_TEAM`, and register the bundle ID (change it if you prefer).
- Replace the placeholder icon with a final design.
- Create the App Store Connect record: screenshots, description, privacy policy URL, age rating.
- *Product → Archive* → *Distribute App* → TestFlight, then submit for review.
