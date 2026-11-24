//
//  TargetApp.swift
//  Deafen
//

/// An app the user wants to deafen, identified by bundle ID.
struct TargetApp: Codable, Hashable, Identifiable {
    var bundleID: String
    var name: String
    var id: String { bundleID }

    /// Chat apps offered as one-click suggestions while the list is empty.
    static let suggestions = [
        TargetApp(bundleID: "com.tinyspeck.slackmacgap", name: "Slack"),
        TargetApp(bundleID: "com.microsoft.teams2", name: "Microsoft Teams"),
        TargetApp(bundleID: "com.hnc.Discord", name: "Discord"),
    ]
}
