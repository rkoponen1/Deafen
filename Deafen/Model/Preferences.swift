//
//  Preferences.swift
//  Deafen
//

import Foundation

/// Typed access to the settings Deafen stores in UserDefaults.
struct Preferences {
    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private enum Key {
        static let targets = "targets"
        static let shortcut = "shortcut"
        static let playsSound = "playsSound"
    }

    var targets: [TargetApp] {
        get { load([TargetApp].self, forKey: Key.targets) ?? [] }
        nonmutating set { save(newValue, forKey: Key.targets) }
    }

    /// The default shortcut until the user records or clears one. A cleared
    /// shortcut stays cleared across launches.
    var shortcut: Shortcut? {
        get {
            guard defaults.object(forKey: Key.shortcut) != nil else { return .default }
            return load(Shortcut.self, forKey: Key.shortcut)
        }
        nonmutating set { save(newValue, forKey: Key.shortcut) }
    }

    var playsSound: Bool {
        get { defaults.object(forKey: Key.playsSound) as? Bool ?? true }
        nonmutating set { defaults.set(newValue, forKey: Key.playsSound) }
    }

    private func save<T: Encodable>(_ value: T?, forKey key: String) {
        // nil is stored as empty data so it isn't replaced by a default on next launch.
        defaults.set(value.flatMap { try? JSONEncoder().encode($0) } ?? Data(), forKey: key)
    }

    private func load<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = defaults.data(forKey: key), !data.isEmpty else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
