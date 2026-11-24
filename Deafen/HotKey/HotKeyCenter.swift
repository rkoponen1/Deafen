//
//  HotKeyCenter.swift
//  Deafen
//
//  Registers the user's shortcut with Carbon's RegisterEventHotKey, which
//  works system-wide without Accessibility permission.
//

import Carbon.HIToolbox

/// Owns the single registered global hotkey.
final class HotKeyCenter {
    static let shared = HotKeyCenter()

    var onPress: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    private init() {}

    /// Registers `shortcut`, replacing any previous one. Passing nil just unregisters.
    func register(_ shortcut: Shortcut?) throws(HotKeyError) {
        unregister()
        guard let shortcut else { return }
        try installHandlerIfNeeded()

        let id = EventHotKeyID(signature: OSType(0x4446_4E44) /* 'DFND' */, id: 1)
        let status = RegisterEventHotKey(
            shortcut.keyCode, shortcut.carbonModifiers, id,
            GetApplicationEventTarget(), 0, &hotKeyRef
        )
        guard status == noErr else { throw .shortcutTaken(shortcut.displayString) }
    }

    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        hotKeyRef = nil
    }

    private func installHandlerIfNeeded() throws(HotKeyError) {
        guard handlerRef == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            // Carbon delivers hotkey events on the main thread.
            MainActor.assumeIsolated { HotKeyCenter.shared.onPress?() }
            return noErr
        }, 1, &spec, nil, &handlerRef)
        guard status == noErr else {
            handlerRef = nil
            throw .handlerUnavailable(status)
        }
    }
}
