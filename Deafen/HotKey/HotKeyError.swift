//
//  HotKeyError.swift
//  Deafen
//

import Foundation

enum HotKeyError: LocalizedError, Equatable {
    /// The Carbon event handler couldn't be installed, so no hotkey can fire.
    case handlerUnavailable(OSStatus)
    /// The system refused the combination, usually because another app owns it.
    case shortcutTaken(String)

    var errorDescription: String? {
        switch self {
        case .handlerUnavailable(let status):
            "Couldn't listen for the shortcut (OSStatus \(status))."
        case .shortcutTaken(let shortcut):
            "\(shortcut) is already used by another app. Pick a different shortcut."
        }
    }
}
