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
    private var currentShortcut: Shortcut?

    private init() {}

    /// Registers `shortcut`, replacing any previous one. Passing nil just unregisters.
    ///
    /// The new shortcut is registered before the old one is released, so a
    /// failed registration leaves the previous shortcut working.
    func register(_ shortcut: Shortcut?) throws(HotKeyError) {
        guard let shortcut else {
            unregister()
            return
        }
        guard shortcut != currentShortcut else { return }
        try installHandlerIfNeeded()

        let id = EventHotKeyID(signature: OSType(0x4446_4E44) /* 'DFND' */, id: 1)
        var newRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            shortcut.keyCode, shortcut.carbonModifiers, id,
            GetApplicationEventTarget(), 0, &newRef
        )
        guard status == noErr, let newRef else {
            if let newRef { UnregisterEventHotKey(newRef) }
            throw .shortcutTaken(shortcut.displayString)
        }

        unregister()
        hotKeyRef = newRef
        currentShortcut = shortcut
    }

    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        hotKeyRef = nil
        currentShortcut = nil
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
