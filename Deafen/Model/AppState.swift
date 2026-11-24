//
//  AppState.swift
//  Deafen
//

import AppKit
import Observation
import ServiceManagement

@Observable
final class AppState {
    private(set) var isDeafened = false
    private(set) var mutedProcessCount = 0

    /// Each source keeps its own error so one success can't hide another's failure.
    private(set) var audioError: String?
    private(set) var shortcutError: String?
    private(set) var loginError: String?
    var errorMessage: String? { audioError ?? shortcutError ?? loginError }

    /// Install state and icons for targets and suggestions, refreshed when the list changes or the panel opens.
    private(set) var installedInfo: [String: InstalledAppInfo] = [:]
    private(set) var suggestedApps: [TargetApp] = []
    private(set) var runningApps: [TargetApp] = []

    var isRecordingShortcut = false {
        didSet { isRecordingShortcut ? hotKeys.unregister() : registerShortcut() }
    }

    var targets: [TargetApp] {
        didSet {
            preferences.targets = targets
            muter.update(bundleIDs: targets.map(\.bundleID))
            refreshAppInfo()
        }
    }

    var shortcut: Shortcut? {
        didSet {
            preferences.shortcut = shortcut
            registerShortcut()
        }
    }

    var playsSound: Bool {
        didSet { preferences.playsSound = playsSound }
    }

    var launchAtLogin = SMAppService.mainApp.status == .enabled {
        didSet { applyLaunchAtLogin() }
    }

    private let preferences: Preferences
    private let muter: AppMuter
    private let hotKeys: HotKeyCenter

    init(preferences: Preferences = Preferences(), muter: AppMuter = AppMuter(), hotKeys: HotKeyCenter = .shared) {
        self.preferences = preferences
        self.muter = muter
        self.hotKeys = hotKeys
        targets = preferences.targets
        shortcut = preferences.shortcut
        playsSound = preferences.playsSound

        muter.onStatusChange = { [weak self] count, error in
            self?.mutedProcessCount = count
            self?.audioError = error.map {
                "\($0). Make sure Deafen is allowed under System Settings › Privacy & Security › Screen & System Audio Recording."
            }
        }
        hotKeys.onPress = { [weak self] in self?.toggle() }
        registerShortcut()
        refreshAppInfo()
    }

    // MARK: Actions

    func toggle() {
        guard isDeafened || !targets.isEmpty else { return }
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

    func info(for app: TargetApp) -> InstalledAppInfo {
        installedInfo[app.bundleID] ?? .missing
    }

    /// Re-reads what's installed and running. Cheap enough to call whenever the panel opens.
    func refreshAppInfo() {
        let bundleIDs = Set((targets + TargetApp.suggestions).map(\.bundleID))
        installedInfo = Dictionary(uniqueKeysWithValues: bundleIDs.map { ($0, InstalledAppInfo(bundleID: $0)) })
        suggestedApps = TargetApp.suggestions.filter { installedInfo[$0.bundleID]?.isInstalled == true }
        runningApps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != Bundle.main.bundleIdentifier }
            .compactMap { app in
                guard let id = app.bundleIdentifier else { return nil }
                return TargetApp(bundleID: id, name: app.localizedName ?? id)
            }
            .filter { !targets.contains($0) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        // The user may have changed this in System Settings; the didSet is a no-op when it matches.
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    // MARK: Status

    var statusText: String {
        Self.statusText(
            appNames: targets.map(\.name),
            isDeafened: isDeafened,
            mutedProcessCount: mutedProcessCount
        )
    }

    static func statusText(appNames: [String], isDeafened: Bool, mutedProcessCount: Int) -> String {
        guard !appNames.isEmpty else { return "No apps selected" }
        let names = appNames.formatted(.list(type: .and))
        guard isDeafened else { return "Listening to \(names)" }
        if mutedProcessCount > 0 { return "\(names) silenced" }
        return appNames.count == 1
            ? "\(names) will be silenced as soon as it plays audio"
            : "\(names) will be silenced as soon as they play audio"
    }

    // MARK: Private

    private func registerShortcut() {
        guard !isRecordingShortcut else { return }
        do {
            try hotKeys.register(shortcut)
            shortcutError = nil
        } catch {
            shortcutError = error.localizedDescription
        }
    }

    private func applyLaunchAtLogin() {
        let isEnabled = SMAppService.mainApp.status == .enabled
        guard launchAtLogin != isEnabled else { return }
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            loginError = SMAppService.mainApp.status == .requiresApproval
                ? "Allow Deafen under System Settings › General › Login Items to launch it at login."
                : nil
        } catch {
            loginError = "Launch at login: \(error.localizedDescription)"
            launchAtLogin = isEnabled
        }
    }
}
