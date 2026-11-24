//
//  ShortcutRecorder.swift
//  Deafen
//

import Carbon.HIToolbox
import SwiftUI

/// Click to record a new global shortcut; Esc cancels, ⌫ clears.
struct ShortcutRecorder: View {
    let state: AppState
    @State private var monitor: Any?
    @State private var hint: String?

    var body: some View {
        HStack(spacing: 4) {
            Button(action: toggleRecording) {
                Text(label)
                    .monospaced()
                    .frame(minWidth: 90)
            }
            .buttonStyle(.bordered)
            .tint(state.isRecordingShortcut ? .accentColor : nil)
            .help("Click, then press the new shortcut")

            Button("Clear Shortcut", systemImage: "xmark.circle.fill", action: clearShortcut)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .opacity(canClear ? 1 : 0)
                .disabled(!canClear)
                .accessibilityHidden(!canClear)
                .help("Clear shortcut")
        }
        .onDisappear(perform: stopRecording)
    }

    private var canClear: Bool {
        state.shortcut != nil && !state.isRecordingShortcut
    }

    private var label: String {
        if state.isRecordingShortcut { return hint ?? "Type shortcut…" }
        return state.shortcut?.displayString ?? "Record"
    }

    private func toggleRecording() {
        state.isRecordingShortcut ? stopRecording() : startRecording()
    }

    private func clearShortcut() {
        state.shortcut = nil
    }

    private func startRecording() {
        hint = nil
        state.isRecordingShortcut = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handle(event)
            return nil
        }
    }

    private func handle(_ event: NSEvent) {
        let hasModifiers = !event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty
        switch Int(event.keyCode) {
        case kVK_Escape where !hasModifiers:
            stopRecording()
        case kVK_Delete where !hasModifiers:
            stopRecording()
            clearShortcut()
        default:
            if let shortcut = Shortcut(event: event) {
                stopRecording()
                state.shortcut = shortcut
            } else {
                hint = "Add ⌘, ⌃ or ⌥"
            }
        }
    }

    private func stopRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        hint = nil
        if state.isRecordingShortcut { state.isRecordingShortcut = false }
    }
}
