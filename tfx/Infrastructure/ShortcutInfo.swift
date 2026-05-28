#if os(macOS)
import AppKit
import Combine
import Foundation
import SwiftUI

/// A keyboard shortcut bundled with everything needed to bind it via
/// `.keyboardShortcut(_:)` and to display it as a hover-help suffix.
///
/// Keeps the binding and the human-readable label in lockstep, so renaming
/// or remapping a shortcut only touches one place (`Shortcuts`).
struct ShortcutInfo: Equatable, Hashable {
    let key: KeyEquivalent
    let modifiers: EventModifiers

    static func == (lhs: ShortcutInfo, rhs: ShortcutInfo) -> Bool {
        lhs.key.character == rhs.key.character &&
        lhs.modifiers.nseventModifierFlags == rhs.modifiers.nseventModifierFlags
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(key.character)
        hasher.combine(modifiers.nseventModifierFlags.rawValue)
    }

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
        case "\u{8}", "\u{7F}": return "⌫"
        case "\u{F728}": return "⌦"
        case "\r", "\n": return "↩"
        case "\t":       return "⇥"
        case " ":        return "␣"
        default:
            if let functionKeyNumber = functionKeyNumber(for: char) {
                return "F\(functionKeyNumber)"
            }
            return String(char).uppercased()
        }
    }

    func matches(_ event: NSEvent) -> Bool {
        let supportedModifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        guard supportedModifiers == modifiers.nseventModifierFlags else { return false }

        if let character = event.charactersIgnoringModifiers?.first,
           String(character).lowercased() == String(key.character).lowercased() {
            return true
        }

        if Self.alternateKeyCodes(for: key.character).contains(event.keyCode) {
            return true
        }

        return Self.keyCode(for: key.character) == event.keyCode
    }

    private static func keyCode(for char: Character) -> UInt16? {
        switch String(char).lowercased() {
        case "a": return 0
        case "s": return 1
        case "d": return 2
        case "f": return 3
        case "h": return 4
        case "g": return 5
        case "z": return 6
        case "x": return 7
        case "c": return 8
        case "v": return 9
        case "b": return 11
        case "q": return 12
        case "w": return 13
        case "e": return 14
        case "r": return 15
        case "y": return 16
        case "t": return 17
        case "1": return 18
        case "2": return 19
        case "3": return 20
        case "4": return 21
        case "6": return 22
        case "5": return 23
        case "=": return 24
        case "9": return 25
        case "7": return 26
        case "-": return 27
        case "8": return 28
        case "0": return 29
        case "]": return 30
        case "o": return 31
        case "u": return 32
        case "[": return 33
        case "i": return 34
        case "p": return 35
        case "\r", "\n": return 36
        case "l": return 37
        case "j": return 38
        case "'": return 39
        case "k": return 40
        case ";": return 41
        case "\\": return 42
        case ",": return 43
        case "/": return 44
        case "n": return 45
        case "m": return 46
        case ".": return 47
        case "\t": return 48
        case " ": return 49
        case "\u{8}", "\u{7F}": return 51
        case "\u{1B}": return 53
        case "\u{F700}": return 126
        case "\u{F701}": return 125
        case "\u{F702}": return 123
        case "\u{F703}": return 124
        case "\u{F704}": return 122
        case "\u{F705}": return 120
        case "\u{F706}": return 99
        case "\u{F707}": return 118
        case "\u{F708}": return 96
        case "\u{F709}": return 97
        case "\u{F70A}": return 98
        case "\u{F70B}": return 100
        case "\u{F70C}": return 101
        case "\u{F70D}": return 109
        case "\u{F70E}": return 103
        case "\u{F70F}": return 111
        case "\u{F710}": return 105
        case "\u{F711}": return 107
        case "\u{F712}": return 113
        case "\u{F713}": return 106
        case "\u{F714}": return 64
        case "\u{F715}": return 79
        case "\u{F716}": return 80
        case "\u{F717}": return 90
        case "\u{F728}": return 117
        default: return nil
        }
    }

    private static func alternateKeyCodes(for char: Character) -> Set<UInt16> {
        switch char {
        case "\u{8}", "\u{7F}":
            // Treat the configured "delete"/"backspace" token as both the
            // Mac Delete/Backspace key and Forward Delete. External keyboards
            // and Fn+Delete report Forward Delete as keyCode 117.
            return [117]
        default:
            return []
        }
    }

    static func functionKeyCharacter(_ number: Int) -> Character? {
        guard (1...20).contains(number), let scalar = UnicodeScalar(0xF703 + number) else {
            return nil
        }
        return Character(scalar)
    }

    private static func functionKeyNumber(for char: Character) -> Int? {
        guard let scalar = String(char).unicodeScalars.first else { return nil }
        let number = Int(scalar.value) - 0xF703
        return (1...20).contains(number) ? number : nil
    }
}

