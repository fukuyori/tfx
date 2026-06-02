#if os(macOS)
import AppKit
import Foundation

struct AppLaunchConfiguration: Equatable {
    var startupLayout: StartupLayoutMode = .single
    var startupRightFolder: URL?
    var startupRightFolders: [URL] = []
    var terminalApplication: ApplicationReference?
    var openWithApplications: [String: ApplicationReference] = [:]

    static let `default` = AppLaunchConfiguration()

    var startupRightFolderURLs: [URL] {
        if !startupRightFolders.isEmpty {
            return startupRightFolders
        }
        return startupRightFolder.map { [$0] } ?? []
    }

    func application(forFile url: URL) -> ApplicationReference? {
        let extensionName = url.pathExtension.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !extensionName.isEmpty else { return nil }
        return openWithApplications[extensionName]
    }
}

enum StartupLayoutMode: String, Equatable {
    case single
    case split
    case restore
}

enum ApplicationReference: Equatable {
    case path(URL)
    case bundleIdentifier(String)

    init(_ rawValue: String) {
        let expanded = NSString(string: rawValue).expandingTildeInPath
        if expanded.hasPrefix("/") || expanded.hasSuffix(".app") || expanded.contains("/") {
            self = .path(URL(fileURLWithPath: expanded))
        } else {
            self = .bundleIdentifier(rawValue)
        }
    }

    func resolvedURL() -> URL? {
        switch self {
        case let .path(url):
            return url
        case let .bundleIdentifier(identifier):
            return NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier)
        }
    }
}

enum AppLaunchConfigurationLoader {
    static let appSupportDirectoryName = "tfx"
    static let fileName = "config.toml"

    static func load(fileManager: FileManager = .default) throws -> AppLaunchConfiguration {
        let configURL = try configFileURL(fileManager: fileManager)
        guard fileManager.fileExists(atPath: configURL.path) else {
            return .default
        }

        let source = try String(contentsOf: configURL, encoding: .utf8)
        return try parse(source)
    }

    static func configFileURL(fileManager: FileManager = .default) throws -> URL {
        guard let appSupportURL = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw AppLaunchConfigurationError.applicationSupportDirectoryUnavailable
        }

        return appSupportURL
            .appendingPathComponent(appSupportDirectoryName, isDirectory: true)
            .appendingPathComponent(fileName, isDirectory: false)
    }

    static func parse(_ source: String) throws -> AppLaunchConfiguration {
        var section = ""
        var configuration = AppLaunchConfiguration.default
        var terminalBundleIdentifier: String?

        for (index, rawLine) in source.components(separatedBy: .newlines).enumerated() {
            let lineNumber = index + 1
            let line = stripComment(from: rawLine).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            if line.hasPrefix("[") && line.hasSuffix("]") {
                section = String(line.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
                continue
            }

            guard ["", "terminal", "startup", "openWith"].contains(section) else {
                continue
            }

            let parts = line.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else {
                throw AppLaunchConfigurationError.invalidAssignment(line: lineNumber)
            }

            let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)

            switch section {
            case "":
                if key == "version" {
                    let version = try parseInt(value, line: lineNumber)
                    guard version == 1 else {
                        throw AppLaunchConfigurationError.unsupportedVersion(version)
                    }
                }
            case "terminal":
                switch key {
                case "app":
                    configuration.terminalApplication = ApplicationReference(try parseString(value, line: lineNumber))
                case "bundleIdentifier":
                    terminalBundleIdentifier = try parseString(value, line: lineNumber)
                default:
                    continue
                }
            case "startup":
                switch key {
                case "layout":
                    let rawLayout = try parseString(value, line: lineNumber)
                    guard let layout = StartupLayoutMode(rawValue: rawLayout) else {
                        throw AppLaunchConfigurationError.invalidStartupLayout(line: lineNumber)
                    }
                    configuration.startupLayout = layout
                case "rightFolder":
                    configuration.startupRightFolder = URL(
                        fileURLWithPath: NSString(string: try parseString(value, line: lineNumber)).expandingTildeInPath
                    ).standardizedFileURL
                case "rightFolders":
                    configuration.startupRightFolders = try parseStringArray(value, line: lineNumber).map {
                        URL(fileURLWithPath: NSString(string: $0).expandingTildeInPath).standardizedFileURL
                    }
                default:
                    continue
                }
            case "openWith":
                let extensionName = try parseKey(key, line: lineNumber)
                    .trimmingCharacters(in: CharacterSet(charactersIn: ".").union(.whitespacesAndNewlines))
                    .lowercased()
                guard !extensionName.isEmpty else {
                    throw AppLaunchConfigurationError.invalidExtension(line: lineNumber)
                }
                configuration.openWithApplications[extensionName] = ApplicationReference(try parseString(value, line: lineNumber))
            default:
                continue
            }
        }

        if configuration.terminalApplication == nil, let terminalBundleIdentifier {
            configuration.terminalApplication = .bundleIdentifier(terminalBundleIdentifier)
        }

        return configuration
    }

    private static func parseKey(_ value: String, line: Int) throws -> String {
        if value.hasPrefix("\"") || value.hasSuffix("\"") {
            return try parseString(value, line: line)
        }
        return value
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
            throw AppLaunchConfigurationError.invalidString(line: line)
        }

        return String(value.dropFirst().dropLast())
    }

    private static func parseStringArray(_ value: String, line: Int) throws -> [String] {
        guard value.hasPrefix("["), value.hasSuffix("]") else {
            throw AppLaunchConfigurationError.invalidString(line: line)
        }

        let body = value.dropFirst().dropLast().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return [] }

        return try body.split(separator: ",", omittingEmptySubsequences: false).map { item in
            try parseString(item.trimmingCharacters(in: .whitespacesAndNewlines), line: line)
        }
    }

    private static func parseInt(_ value: String, line: Int) throws -> Int {
        guard let parsed = Int(value) else {
            throw AppLaunchConfigurationError.invalidNumber(line: line)
        }
        return parsed
    }
}

enum AppLaunchConfigurationError: LocalizedError {
    case applicationSupportDirectoryUnavailable
    case invalidAssignment(line: Int)
    case invalidString(line: Int)
    case invalidNumber(line: Int)
    case invalidExtension(line: Int)
    case invalidStartupLayout(line: Int)
    case unsupportedVersion(Int)
    case applicationUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .applicationSupportDirectoryUnavailable:
            return "Application Support directory is unavailable."
        case let .invalidAssignment(line):
            return "Invalid app launch assignment at line \(line)."
        case let .invalidString(line):
            return "Invalid app launch string at line \(line)."
        case let .invalidNumber(line):
            return "Invalid app launch number at line \(line)."
        case let .invalidExtension(line):
            return "Invalid extension key at line \(line)."
        case let .invalidStartupLayout(line):
            return "Invalid startup layout at line \(line). Use \"single\", \"split\", or \"restore\"."
        case let .unsupportedVersion(version):
            return "Unsupported config version \(version)."
        case let .applicationUnavailable(reference):
            return "Configured application is unavailable: \(reference)"
        }
    }
}

#endif
