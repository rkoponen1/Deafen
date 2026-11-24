//
//  HotKey.swift
//  Deafen
//
//  A user-chosen global shortcut, registered with Carbon's RegisterEventHotKey
//  (works system-wide without Accessibility permission).
//

import AppKit
import Carbon.HIToolbox

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

    var displayString: String {
        var s = ""
        if carbonModifiers & UInt32(controlKey) != 0 { s += "⌃" }
        if carbonModifiers & UInt32(optionKey) != 0 { s += "⌥" }
        if carbonModifiers & UInt32(shiftKey) != 0 { s += "⇧" }
        if carbonModifiers & UInt32(cmdKey) != 0 { s += "⌘" }
        return s + keyLabel
    }

    /// Builds a shortcut from a key event, or nil if it isn't a usable global
    /// shortcut (needs ⌘, ⌃ or ⌥ — or be a function key on its own).
    init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var mods: UInt32 = 0
        if flags.contains(.command) { mods |= UInt32(cmdKey) }
        if flags.contains(.option) { mods |= UInt32(optionKey) }
        if flags.contains(.control) { mods |= UInt32(controlKey) }
        if flags.contains(.shift) { mods |= UInt32(shiftKey) }

        let code = Int(event.keyCode)
        let functionKeyLabel = Self.functionKeys[code]
        let hasRealModifier = mods & UInt32(cmdKey | optionKey | controlKey) != 0
        guard hasRealModifier || functionKeyLabel != nil else { return nil }

        let label = functionKeyLabel
            ?? Self.specialKeys[code]
            ?? event.charactersIgnoringModifiers?.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard let label, !label.isEmpty else { return nil }

        self.init(keyCode: UInt32(code), carbonModifiers: mods, keyLabel: label)
    }

    init(keyCode: UInt32, carbonModifiers: UInt32, keyLabel: String) {
        self.keyCode = keyCode
        self.carbonModifiers = carbonModifiers
        self.keyLabel = keyLabel
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

/// Owns the single registered global hotkey.
final class HotKeyCenter {
    static let shared = HotKeyCenter()

    var onPress: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    private init() {}

    /// Registers `shortcut` (replacing any previous one). Returns false if the
    /// system refused it, typically because another app already owns it.
    @discardableResult
    func register(_ shortcut: Shortcut?) -> Bool {
        unregister()
        guard let shortcut else { return true }
        installHandlerIfNeeded()

        let id = EventHotKeyID(signature: OSType(0x4446_4E44) /* 'DFND' */, id: 1)
        let status = RegisterEventHotKey(
            shortcut.keyCode, shortcut.carbonModifiers, id,
            GetApplicationEventTarget(), 0, &hotKeyRef
        )
        return status == noErr
    }

    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        hotKeyRef = nil
    }

    private func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            // Carbon delivers hotkey events on the main thread.
            MainActor.assumeIsolated { HotKeyCenter.shared.onPress?() }
            return noErr
        }, 1, &spec, nil, &handlerRef)
    }
}
