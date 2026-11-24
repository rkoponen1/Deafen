//
//  MenuView.swift
//  Deafen
//

import SwiftUI

/// The panel shown from the menu bar icon.
struct MenuView: View {
    let state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.sectionSpacing) {
            DeafenHeader(state: state)
            AppListSection(state: state)
            SettingsSection(state: state)

            if let error = state.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Text("Deafen \(appVersion)")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                Spacer()
                Button("Quit Deafen", action: quit)
                    .keyboardShortcut("q")
            }
        }
        .padding(Metrics.panelPadding)
        .frame(width: Metrics.panelWidth)
        .onAppear(perform: state.refreshAppInfo)
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    private func quit() {
        NSApp.terminate(nil)
    }
}
