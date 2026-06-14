#if os(macOS)
import AppKit
import CoreText
import Foundation
import SwiftUI

struct DesignConfiguration {
    var theme: Theme
    var fonts: DesignFontTokens
    var opacity: DesignOpacityTokens

    static let `default` = DesignConfiguration(theme: .default, fonts: .default, opacity: .default)
}

enum DesignConfigurationLoader {
    static let appSupportDirectoryName = "tfx"
    static let fileName = "config.toml"

    static func load(fileManager: FileManager = .default) throws -> DesignConfiguration {
        let configURL = try ensureConfigFile(fileManager: fileManager)
        let source = try String(contentsOf: configURL, encoding: .utf8)
        return try parse(source)
    }

    static func configFileURL(fileManager: FileManager = .default) throws -> URL {
        guard let appSupportURL = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw DesignConfigurationError.applicationSupportDirectoryUnavailable
        }

        return appSupportURL
            .appendingPathComponent(appSupportDirectoryName, isDirectory: true)
            .appendingPathComponent(fileName, isDirectory: false)
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

    static func parse(_ source: String) throws -> DesignConfiguration {
        var section = ""
        var fonts = DesignFontTokens.default
        var opacity = DesignOpacityTokens.default
        var colorOverrides = ThemeColorOverrides()

        for (index, rawLine) in source.components(separatedBy: .newlines).enumerated() {
            let lineNumber = index + 1
            let line = stripComment(from: rawLine).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            if line.hasPrefix("[") && line.hasSuffix("]") {
                section = String(line.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
                continue
            }

            guard ["", "font", "colors", "opacity"].contains(section) else {
                continue
            }

            let parts = line.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else {
                throw DesignConfigurationError.invalidAssignment(line: lineNumber)
            }

            let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)

            switch section {
            case "":
                if key == "version" {
                    let version = try parseInt(value, line: lineNumber)
                    guard version == 1 else {
                        throw DesignConfigurationError.unsupportedVersion(version)
                    }
                }
            case "font":
                try applyFontValue(key: key, value: value, line: lineNumber, fonts: &fonts)
            case "colors":
                try applyColorValue(key: key, value: value, line: lineNumber, overrides: &colorOverrides)
            case "opacity":
                try applyOpacityValue(key: key, value: value, line: lineNumber, opacity: &opacity)
            default:
                continue
            }
        }

        return DesignConfiguration(theme: Theme.default.applying(colorOverrides), fonts: fonts, opacity: opacity)
    }

    private static func applyFontValue(
        key: String,
        value: String,
        line: Int,
        fonts: inout DesignFontTokens
    ) throws {
        switch key {
        case "ui":
            let family = try parseString(value, line: line)
            fonts.uiFamily = family == "system" ? nil : ConfiguredFontRegistrar.resolve(family)
        case "mono":
            let family = try parseString(value, line: line)
            fonts.monoFamily = family == "monospace" ? nil : ConfiguredFontRegistrar.resolve(family)
        case "size":
            fonts.baseSize = try parsePointSize(value, line: line)
        // Per-pane overrides. Empty string → no override (cleared
        // by the user, fall back to global `mono` / `ui`). A
        // family name that doesn't resolve gets stored verbatim
        // so the existing fall-through in `DesignFontTokens`
        // (NSFont(name:) returning nil → system mono / system
        // ui) keeps the pane usable.
        case "fileList":
            fonts.fileListFamily = parsePaneFamily(try parseString(value, line: line))
        case "fileListSize":
            fonts.fileListSize = try parsePaneSize(value, line: line)
        case "folderTree":
            fonts.folderTreeFamily = parsePaneFamily(try parseString(value, line: line))
        case "folderTreeSize":
            fonts.folderTreeSize = try parsePaneSize(value, line: line)
        case "preview":
            fonts.previewFamily = parsePaneFamily(try parseString(value, line: line))
        case "previewSize":
            fonts.previewSize = try parsePaneSize(value, line: line)
        case "terminal":
            fonts.terminalFamily = parsePaneFamily(try parseString(value, line: line))
        case "terminalSize":
            fonts.terminalSize = try parsePaneSize(value, line: line)
        default:
            break
        }
    }

    /// Family lookup for per-pane keys. Sentinel values that
    /// mean "inherit from the global setting" — `""`, the
    /// literal `"system"` (mirroring `[font] ui`), and
    /// `"monospace"` (mirroring `[font] mono`) — collapse to
    /// `nil` so `DesignFontTokens.resolvedFamily(for:)` falls
    /// back to `uiFamily` / `monoFamily`.
    private static func parsePaneFamily(_ family: String) -> String? {
        let trimmed = family.trimmingCharacters(in: .whitespaces)
        switch trimmed {
        case "", "system", "monospace": return nil
        default: return ConfiguredFontRegistrar.resolve(trimmed)
        }
    }

