//
//  AppRow.swift
//  Deafen
//

import SwiftUI

/// One app in the deafen list, with its icon and a remove button.
struct AppRow: View {
    let app: TargetApp
    let info: InstalledAppInfo
    let onRemove: () -> Void

    var body: some View {
        HStack {
            Label {
                VStack(alignment: .leading, spacing: 0) {
                    Text(app.name)
                    if !info.isInstalled {
                        Text("Not installed")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } icon: {
                AppIcon(image: info.icon)
            }

            Spacer()

            Button("Remove \(app.name)", systemImage: "minus.circle.fill", action: onRemove)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help("Remove \(app.name)")
        }
    }
}
