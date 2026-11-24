//
//  SectionCard.swift
//  Deafen
//

import SwiftUI

/// A titled, rounded group of rows, in the style of Control Center modules.
struct SectionCard<Content: View>: View {
    let title: LocalizedStringResource
    @ContentBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .bold()
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            VStack(alignment: .leading, spacing: Metrics.rowSpacing) {
                content
            }
            .padding(Metrics.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.fill.quaternary, in: .rect(cornerRadius: Metrics.cardRadius))
        }
    }
}
