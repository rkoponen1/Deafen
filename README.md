# Deafen

A small macOS menu bar app that **deafens** the apps you choose, like Discord's deafen button for Slack or any other app. Press a shortcut and the app goes silent; press it again to hear it. Everything else keeps playing.

## Install

1. Download **Deafen-x.y.dmg** from the [latest release](https://github.com/rkoponen1/Deafen/releases/latest).
2. Open it and drag **Deafen** into **Applications**.
3. Open Deafen. A headphones icon appears in the menu bar (there's no Dock icon).

Requires macOS 27 or later.

## Use

1. Click the headphones icon and add the apps to silence. Installed Slack, Microsoft Teams and Discord are offered as one-click suggestions; anything else can be added with **Add App…**.
2. Press **⌃⌥⌘D** (or click the round button) to deafen. The icon shows a slash while deafened.
3. Press it again to undeafen.

To change the shortcut, click it under **Settings** and press a new combination with ⌘, ⌃ or ⌥ (or a function key on its own). Turn on **Launch at login** to keep Deafen running.

The first time you deafen, macOS asks to let Deafen **record audio from other apps**. Allow it: Deafen silences an app by intercepting its audio. It never saves or sends any audio. While an app is deafened, macOS may show its recording indicator.

## Troubleshooting

- **The app still makes sound:** check that Deafen is allowed under System Settings → Privacy & Security → **Screen & System Audio Recording**.
- **"Already used by another app":** another app owns that shortcut. Pick a different one.
- **The app isn't playing anything yet:** that's fine. Deafen silences it as soon as it makes a sound, including helper processes and after you switch output devices.

## How it works

Deafen creates a Core Audio [process tap](https://developer.apple.com/documentation/coreaudio/capturing-system-audio-with-core-audio-taps) on the chosen apps' audio processes with `muteBehavior = .muted`, which keeps their audio from reaching the speakers. The global shortcut uses Carbon's `RegisterEventHotKey`, so it needs no Accessibility permission. The app runs outside the App Sandbox, so it can't be on the Mac App Store as is.

## Development

To publish a signed, notarized release, see [docs/RELEASING.md](docs/RELEASING.md).

## License

[MIT](LICENSE)
