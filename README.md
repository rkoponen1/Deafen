# Deafen

A tiny macOS menu bar app that **deafens** the apps you choose, like Discord's deafen button for Slack (or any other app). Press a global shortcut and the app goes silent. Press it again to hear it.

- **Any app.** Slack is selected by default. Add others from running apps or the Applications folder.
- **A shortcut you choose.** Record any key combination with ⌘, ⌃ or ⌥, or a function key on its own. The default is **⌃⌥⌘D**.
- **Only the chosen apps go quiet.** Your other audio keeps playing.
- **Follows the app.** Helper processes (Slack is an Electron app, and its sounds come from "Slack Helper") are silenced too. Processes that start playing sound later, and output device changes (e.g. plugging in headphones), are picked up automatically.
- **Small extras:** a sound when you toggle, and launch at login.

## Requirements

- macOS 27 or later (the project's deployment target; the audio tap APIs themselves exist since macOS 14.2)
- Xcode 27 or later to build

## Build and run

1. Clone the repo and open `Deafen.xcodeproj` in Xcode.
2. Select the **Deafen** target → **Signing & Capabilities** and choose your own **Team**. Change the bundle identifier (`rk.Deafen`) if Xcode asks for a unique one.
3. Build and run (⌘R). A speaker icon appears in the menu bar. The app has no Dock icon.

To keep it installed, archive a Release build (Product → Archive → Distribute App → Copy App), move `Deafen.app` into `/Applications` and turn on **Launch at login** from its menu.

## First use: allow audio access

The first time you deafen an app, macOS asks to let Deafen **record audio from other apps**. Allow it. Silencing another app works by intercepting its audio, so this permission is required.

You can change it later in **System Settings → Privacy & Security → Screen & System Audio Recording**. While an app is deafened, macOS may show its recording indicator in the menu bar. Deafen never saves or sends any audio; it just drops it.

## How it works

Deafen uses Core Audio [process taps](https://developer.apple.com/documentation/coreaudio/capturing-system-audio-with-core-audio-taps). It creates a private tap on the chosen app's audio processes with `muteBehavior = .muted`, which keeps their audio from reaching the speakers. The tap is attached to a private aggregate device that runs with an empty IOProc. Deafen also listens for changes to the system's process list and default output device, and rebuilds the tap when they change.

The global shortcut uses Carbon's `RegisterEventHotKey`, so it works in every app without Accessibility permission.

| File | What it does |
| --- | --- |
| `Deafen/AudioMuter.swift` | Finds the apps' audio processes and silences them |
| `Deafen/HotKey.swift` | Shortcut model and global hotkey registration |
| `Deafen/AppState.swift` | Settings, persistence and on/off state |
| `Deafen/MenuView.swift`, `Deafen/ShortcutRecorder.swift` | Menu bar panel and shortcut recorder |

## Notes

- **No App Sandbox.** The app runs outside the App Sandbox so audio taps work reliably, which means it can't be distributed through the Mac App Store as is.
- **If your shortcut is taken,** another app already owns that combination, and Deafen tells you so. Pick a different one.
- **When the target app isn't playing anything yet,** Deafen stays deafened and silences it as soon as it makes a sound.

## License

[MIT](LICENSE)
