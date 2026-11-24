//
//  SettingsSection.swift
//  Deafen
//

import SwiftUI

/// Shortcut, sound and launch-at-login settings, with every control aligned to the trailing edge.
struct SettingsSection: View {
    @Bindable var state: AppState

    var body: some View {
        SectionCard(title: "Settings") {
            SettingsRow(title: "Shortcut") {
                ShortcutRecorder(state: state)
            }
            Divider()
            SettingsRow(title: "Play sound when toggling") {
                Toggle("Play sound when toggling", isOn: $state.playsSound)
                    .labelsHidden()
            }
            Divider()
            SettingsRow(title: "Launch at login") {
                Toggle("Launch at login", isOn: $state.launchAtLogin)
                    .labelsHidden()
            }
        }
        .toggleStyle(.switch)
        .controlSize(.small)
    }
}
