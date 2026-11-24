//
//  Shortcut.swift
//  Deafen
//

import AppKit
import Carbon.HIToolbox

/// A global keyboard shortcut in the form Carbon's RegisterEventHotKey expects.
struct Shortcut: Codable, Equatable {
    /// Virtual key code (kVK_*).
    var keyCode: UInt32
    /// Carbon modifier mask (cmdKey, optionKey, controlKey, shiftKey).
    var carbonModifiers: UInt32
    /// Key label captured when recorded, e.g. "D" or "F5".
    var keyLabel: String

    static let `default` = Shortcut(
        keyCode: UInt32(kVK_ANSI_D),
        carbonModifiers: UInt32(controlKey | optionKey | cmdKey),
        keyLabel: "D"
    )

    /// Modifier symbols in the standard macOS order (⌃⌥⇧⌘) followed by the key.
    var displayString: String {
        var symbols = ""
        if carbonModifiers & UInt32(controlKey) != 0 { symbols += "⌃" }
        if carbonModifiers & UInt32(optionKey) != 0 { symbols += "⌥" }
        if carbonModifiers & UInt32(shiftKey) != 0 { symbols += "⇧" }
        if carbonModifiers & UInt32(cmdKey) != 0 { symbols += "⌘" }
        return symbols + keyLabel
    }

    init(keyCode: UInt32, carbonModifiers: UInt32, keyLabel: String) {
        self.keyCode = keyCode
        self.carbonModifiers = carbonModifiers
        self.keyLabel = keyLabel
    }

    init?(event: NSEvent) {
        self.init(
            keyCode: Int(event.keyCode),
            modifierFlags: event.modifierFlags,
            characters: event.charactersIgnoringModifiers
        )
    }

    /// Builds a shortcut from a key press, or nil if it isn't usable as a
    /// global shortcut: it needs ⌘, ⌃ or ⌥, unless it's a function key.
    init?(keyCode: Int, modifierFlags: NSEvent.ModifierFlags, characters: String?) {
        let flags = modifierFlags.intersection(.deviceIndependentFlagsMask)
        var modifiers: UInt32 = 0
        if flags.contains(.command) { modifiers |= UInt32(cmdKey) }
        if flags.contains(.option) { modifiers |= UInt32(optionKey) }
        if flags.contains(.control) { modifiers |= UInt32(controlKey) }
        if flags.contains(.shift) { modifiers |= UInt32(shiftKey) }

        let functionKeyLabel = Self.functionKeys[keyCode]
        let hasRequiredModifier = modifiers & UInt32(cmdKey | optionKey | controlKey) != 0
        guard hasRequiredModifier || functionKeyLabel != nil else { return nil }

        let label = functionKeyLabel
            ?? Self.specialKeys[keyCode]
            ?? characters?.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard let label, !label.isEmpty else { return nil }

        self.init(keyCode: UInt32(keyCode), carbonModifiers: modifiers, keyLabel: label)
    }

    private static let functionKeys: [Int: String] = [
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5",
        kVK_F6: "F6", kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10",
        kVK_F11: "F11", kVK_F12: "F12", kVK_F13: "F13", kVK_F14: "F14", kVK_F15: "F15",
        kVK_F16: "F16", kVK_F17: "F17", kVK_F18: "F18", kVK_F19: "F19", kVK_F20: "F20",
    ]

    private static let specialKeys: [Int: String] = [
        kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Delete: "⌫",
        kVK_ForwardDelete: "⌦", kVK_Escape: "⎋", kVK_LeftArrow: "←", kVK_RightArrow: "→",
        kVK_UpArrow: "↑", kVK_DownArrow: "↓", kVK_Home: "↖", kVK_End: "↘",
        kVK_PageUp: "⇞", kVK_PageDown: "⇟",
    ]
}
