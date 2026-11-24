//
//  DeafenHeader.swift
//  Deafen
//

import SwiftUI

/// The big deafen button with the current status and shortcut.
struct DeafenHeader: View {
    let state: AppState

    var body: some View {
        HStack(spacing: Metrics.rowSpacing + 4) {
            Button(action: state.toggle) {
                Label(
                    state.isDeafened ? "Undeafen" : "Deafen",
                    systemImage: state.isDeafened ? "headphones.slash" : "headphones"
                )
                .labelStyle(.iconOnly)
                .font(.title2)
                .foregroundStyle(.white)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: Metrics.toggleButtonSize, height: Metrics.toggleButtonSize)
                .background(state.isDeafened ? Color.red : Color.accentColor, in: .circle)
                .contentShape(.circle)
            }
            .buttonStyle(.plain)
            .disabled(state.targets.isEmpty)
            .opacity(state.targets.isEmpty ? 0.5 : 1)
            .help(state.isDeafened ? "Undeafen" : "Deafen")

            VStack(alignment: .leading, spacing: 2) {
                Text(state.isDeafened ? "Deafened" : "Not Deafened")
                    .font(.headline)
                Text(state.statusText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Text(state.shortcut?.displayString ?? "")
                .font(.callout.monospaced())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.fill.tertiary, in: .rect(cornerRadius: 5))
                .opacity(state.shortcut == nil ? 0 : 1)
                .accessibilityLabel("Shortcut \(state.shortcut?.displayString ?? "")")
                .accessibilityHidden(state.shortcut == nil)
        }
        .padding(Metrics.cardPadding)
        .background(
            state.isDeafened ? AnyShapeStyle(Color.red.opacity(0.15)) : AnyShapeStyle(.fill.quaternary),
            in: .rect(cornerRadius: Metrics.cardRadius)
        )
        .animation(.default, value: state.isDeafened)
    }
}
