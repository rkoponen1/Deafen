//
//  ShortcutTests.swift
//  DeafenTests
//

import AppKit
import Carbon.HIToolbox
import Testing
@testable import Deafen

struct ShortcutTests {
    @Test func defaultShortcutDisplay() {
        #expect(Shortcut.default.displayString == "⌃⌥⌘D")
    }

    @Test func modifiersAreShownInStandardOrder() {
        let shortcut = Shortcut(
            keyCode: kVK_ANSI_M,
            modifierFlags: [.command, .shift, .option, .control],
            characters: "m"
        )
        #expect(shortcut?.displayString == "⌃⌥⇧⌘M")
    }

    @Test func letterWithCommandIsAccepted() throws {
        let shortcut = try #require(Shortcut(keyCode: kVK_ANSI_D, modifierFlags: .command, characters: "d"))
        #expect(shortcut.keyCode == UInt32(kVK_ANSI_D))
        #expect(shortcut.carbonModifiers == UInt32(cmdKey))
        #expect(shortcut.keyLabel == "D")
    }

    @Test(arguments: [NSEvent.ModifierFlags(), .shift, .capsLock])
    func letterWithoutRequiredModifierIsRejected(flags: NSEvent.ModifierFlags) {
        #expect(Shortcut(keyCode: kVK_ANSI_D, modifierFlags: flags, characters: "d") == nil)
    }

    @Test func functionKeyAloneIsAccepted() {
        let shortcut = Shortcut(keyCode: kVK_F5, modifierFlags: [], characters: nil)
        #expect(shortcut?.displayString == "F5")
    }

    @Test func specialKeysGetReadableLabels() {
        let shortcut = Shortcut(keyCode: kVK_Space, modifierFlags: .option, characters: " ")
        #expect(shortcut?.displayString == "⌥Space")
    }

    @Test func keyWithoutCharactersIsRejected() {
        #expect(Shortcut(keyCode: kVK_ANSI_D, modifierFlags: .command, characters: nil) == nil)
    }

    @Test func roundTripsThroughCodable() throws {
        let data = try JSONEncoder().encode(Shortcut.default)
        #expect(try JSONDecoder().decode(Shortcut.self, from: data) == .default)
    }
}
