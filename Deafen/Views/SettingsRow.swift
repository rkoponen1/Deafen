//
//  SettingsRow.swift
//  Deafen
//

import SwiftUI

/// A title on the leading edge with its control pinned to the trailing edge,
/// so every row's control lines up.
struct SettingsRow<Content: View>: View {
    let title: LocalizedStringResource
    @ContentBuilder let content: Content

    var body: some View {
        HStack {
            Text(title)
            Spacer(minLength: Metrics.rowSpacing)
            content
        }
        .frame(minHeight: 24)
    }
}