enum ShortcutAction: String, CaseIterable, Identifiable {
    case reload
    case openTerminal
    case togglePreview
    case toggleSplit
    case swapPanes
    case focusSearch
    case toggleHidden
    case goBack
    case goForward
    case goUp
    case openItem
    case newFolder
    case newFile
    case rename
    case moveToTrash
    case compressToZip
    case extractZip
    case copyItems
    case cutItems
    case pasteItems
    case movePasteItems
    case selectAll
    case revealInFinder
    case copyPath
    case newTab
    case closeTab
    case previousTab
    case nextTab

    var id: String { rawValue }
}

/// Central registry of default keyboard shortcuts used in tfx toolbar controls
/// and menu commands.
enum Shortcuts {
    static let defaults: [ShortcutAction: ShortcutInfo] = [
        .reload: ShortcutInfo(key: "r", modifiers: .command),
        .openTerminal: ShortcutInfo(key: "t", modifiers: .command),
        .togglePreview: ShortcutInfo(key: "p", modifiers: .command),
        .toggleSplit: ShortcutInfo(key: "\\", modifiers: .command),
        .swapPanes: ShortcutInfo(key: "x", modifiers: [.command, .shift]),
        .focusSearch: ShortcutInfo(key: "f", modifiers: .command),
        .toggleHidden: ShortcutInfo(key: ".", modifiers: [.command, .shift]),
        .goBack: ShortcutInfo(key: "[", modifiers: .command),
        .goForward: ShortcutInfo(key: "]", modifiers: .command),
        .goUp: ShortcutInfo(key: .upArrow, modifiers: .command),
        .openItem: ShortcutInfo(key: "o", modifiers: .command),
        .newFolder: ShortcutInfo(key: "n", modifiers: .command),
        .newFile: ShortcutInfo(key: "n", modifiers: [.command, .shift]),
        .rename: ShortcutInfo(key: .return, modifiers: .command),
        .moveToTrash: ShortcutInfo(key: .delete, modifiers: .command),
        .compressToZip: ShortcutInfo(key: "z", modifiers: [.command, .option]),
        .extractZip: ShortcutInfo(key: "e", modifiers: [.command, .option]),
        .copyItems: ShortcutInfo(key: "c", modifiers: .command),
        .cutItems: ShortcutInfo(key: "x", modifiers: .command),
        .pasteItems: ShortcutInfo(key: "v", modifiers: .command),
        .movePasteItems: ShortcutInfo(key: "v", modifiers: [.command, .option]),
        .selectAll: ShortcutInfo(key: "a", modifiers: .command),
        .revealInFinder: ShortcutInfo(key: "r", modifiers: [.command, .option]),
        .copyPath: ShortcutInfo(key: "c", modifiers: [.command, .option]),
        .newTab: ShortcutInfo(key: "t", modifiers: [.command, .shift]),
        .closeTab: ShortcutInfo(key: "w", modifiers: .command),
        .previousTab: ShortcutInfo(key: "[", modifiers: [.command, .shift]),
        .nextTab: ShortcutInfo(key: "]", modifiers: [.command, .shift])
    ]

    static func info(_ action: ShortcutAction) -> ShortcutInfo {
        defaults[action]!
    }
}

@MainActor
final class ShortcutStore: ObservableObject {
    @Published private(set) var shortcuts = Shortcuts.defaults
    @Published private(set) var configurationError: String?

    init() {
        reload()
    }

    func info(_ action: ShortcutAction) -> ShortcutInfo {
        shortcuts[action] ?? Shortcuts.info(action)
    }

    func reload() {
        do {
            shortcuts = try ShortcutConfigurationLoader.load()
            configurationError = nil
        } catch {
            shortcuts = Shortcuts.defaults
            configurationError = error.localizedDescription
        }
    }

    func dismissConfigurationError() {
        configurationError = nil
    }
}

enum ShortcutConfigurationLoader {
    static let appSupportDirectoryName = "tfx"
    static let fileName = "config.toml"

