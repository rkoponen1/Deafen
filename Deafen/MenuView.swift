//
//  MenuView.swift
//  Deafen
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct MenuView: View {
    @Bindable var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            Divider()
            appsSection
            Divider()
            settingsSection
            if let error = state.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Divider()
            HStack {
                Spacer()
                Button("Quit Deafen") { NSApp.terminate(nil) }
                    .keyboardShortcut("q")
            }
        }
        .padding(16)
        .frame(width: 320)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button(action: state.toggle) {
                Image(systemName: state.isDeafened ? "headphones.slash" : "headphones")
                    .font(.title2)
                    .frame(width: 44, height: 44)
                    .foregroundStyle(.white)
                    .background(Circle().fill(state.isDeafened ? Color.red : Color.accentColor))
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .disabled(state.targets.isEmpty)
            .help(state.isDeafened ? "Undeafen" : "Deafen")

            VStack(alignment: .leading, spacing: 2) {
                Text(state.isDeafened ? "Deafened" : "Not deafened").font(.headline)
                Text(state.statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var appsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Apps to deafen").font(.subheadline.weight(.semibold))

            ForEach(state.targets) { app in
                HStack(spacing: 8) {
                    if let icon = app.icon {
                        Image(nsImage: icon).resizable().frame(width: 20, height: 20)
                    } else {
                        Image(systemName: "app.dashed").frame(width: 20, height: 20)
                    }
                    Text(app.name)
                    Spacer()
                    Button {
                        state.remove(app)
                    } label: {
                        Image(systemName: "minus.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Remove \(app.name)")
                }
            }

            Menu("Add App…") {
                let running = runningApps
                if !running.isEmpty {
                    Section("Running") {
                        ForEach(running) { app in
                            Button(app.name) { state.add(app) }
                        }
                    }
                }
                Button("Choose from Applications…", action: chooseApp)
            }
            .fixedSize()
        }
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Shortcut")
                Spacer()
                ShortcutRecorder(state: state)
            }
            Toggle("Play sound when toggling", isOn: $state.playsSound)
            Toggle("Launch at login", isOn: Binding(
                get: { state.launchAtLogin },
                set: { state.launchAtLogin = $0 }
            ))
        }
        .toggleStyle(.switch)
        .controlSize(.small)
    }

    private var runningApps: [TargetApp] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != Bundle.main.bundleIdentifier }
            .compactMap { app in
                guard let id = app.bundleIdentifier else { return nil }
                return TargetApp(bundleID: id, name: app.localizedName ?? id)
            }
            .filter { !state.targets.contains($0) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func chooseApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = true
        NSApp.activate()
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            guard let bundle = Bundle(url: url), let id = bundle.bundleIdentifier else { continue }
            let name = FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
            state.add(TargetApp(bundleID: id, name: name))
        }
    }
}
