//
//  PreferencesTests.swift
//  DeafenTests
//

import AppKit
import Testing
@testable import Deafen

struct PreferencesTests {
    let defaults: UserDefaults
    let preferences: Preferences

    init() throws {
        let suite = "DeafenTests.\(UUID().uuidString)"
        defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        preferences = Preferences(defaults: defaults)
    }

    @Test func freshInstallHasEmptyListDefaultShortcutAndSound() {
        #expect(preferences.targets.isEmpty)
        #expect(preferences.shortcut == .default)
        #expect(preferences.playsSound)
    }

    @Test func savesTargets() {
        let apps = [TargetApp(bundleID: "com.example.chat", name: "Chat")]
        preferences.targets = apps
        #expect(Preferences(defaults: defaults).targets == apps)
    }

    @Test func savesRecordedShortcut() throws {
        let shortcut = try #require(Shortcut(keyCode: 2, modifierFlags: .command, characters: "d"))
        preferences.shortcut = shortcut
        #expect(Preferences(defaults: defaults).shortcut == shortcut)
    }

    @Test func clearedShortcutStaysClearedInsteadOfFallingBackToDefault() {
        preferences.shortcut = nil
        #expect(Preferences(defaults: defaults).shortcut == nil)
    }

    @Test func savesSoundSetting() {
        preferences.playsSound = false
        #expect(Preferences(defaults: defaults).playsSound == false)
    }

    @Test func corruptDataFallsBackToEmptyList() {
        defaults.set(Data("not json".utf8), forKey: "targets")
        #expect(preferences.targets.isEmpty)
    }
}
