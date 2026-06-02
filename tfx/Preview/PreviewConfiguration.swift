#if os(macOS)
import Foundation
import Combine

struct PreviewConfiguration: Equatable {
    enum Mode: String, Equatable {
        case auto
        case rendered
        case text
        case none
    }

    enum ExternalImagePolicy: String, Equatable {
        case button
        case always
        case never
    }

    var defaultMode: Mode = .auto
    var extensionModes: [String: Mode] = [:]
    var markdownExternalImages: ExternalImagePolicy = .button

    static let `default` = PreviewConfiguration()

    func mode(for url: URL) -> Mode {
        for extensionName in extensionModes.keys.sorted(by: { $0.count > $1.count }) {
            if url.path.lowercased().hasSuffix(".\(extensionName)") {
                return extensionModes[extensionName] ?? defaultMode
            }
        }
        return defaultMode
    }

    static func normalizedExtension(_ value: String) -> String {
        value
            .trimmingCharacters(in: CharacterSet(charactersIn: ".").union(.whitespacesAndNewlines))
            .lowercased()
    }
}

@MainActor
final class PreviewConfigurationStore: ObservableObject {
    @Published private(set) var configuration = PreviewConfiguration.default
    @Published private(set) var configurationError: String?

    init() {
        reload()
    }

    func reload() {
        do {
            configuration = try PreviewConfigurationLoader.load()
            configurationError = nil
        } catch {
            configuration = .default
            configurationError = error.localizedDescription
        }
    }

    func dismissConfigurationError() {
        configurationError = nil
    }
}

enum PreviewConfigurationLoader {
    static let appSupportDirectoryName = "tfx"
    static let fileName = "config.toml"

    static func load(fileManager: FileManager = .default) throws -> PreviewConfiguration {
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
            throw PreviewConfigurationError.applicationSupportDirectoryUnavailable
        }

        return appSupportURL
            .appendingPathComponent(appSupportDirectoryName, isDirectory: true)
            .appendingPathComponent(fileName, isDirectory: false)
    }

    static func parse(_ source: String) throws -> PreviewConfiguration {
        var section = ""
        var configuration = PreviewConfiguration.default

        for (index, rawLine) in source.components(separatedBy: .newlines).enumerated() {
            let lineNumber = index + 1
            let line = stripComment(from: rawLine).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            if line.hasPrefix("[") && line.hasSuffix("]") {
                section = String(line.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
                continue
            }

            guard ["", "preview", "preview.extensions", "preview.markdown"].contains(section) else {
                continue
            }

            let parts = line.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else {
                throw PreviewConfigurationError.invalidAssignment(line: lineNumber)
            }

            let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)

            switch section {
            case "":
                if key == "version" {
                    let version = try parseInt(value, line: lineNumber)
                    guard version == 1 else {
                        throw PreviewConfigurationError.unsupportedVersion(version)
                    }
                }
            case "preview":
                if key == "default" {
                    configuration.defaultMode = try parseMode(value, line: lineNumber)
                }
            case "preview.extensions":
                let extensionName = PreviewConfiguration.normalizedExtension(try parseKey(key, line: lineNumber))
                guard !extensionName.isEmpty else {
                    throw PreviewConfigurationError.invalidExtension(line: lineNumber)
                }
                configuration.extensionModes[extensionName] = try parseMode(value, line: lineNumber)
            case "preview.markdown":
                if key == "externalImages" {
                    configuration.markdownExternalImages = try parseExternalImagePolicy(value, line: lineNumber)
                }
            default:
                continue
            }
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
            throw PreviewConfigurationError.invalidString(line: line)
        }

        return String(value.dropFirst().dropLast())
    }

    private static func parseMode(_ value: String, line: Int) throws -> PreviewConfiguration.Mode {
        let rawValue = try parseString(value, line: line)
        guard let mode = PreviewConfiguration.Mode(rawValue: rawValue) else {
            throw PreviewConfigurationError.invalidMode(line: line)
        }
        return mode
    }

    private static func parseExternalImagePolicy(_ value: String, line: Int) throws -> PreviewConfiguration.ExternalImagePolicy {
        let rawValue = try parseString(value, line: line)
        guard let policy = PreviewConfiguration.ExternalImagePolicy(rawValue: rawValue) else {
            throw PreviewConfigurationError.invalidExternalImagePolicy(line: line)
        }
        return policy
    }

    private static func parseInt(_ value: String, line: Int) throws -> Int {
        guard let parsed = Int(value) else {
            throw PreviewConfigurationError.invalidNumber(line: line)
        }
        return parsed
    }
}

enum PreviewConfigurationError: LocalizedError {
    case applicationSupportDirectoryUnavailable
    case invalidAssignment(line: Int)
    case invalidString(line: Int)
    case invalidNumber(line: Int)
    case invalidExtension(line: Int)
    case invalidMode(line: Int)
    case invalidExternalImagePolicy(line: Int)
    case unsupportedVersion(Int)

    var errorDescription: String? {
        switch self {
        case .applicationSupportDirectoryUnavailable:
            return "Application Support directory is unavailable."
        case let .invalidAssignment(line):
            return "Invalid preview assignment at line \(line)."
        case let .invalidString(line):
            return "Invalid preview string at line \(line)."
        case let .invalidNumber(line):
            return "Invalid preview number at line \(line)."
        case let .invalidExtension(line):
            return "Invalid preview extension at line \(line)."
        case let .invalidMode(line):
            return "Invalid preview mode at line \(line). Use \"auto\", \"rendered\", \"text\", or \"none\"."
        case let .invalidExternalImagePolicy(line):
            return "Invalid Markdown external image policy at line \(line). Use \"button\", \"always\", or \"never\"."
        case let .unsupportedVersion(version):
            return "Unsupported config version \(version)."
        }
    }
}
#endif
