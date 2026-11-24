//
//  DeafenApp.swift
//  Deafen
//
//  Created by Ruupert Koponen on 20.11.2026.
//

import SwiftUI

@main
struct DeafenApp: App {
    @State private var state = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuView(state: state)
        } label: {
            Image(systemName: state.isDeafened ? "headphones.slash" : "headphones")
                .accessibilityLabel(state.isDeafened ? "Deafen, on" : "Deafen, off")
        }
        .menuBarExtraStyle(.window)
    }
}