    static func load(fileManager: FileManager = .default) throws -> [ShortcutAction: ShortcutInfo] {
        let configURL = try ensureConfigFile(fileManager: fileManager)
        let source = try String(contentsOf: configURL, encoding: .utf8)
        return try parse(source)
    }

    static func configFileURL(fileManager: FileManager = .default) throws -> URL {
        guard let appSupportURL = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw ShortcutConfigurationError.applicationSupportDirectoryUnavailable
        }

        return appSupportURL
            .appendingPathComponent(appSupportDirectoryName, isDirectory: true)
            .appendingPathComponent(fileName, isDirectory: false)
    }

    static func parse(_ source: String) throws -> [ShortcutAction: ShortcutInfo] {
        let parsed = try parseConfiguration(source)
        try validateConflicts(in: parsed.shortcuts, limitedTo: parsed.explicitlySet)
        return parsed.shortcuts
    }

    private static func parseConfiguration(_ source: String) throws -> ParsedShortcutConfiguration {
        var section = ""
        var resolved = Shortcuts.defaults
        var explicitlySet: Set<ShortcutAction> = []

        for (index, rawLine) in source.components(separatedBy: .newlines).enumerated() {
            let lineNumber = index + 1
            let line = stripComment(from: rawLine).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            if line.hasPrefix("[") && line.hasSuffix("]") {
                section = String(line.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
                continue
            }

            let parts = line.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else {
                throw ShortcutConfigurationError.invalidAssignment(line: lineNumber)
            }

            let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)

            switch section {
            case "":
                if key == "version" {
                    let version = try parseInt(value, line: lineNumber)
                    guard version == 1 else {
                        throw ShortcutConfigurationError.unsupportedVersion(version)
                    }
                }
            case "shortcuts":
                guard let action = ShortcutAction(rawValue: key) else {
                    throw ShortcutConfigurationError.unknownAction(key, line: lineNumber)
                }
                resolved[action] = try parseShortcut(try parseString(value, line: lineNumber), line: lineNumber)
                explicitlySet.insert(action)
            default:
                continue
            }
        }

        return ParsedShortcutConfiguration(shortcuts: resolved, explicitlySet: explicitlySet)
    }

    private static func ensureConfigFile(fileManager: FileManager) throws -> URL {
        let configURL = try configFileURL(fileManager: fileManager)
        let directoryURL = configURL.deletingLastPathComponent()

        if !fileManager.fileExists(atPath: directoryURL.path) {
            try fileManager.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )
        }

        if !fileManager.fileExists(atPath: configURL.path) {
            try defaultConfigSource.write(to: configURL, atomically: true, encoding: .utf8)
        }

        return configURL
    }

    private static func validateConflicts(
        in shortcuts: [ShortcutAction: ShortcutInfo],
        limitedTo explicitlySet: Set<ShortcutAction>
    ) throws {
        var used: [ShortcutInfo: ShortcutAction] = [:]
        for action in ShortcutAction.allCases {
            guard let shortcut = shortcuts[action] else { continue }
            if let existing = used[shortcut] {
                if explicitlySet.contains(action) || explicitlySet.contains(existing) {
                    throw ShortcutConfigurationError.conflictingShortcut(
                        shortcut.displayString,
                        first: existing.rawValue,
                        second: action.rawValue
                    )
                }
            } else {
                used[shortcut] = action
            }
        }
    }

    private static func parseShortcut(_ value: String, line: Int) throws -> ShortcutInfo {
        let tokens = value
            .split(separator: "+", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
        guard !tokens.isEmpty else {
            throw ShortcutConfigurationError.invalidShortcut(value, line: line)
        }

        var modifiers: EventModifiers = []
        var keyToken: String?
        for token in tokens {
            switch token {
            case "cmd", "command":
                modifiers.insert(.command)
            case "shift":
                modifiers.insert(.shift)
            case "opt", "option", "alt":
                modifiers.insert(.option)
            case "ctrl", "control":
                modifiers.insert(.control)
            default:
                guard keyToken == nil else {
                    throw ShortcutConfigurationError.invalidShortcut(value, line: line)
                }
                keyToken = token
            }
        }

        guard let keyToken, let key = keyEquivalent(for: keyToken) else {
            throw ShortcutConfigurationError.invalidShortcut(value, line: line)
        }
        return ShortcutInfo(key: key, modifiers: modifiers)
    }

    private static func keyEquivalent(for token: String) -> KeyEquivalent? {
        if token.hasPrefix("f"),
           let number = Int(token.dropFirst()),
           let character = ShortcutInfo.functionKeyCharacter(number) {
            return KeyEquivalent(character)
        }

        switch token {
        case "up": return .upArrow
        case "down": return .downArrow
        case "left": return .leftArrow
        case "right": return .rightArrow
        case "escape", "esc": return .escape
        case "delete", "backspace": return .delete
        case "return", "enter": return .return
        case "tab": return .tab
        case "space": return " "
        case "backslash": return "\\"
        case "leftbracket", "[": return "["
        case "rightbracket", "]": return "]"
        default:
            guard token.count == 1, let character = token.first else { return nil }
            return KeyEquivalent(character)
        }
    }

    private static func stripComment(from line: String) -> String {
        var isInString = false
        var previous: Character?

        for (index, character) in line.enumerated() {
            if character == "\"", previous != "\\" {
                isInString.toggle()
            }

            if character == "#", !isInString {
                return String(line.prefix(index))
            }

            previous = character
        }

        return line
    }

    private static func parseString(_ value: String, line: Int) throws -> String {
        guard value.hasPrefix("\""), value.hasSuffix("\""), value.count >= 2 else {
            throw ShortcutConfigurationError.invalidString(line: line)
        }

        return String(value.dropFirst().dropLast())
    }

    private static func parseInt(_ value: String, line: Int) throws -> Int {
        guard let parsed = Int(value) else {
            throw ShortcutConfigurationError.invalidNumber(line: line)
        }
        return parsed
    }

    private static let defaultConfigSource = """
    version = 1

    [font]
    ui = "system"
    mono = "monospace"
    size = 13

    [shortcuts]
    reload = "cmd+r"
    openTerminal = "cmd+t"
    togglePreview = "cmd+p"
    toggleSplit = "cmd+backslash"
    swapPanes = "cmd+shift+x"
    focusSearch = "cmd+f"
    toggleHidden = "cmd+shift+."
    goBack = "cmd+["
    goForward = "cmd+]"
    goUp = "cmd+up"
    openItem = "cmd+o"
    newFolder = "cmd+n"
    newFile = "cmd+shift+n"
    rename = "cmd+return"
    moveToTrash = "cmd+backspace"
    compressToZip = "cmd+option+z"
    extractZip = "cmd+option+e"
    copyItems = "cmd+c"
    cutItems = "cmd+x"
    pasteItems = "cmd+v"
    movePasteItems = "cmd+option+v"
    selectAll = "cmd+a"
    revealInFinder = "cmd+option+r"
    copyPath = "cmd+option+c"
    newTab = "cmd+shift+t"
    closeTab = "cmd+w"
    previousTab = "cmd+shift+["
    nextTab = "cmd+shift+]"
    """
}