    /// Size override. `0` (and anything missing) means inherit
    /// the global base size — same convention as the family
    /// sentinels above. Anything else is bounds-checked the
    /// same way `[font] size` is.
    private static func parsePaneSize(_ value: String, line: Int) throws -> CGFloat? {
        let parsed = try parseDouble(value, line: line)
        if parsed == 0 { return nil }
        guard parsed >= 8, parsed <= 40 else {
            throw DesignConfigurationError.invalidFontSize(line: line)
        }
        return CGFloat(parsed)
    }

    private static func parsePointSize(_ value: String, line: Int) throws -> CGFloat {
        let parsed = try parseDouble(value, line: line)
        guard parsed >= 8, parsed <= 40 else {
            throw DesignConfigurationError.invalidFontSize(line: line)
        }
        return CGFloat(parsed)
    }

    private static func applyColorValue(
        key: String,
        value: String,
        line: Int,
        overrides: inout ThemeColorOverrides
    ) throws {
        let color = try parseColor(value, line: line)

        switch key {
        case "fileListBackground": overrides.fileListBackground = color
        case "fileListRowSelected": overrides.fileListRowSelected = color
        case "fileListRowDropTarget": overrides.fileListRowDropTarget = color
        case "directoryForeground": overrides.directoryForeground = color
        case "fileForeground": overrides.fileForeground = color
        case "secondaryForeground": overrides.secondaryForeground = color
        case "headerForeground": overrides.headerForeground = color
        case "headerBackground": overrides.headerBackground = color
        case "headerIconForeground": overrides.headerIconForeground = color
        case "titleBarBackgroundActive": overrides.titleBarBackgroundActive = color
        case "titleBarBackgroundInactive": overrides.titleBarBackgroundInactive = color
        case "statusLineForegroundActive": overrides.statusLineForegroundActive = color
        case "statusLineForegroundInactive": overrides.statusLineForegroundInactive = color
        case "statusLineBackground": overrides.statusLineBackground = color
        case "paneBorderKeyboardTarget": overrides.paneBorderKeyboardTarget = color
        case "paneBorderActive": overrides.paneBorderActive = color
        case "paneBorderInactive": overrides.paneBorderInactive = color
        case "folderTreeBackground": overrides.folderTreeBackground = color
        case "folderTreeForeground": overrides.folderTreeForeground = color
        case "folderTreeSelectedForeground": overrides.folderTreeSelectedForeground = color
        case "folderTreeFolderIcon": overrides.folderTreeFolderIcon = color
        case "folderTreeSelectedActive": overrides.folderTreeSelectedActive = color
        case "folderTreeSelectedInactive": overrides.folderTreeSelectedInactive = color
        case "folderTreeSectionHeader": overrides.folderTreeSectionHeader = color
        case "splitHandleIdle": overrides.splitHandleIdle = color
        case "splitHandleActive": overrides.splitHandleActive = color
        case "gitModified": overrides.gitModified = color
        case "gitAdded": overrides.gitAdded = color
        case "gitDeleted": overrides.gitDeleted = color
        case "gitRenamed": overrides.gitRenamed = color
        case "gitUntracked": overrides.gitUntracked = color
        case "gitIgnored": overrides.gitIgnored = color
        case "gitConflicted": overrides.gitConflicted = color
        default:
            break
        }
    }

    private static func applyOpacityValue(
        key: String,
        value: String,
        line: Int,
        opacity: inout DesignOpacityTokens
    ) throws {
        let parsed = try parseDouble(value, line: line)
        guard parsed >= 0, parsed <= 1 else {
            throw DesignConfigurationError.invalidOpacity(line: line)
        }

        switch key {
        case "background": opacity.background = parsed
        case "inactivePane": opacity.inactivePane = parsed
        case "disabledItem": opacity.disabledItem = parsed
        case "headerSecondary": opacity.headerSecondary = parsed
        case "selectedParentRow": opacity.selectedParentRow = parsed
        case "dropIndicator": opacity.dropIndicator = parsed
        case "dragPreview": opacity.dragPreview = parsed
        case "dragPreviewShadow": opacity.dragPreviewShadow = parsed
        case "subtleBackground": opacity.subtleBackground = parsed
        default:
            break
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
            throw DesignConfigurationError.invalidString(line: line)
        }

        return String(value.dropFirst().dropLast())
    }

    private static func parseColor(_ value: String, line: Int) throws -> Color {
        let string = try parseString(value, line: line)
        guard string.hasPrefix("#"), string.count == 7 else {
            throw DesignConfigurationError.invalidColor(line: line)
        }

        let hex = String(string.dropFirst())
        guard let value = Int(hex, radix: 16) else {
            throw DesignConfigurationError.invalidColor(line: line)
        }

        let red = Double((value >> 16) & 0xff) / 255.0
        let green = Double((value >> 8) & 0xff) / 255.0
        let blue = Double(value & 0xff) / 255.0
        return Color(red: red, green: green, blue: blue)
    }

