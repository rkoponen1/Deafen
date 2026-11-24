//
//  AppIcon.swift
//  Deafen
//

import SwiftUI

/// An app's icon, or a placeholder when the app isn't installed.
struct AppIcon: View {
    let image: NSImage?
    var size: CGFloat = Metrics.appIconSize

    var body: some View {
        Image(nsImage: image ?? NSImage(systemSymbolName: "app.dashed", accessibilityDescription: nil) ?? NSImage())
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
