//
//  ProcessMatcher.swift
//  Deafen
//

/// Decides whether an audio process belongs to one of the target apps.
///
/// A process matches when its bundle ID equals a target's or is nested under
/// it (`com.tinyspeck.slackmacgap.helper`), or when its executable lives
/// inside a target's app bundle (Electron helpers such as "Slack Helper").
struct ProcessMatcher {
    let bundleIDs: [String]
    let bundlePaths: [String]

    func matches(bundleID: String?) -> Bool {
        guard let bundleID, !bundleID.isEmpty else { return false }
        return bundleIDs.contains { bundleID == $0 || bundleID.hasPrefix($0 + ".") }
    }

    func matches(executablePath: String) -> Bool {
        bundlePaths.contains { path in
            let folder = path.hasSuffix("/") ? path : path + "/"
            return executablePath.hasPrefix(folder)
        }
    }
}
