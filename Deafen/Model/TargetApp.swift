//
//  TargetApp.swift
//  Deafen
//

/// An app the user wants to deafen, identified by bundle ID.
struct TargetApp: Codable, Hashable, Identifiable {
    var bundleID: String
    var name: String
    var id: String { bundleID }

    /// Offered as a one-click suggestion while the list is empty, if installed.
    static let suggestions = [
        TargetApp(bundleID: "com.tinyspeck.slackmacgap", name: "Slack"),
    ]
}
