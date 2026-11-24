//
//  InstalledAppInfo.swift
//  Deafen
//

import AppKit

/// Whether an app is installed and its icon, looked up once so views don't
/// hit NSWorkspace on every render.
struct InstalledAppInfo {
    let isInstalled: Bool
    let icon: NSImage?

    static let missing = InstalledAppInfo(isInstalled: false, icon: nil)

    init(isInstalled: Bool, icon: NSImage?) {
        self.isInstalled = isInstalled
        self.icon = icon
    }

    init(bundleID: String) {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            self.init(isInstalled: true, icon: NSWorkspace.shared.icon(forFile: url.path))
        } else {
            self = .missing
        }
    }
}
