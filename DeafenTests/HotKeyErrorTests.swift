//
//  HotKeyErrorTests.swift
//  DeafenTests
//

import Testing
@testable import Deafen

struct HotKeyErrorTests {
    @Test func takenShortcutNamesTheShortcut() {
        let message = HotKeyError.shortcutTaken("⌃⌥⌘D").errorDescription
        #expect(message == "⌃⌥⌘D is already used by macOS or another app. Pick a different shortcut.")
    }

    @Test func handlerFailureIncludesStatus() {
        #expect(HotKeyError.handlerUnavailable(-9870).errorDescription?.contains("-9870") == true)
    }
}
