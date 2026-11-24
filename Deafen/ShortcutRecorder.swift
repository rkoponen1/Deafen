//
//  ShortcutRecorder.swift
//  Deafen
//

import AppKit
import SwiftUI

/// Click to record a new global shortcut; Esc cancels, ⌫ clears.
struct ShortcutRecorder: View {
    @Bindable var state: AppState
    @State private var monitor: Any?
    @State private var hint: String?

    var body: some View {
        HStack(spacing: 6) {
            Button {
                state.isRecordingShortcut ? stopRecording() : startRecording()
            } label: {
                Text(label)
                    .font(.system(.body, design: .rounded).monospaced())
                    .frame(minWidth: 110)
            }
            .buttonStyle(.bordered)
            .tint(state.isRecordingShortcut ? .accentColor : nil)

            if state.shortcut != nil, !state.isRecordingShortcut {
                Button {
                    state.shortcut = nil
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear shortcut")
            }
        }
        .onDisappear(perform: stopRecording)
    }

    private var label: String {
        if state.isRecordingShortcut { return hint ?? "Type shortcut…" }
        return state.shortcut?.displayString ?? "Record Shortcut"
    }

    private func startRecording() {
        hint = nil
        state.isRecordingShortcut = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch Int(event.keyCode) {
            case 53 where event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty: // Esc
                stopRecording()
            case 51 where event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty: // Delete
                state.shortcut = nil
                stopRecording()
            default:
                if let shortcut = Shortcut(event: event) {
                    stopRecording()
                    state.shortcut = shortcut
                } else {
                    hint = "Add ⌘, ⌃ or ⌥"
                }
            }
            return nil
        }
    }

    private func stopRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        hint = nil
        if state.isRecordingShortcut { state.isRecordingShortcut = false }
    }
}