    private static func parseDouble(_ value: String, line: Int) throws -> Double {
        guard let parsed = Double(value) else {
            throw DesignConfigurationError.invalidNumber(line: line)
        }
        return parsed
    }

    private static func parseInt(_ value: String, line: Int) throws -> Int {
        guard let parsed = Int(value) else {
            throw DesignConfigurationError.invalidNumber(line: line)
        }
        return parsed
    }

    private static let defaultConfigSource = """
    version = 1

    [font]
    ui = "system"
    mono = "monospace"
    size = 13

    # Optional per-pane overrides. Empty family or size = 0 inherits global.
    #   fileList       fileListSize   — file rows, status line, archive view
    #   folderTree     folderTreeSize — folder tree + pinned list
    #   preview        previewSize    — preview pane (rendered + source)
    #   terminal       terminalSize   — built-in terminal pane
    # Examples:
    # terminal = "JetBrains Mono"
    # terminalSize = 13
    # previewSize = 14

    # Optional color overrides. Unspecified colors use the built-in tfx base.
    #
    # [colors]
    # fileListBackground = "#000301"
    # fileForeground = "#CFFFCF"
    # directoryForeground = "#6FFF80"
    #
    # Optional opacity overrides. Values must be between 0 and 1.
    #
    # [opacity]
    # background = 1
    # inactivePane = 0.5
    # disabledItem = 0.45

    [startup]
    # "single" starts with one pane and one tab.
    # "split" starts with two panes. If rightFolder / rightFolders is omitted, the
    # previous right-pane tabs are reused.
    # "restore" reuses the previous split state and pane tabs.
    layout = "single"
    # rightFolder = "~/Downloads"
    # rightFolders = ["~/Downloads", "~/Documents"]

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
    newTab = "cmd+shift+t"
    closeTab = "cmd+w"
    previousTab = "cmd+shift+["
    nextTab = "cmd+shift+]"
    toggleTerminalPane = "cmd+option+t"
    focusTerminalPane = "cmd+option+shift+t"
    toggleFolderTree = "cmd+option+f"

    # Optional application launch overrides.
    #
    # [terminal]
    # app = "/System/Applications/Utilities/Terminal.app"
    # bundleIdentifier = "com.apple.Terminal"
    #
    # [openWith]
    # md = "com.microsoft.VSCode"
    # pdf = "/Applications/Preview.app"
    """
}

private enum ConfiguredFontRegistrar {
    private static var didRegisterUserFonts = false

    static func resolve(_ family: String) -> String {
        guard !family.isEmpty else { return family }
        if NSFont(name: family, size: 13) != nil {
            return family
        }

        registerUserFontsIfNeeded()

        if let font = NSFont(name: family, size: 13) {
            return font.familyName ?? family
        }

        return family
    }

    private static func registerUserFontsIfNeeded() {
        guard !didRegisterUserFonts else { return }
        didRegisterUserFonts = true

        let fileManager = FileManager.default
        let directories = [
            fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent("Library", isDirectory: true)
                .appendingPathComponent("Fonts", isDirectory: true),
            URL(fileURLWithPath: "/Library/Fonts", isDirectory: true)
        ]

        for directory in directories {
            guard let urls = try? fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }

            for url in urls where isFontFile(url) {
                var error: Unmanaged<CFError>?
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
            }
        }
    }

    private static func isFontFile(_ url: URL) -> Bool {
        switch url.pathExtension.lowercased() {
        case "ttf", "otf", "ttc":
            return true
        default:
            return false
        }
    }
}

enum DesignConfigurationError: LocalizedError {
    case applicationSupportDirectoryUnavailable
    case invalidAssignment(line: Int)
    case invalidString(line: Int)
    case invalidNumber(line: Int)
    case invalidColor(line: Int)
    case invalidFontSize(line: Int)
    case invalidOpacity(line: Int)
    case unsupportedVersion(Int)

    var errorDescription: String? {
        switch self {
        case .applicationSupportDirectoryUnavailable:
            return "Application Support directory is unavailable."
        case let .invalidAssignment(line):
            return "Invalid config assignment at line \(line)."
        case let .invalidString(line):
            return "Invalid string value at line \(line)."
        case let .invalidNumber(line):
            return "Invalid number value at line \(line)."
        case let .invalidColor(line):
            return "Invalid color value at line \(line). Use \"#RRGGBB\"."
        case let .invalidFontSize(line):
            return "Font size at line \(line) must be between 8 and 40."
        case let .invalidOpacity(line):
            return "Opacity value at line \(line) must be between 0 and 1."
        case let .unsupportedVersion(version):
            return "Unsupported config version \(version)."
        }
    }
}
#endif
