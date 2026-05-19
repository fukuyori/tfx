#if os(macOS)
import SwiftUI

/// A keyboard shortcut bundled with everything needed to bind it via
/// `.keyboardShortcut(_:)` and to display it as a hover-help suffix.
///
/// Keeps the binding and the human-readable label in lockstep, so renaming
/// or remapping a shortcut only touches one place (`Shortcuts`).
struct ShortcutInfo {
    let key: KeyEquivalent
    let modifiers: EventModifiers

    /// macOS-style display string. Examples: "⌘R", "⌘⇧X", "⌘\\", "⌘↑".
    /// Modifier order follows the macOS menu-bar convention: ⌃ ⌥ ⇧ ⌘ <key>.
    var displayString: String {
        var result = ""
        if modifiers.contains(.control) { result += "⌃" }
        if modifiers.contains(.option) { result += "⌥" }
        if modifiers.contains(.shift) { result += "⇧" }
        if modifiers.contains(.command) { result += "⌘" }
        result += Self.displayCharacter(for: key.character)
        return result
    }

    private static func displayCharacter(for char: Character) -> String {
        switch char {
        case "\u{F700}": return "↑"
        case "\u{F701}": return "↓"
        case "\u{F702}": return "←"
        case "\u{F703}": return "→"
        case "\u{1B}":   return "⎋"
        case "\u{7F}":   return "⌫"
        case "\u{F728}": return "⌦"
        case "\r", "\n": return "↩"
        case "\t":       return "⇥"
        case " ":        return "␣"
        default:         return String(char).uppercased()
        }
    }
}

/// Central registry of keyboard shortcuts used in tfx toolbar controls and
/// menu commands. Update here to remap a shortcut everywhere it appears.
enum Shortcuts {
    static let reload         = ShortcutInfo(key: "r", modifiers: .command)
    static let openTerminal   = ShortcutInfo(key: "t", modifiers: .command)
    static let togglePreview  = ShortcutInfo(key: "p", modifiers: .command)
    static let toggleSplit    = ShortcutInfo(key: "\\", modifiers: .command)
    static let swapPanes      = ShortcutInfo(key: "x", modifiers: [.command, .shift])
    static let focusSearch    = ShortcutInfo(key: "f", modifiers: .command)
    static let toggleHidden   = ShortcutInfo(key: ".", modifiers: [.command, .shift])
    static let goBack         = ShortcutInfo(key: "[", modifiers: .command)
    static let goForward      = ShortcutInfo(key: "]", modifiers: .command)
    static let goUp           = ShortcutInfo(key: .upArrow, modifiers: .command)
}

#endif
