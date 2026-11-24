//
//  AppState.swift
//  Deafen
//

import AppKit
import Observation
import ServiceManagement

struct TargetApp: Codable, Hashable, Identifiable {
    var bundleID: String
    var name: String
    var id: String { bundleID }

    static let slack = TargetApp(bundleID: "com.tinyspeck.slackmacgap", name: "Slack")

    var icon: NSImage? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}

@Observable
final class AppState {
    private(set) var isDeafened = false
    private(set) var mutedProcessCount = 0
    var errorMessage: String?
    var isRecordingShortcut = false {
        didSet { isRecordingShortcut ? HotKeyCenter.shared.unregister() : registerShortcut() }
    }

    var targets: [TargetApp] {
        didSet {
            save(targets, forKey: Keys.targets)
            muter.update(bundleIDs: targets.map(\.bundleID))
        }
    }

    var shortcut: Shortcut? {
        didSet {
            save(shortcut, forKey: Keys.shortcut)
            registerShortcut()
        }
    }

    var playsSound: Bool {
        didSet { UserDefaults.standard.set(playsSound, forKey: Keys.playsSound) }
    }

    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                errorMessage = nil
            } catch {
                errorMessage = "Launch at login: \(error.localizedDescription)"
            }
        }
    }

    private let muter = AppMuter()

    private enum Keys {
        static let targets = "targets"
        static let shortcut = "shortcut"
        static let playsSound = "playsSound"
    }

    init() {
        let defaults = UserDefaults.standard
        targets = Self.load([TargetApp].self, forKey: Keys.targets) ?? [.slack]
        shortcut = defaults.object(forKey: Keys.shortcut) == nil
            ? .default
            : Self.load(Shortcut.self, forKey: Keys.shortcut)
        playsSound = defaults.object(forKey: Keys.playsSound) as? Bool ?? true

        muter.onStatusChange = { [weak self] count, error in
            self?.mutedProcessCount = count
            self?.errorMessage = error.map { "\($0). Make sure Deafen is allowed under System Settings › Privacy & Security › Screen & System Audio Recording." }
        }
        HotKeyCenter.shared.onPress = { [weak self] in self?.toggle() }
        registerShortcut()
    }

    func toggle() {
        isDeafened.toggle()
        if isDeafened {
            muter.start(bundleIDs: targets.map(\.bundleID))
        } else {
            muter.stop()
        }
        if playsSound { NSSound(named: isDeafened ? "Pop" : "Tink")?.play() }
    }

    func add(_ app: TargetApp) {
        guard !targets.contains(app) else { return }
        targets.append(app)
    }

    func remove(_ app: TargetApp) {
        targets.removeAll { $0 == app }
    }

    var statusText: String {
        let names = targets.map(\.name).formatted(.list(type: .and))
        if targets.isEmpty { return "No apps selected" }
        guard isDeafened else { return "Listening to \(names)" }
        return mutedProcessCount > 0
            ? "\(names) deafened"
            : "\(names) will be silenced as soon as it plays audio"
    }

    private func registerShortcut() {
        guard !isRecordingShortcut else { return }
        if !HotKeyCenter.shared.register(shortcut), let shortcut {
            errorMessage = "\(shortcut.displayString) is already used by another app. Pick a different shortcut."
        }
    }

    private func save<T: Encodable>(_ value: T?, forKey key: String) {
        // A cleared value is stored as empty data so it isn't replaced by the default on next launch.
        UserDefaults.standard.set(value.flatMap { try? JSONEncoder().encode($0) } ?? Data(), forKey: key)
    }

    private static func load<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
