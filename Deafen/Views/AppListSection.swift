//
//  AppListSection.swift
//  Deafen
//

import SwiftUI
import UniformTypeIdentifiers

/// The apps to deafen, with suggestions while empty and a menu to add more.
struct AppListSection: View {
    let state: AppState

    var body: some View {
        SectionCard(title: "Apps to Deafen") {
            if state.targets.isEmpty {
                Text("Add the apps you want to silence.")
                    .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    ForEach(state.suggestedApps) { app in
                        Button {
                            state.add(app)
                        } label: {
                            Label {
                                Text(app.name)
                            } icon: {
                                AppIcon(image: state.info(for: app).icon, size: 14)
                            }
                        }
                        .controlSize(.small)
                        .help("Add \(app.name)")
                    }
                }
            }

            ForEach(state.targets) { app in
                AppRow(app: app, info: state.info(for: app), onRemove: { state.remove(app) })
            }

            Menu("Add App…", systemImage: "plus") {
                if !state.runningApps.isEmpty {
                    Section("Running") {
                        ForEach(state.runningApps) { app in
                            Button(app.name) { state.add(app) }
                        }
                    }
                    Divider()
                }
                Button("Choose from Applications…", action: chooseApp)
            }
            .menuStyle(.button)
            .buttonStyle(.borderless)
            .fixedSize()
        }
    }

    private func chooseApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(filePath: "/Applications")
        panel.allowsMultipleSelection = true
        NSApp.activate()
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            guard let id = Bundle(url: url)?.bundleIdentifier else { continue }
            state.add(TargetApp(bundleID: id, name: url.deletingPathExtension().lastPathComponent))
        }
    }
}
