#if os(macOS)
import AppKit
import SwiftUI
import Testing
@testable import tfx

@Suite("ShortcutConfiguration")
struct ShortcutConfigurationTests {
    @Test
    func parsesShortcutOverrides() throws {
        let shortcuts = try ShortcutConfigurationLoader.parse("""
        version = 1

        [shortcuts]
        reload = "cmd+shift+r"
        openTerminal = "f12"
        toggleSplit = "cmd+backslash"
        goUp = "cmd+up"
        rename = "ctrl+r"
        copyPath = "cmd+option+c"
        """)

        let f12 = try #require(ShortcutInfo.functionKeyCharacter(12))
        #expect(shortcuts[.reload] == ShortcutInfo(key: "r", modifiers: [.command, .shift]))
        #expect(shortcuts[.openTerminal] == ShortcutInfo(key: KeyEquivalent(f12), modifiers: []))
        #expect(shortcuts[.toggleSplit] == ShortcutInfo(key: "\\", modifiers: .command))
        #expect(shortcuts[.goUp] == ShortcutInfo(key: .upArrow, modifiers: .command))
        #expect(shortcuts[.rename] == ShortcutInfo(key: "r", modifiers: .control))
        #expect(shortcuts[.copyPath] == ShortcutInfo(key: "c", modifiers: [.command, .option]))
    }

    @Test
    func rejectsUnknownAction() {
        #expect(throws: ShortcutConfigurationError.self) {
            _ = try ShortcutConfigurationLoader.parse("""
            version = 1

            [shortcuts]
            notAnAction = "cmd+n"
            """)
        }
    }

    @Test
    func rejectsInvalidShortcut() {
        #expect(throws: ShortcutConfigurationError.self) {
            _ = try ShortcutConfigurationLoader.parse("""
            version = 1

            [shortcuts]
            reload = "cmd+shift"
            """)
        }
    }

    @Test
    func rejectsConflictsWithDefaults() {
        #expect(throws: ShortcutConfigurationError.self) {
            _ = try ShortcutConfigurationLoader.parse("""
            version = 1

            [shortcuts]
            reload = "cmd+t"
            """)
        }
    }

    @Test
    func rejectsConflictsBetweenOverrides() {
        #expect(throws: ShortcutConfigurationError.self) {
            _ = try ShortcutConfigurationLoader.parse("""
            version = 1

            [shortcuts]
            reload = "cmd+shift+z"
            openTerminal = "cmd+shift+z"
            """)
        }
    }

    @Test
    func controlShortcutMatchesControlCharacterEvent() throws {
        let shortcut = ShortcutInfo(key: "t", modifiers: .control)
        let event = try #require(NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: .control,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "\u{14}",
            charactersIgnoringModifiers: "\u{14}",
            isARepeat: false,
            keyCode: 17
        ))

        #expect(shortcut.matches(event))
    }

    @Test
    func functionKeyShortcutMatchesFunctionKeyEvent() throws {
        let functionKey = try #require(ShortcutInfo.functionKeyCharacter(12))
        let shortcut = ShortcutInfo(key: KeyEquivalent(functionKey), modifiers: [])
        let event = try #require(NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: String(functionKey),
            charactersIgnoringModifiers: String(functionKey),
            isARepeat: false,
            keyCode: 111
        ))

        #expect(shortcut.matches(event))
        #expect(shortcut.displayString == "F12")
    }

    @Test
    func deleteShortcutMatchesForwardDeleteEvent() throws {
        let shortcut = ShortcutInfo(key: .delete, modifiers: .command)
        let event = try #require(NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: .command,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "\u{F728}",
            charactersIgnoringModifiers: "\u{F728}",
            isARepeat: false,
            keyCode: 117
        ))

        #expect(shortcut.matches(event))
    }
}
#endif