enum ShortcutConfigurationError: LocalizedError {
    case applicationSupportDirectoryUnavailable
    case invalidAssignment(line: Int)
    case invalidString(line: Int)
    case invalidNumber(line: Int)
    case invalidShortcut(String, line: Int)
    case unknownAction(String, line: Int)
    case conflictingShortcut(String, first: String, second: String)
    case unsupportedVersion(Int)

    var errorDescription: String? {
        switch self {
        case .applicationSupportDirectoryUnavailable:
            return "Application Support directory is unavailable."
        case let .invalidAssignment(line):
            return "Invalid shortcut assignment at line \(line)."
        case let .invalidString(line):
            return "Invalid shortcut string at line \(line)."
        case let .invalidNumber(line):
            return "Invalid shortcut number at line \(line)."
        case let .invalidShortcut(value, line):
            return "Invalid shortcut \"\(value)\" at line \(line). Use forms like \"cmd+r\", \"cmd+shift+x\", or \"cmd+up\"."
        case let .unknownAction(action, line):
            return "Unknown shortcut action \"\(action)\" at line \(line)."
        case let .conflictingShortcut(shortcut, first, second):
            return "Shortcut \(shortcut) is assigned to both \(first) and \(second)."
        case let .unsupportedVersion(version):
            return "Unsupported shortcuts version \(version)."
        }
    }
}

private struct ParsedShortcutConfiguration {
    var shortcuts: [ShortcutAction: ShortcutInfo]
    var explicitlySet: Set<ShortcutAction>
}

private extension EventModifiers {
    var nseventModifierFlags: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if contains(.command) { flags.insert(.command) }
        if contains(.shift) { flags.insert(.shift) }
        if contains(.option) { flags.insert(.option) }
        if contains(.control) { flags.insert(.control) }
        return flags
    }
}

#endif
