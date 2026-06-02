#if os(macOS)
import AppKit
import Combine
import Foundation

struct UserCommand: Identifiable, Equatable {
    enum Target: String {
        case file
        case folder
        case current
        case any
    }

    enum Selection: String {
        case single
        case multiple
        case any
    }

    let id = UUID()
    var name: String
    var run: String
    var extensions: Set<String> = []
    var target: Target = .any
    var selection: Selection = .any
    var requireGit = false
    var terminal = false
    var shortcut: ShortcutInfo?
    var shell: String?

    func matches(selection items: [FileItem], isGitRepository: Bool) -> Bool {
        if requireGit && !isGitRepository {
            return false
        }

        if target == .current {
            return true
        }

        guard !items.isEmpty else { return false }

        switch selection {
        case .single where items.count != 1:
            return false
        case .multiple where items.count < 2:
            return false
        default:
            break
        }

        for item in items {
            if target == .file && item.isDirectory {
                return false
            }
            if target == .folder && !item.isDirectory {
                return false
            }
            if !extensions.isEmpty, !extensions.contains("*") {
                let itemExtension = item.url.pathExtension.lowercased()
                if !extensions.contains(itemExtension) {
                    return false
                }
            }
        }

        return true
    }
}

@MainActor
final class UserCommandStore: ObservableObject {
    @Published private(set) var commands: [UserCommand] = []
    @Published private(set) var configurationError: String?

    init() {
        reload()
    }

    func reload() {
        do {
            commands = try UserCommandConfigurationLoader.load()
            configurationError = nil
        } catch {
            commands = []
            configurationError = error.localizedDescription
        }
    }

    func matchingCommands(selection: [FileItem], currentDirectory: URL, isGitRepository: Bool) -> [UserCommand] {
        commands.filter { command in
            command.matches(selection: selection, isGitRepository: isGitRepository)
        }
    }

    func firstMatchingShortcut(
        for event: NSEvent,
        selection: [FileItem],
        currentDirectory: URL,
        isGitRepository: Bool
    ) -> UserCommand? {
        commands.first { command in
            command.shortcut?.matches(event) == true &&
                command.matches(selection: selection, isGitRepository: isGitRepository)
        }
    }

    func dismissConfigurationError() {
        configurationError = nil
    }
}

enum UserCommandConfigurationLoader {
    static let appSupportDirectoryName = "tfx"
    static let fileName = "config.toml"

    static func load(fileManager: FileManager = .default) throws -> [UserCommand] {
        let configURL = try configFileURL(fileManager: fileManager)
        guard fileManager.fileExists(atPath: configURL.path) else {
            return []
        }

        let source = try String(contentsOf: configURL, encoding: .utf8)
        return try parse(source)
    }

    static func configFileURL(fileManager: FileManager = .default) throws -> URL {
        guard let appSupportURL = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw UserCommandConfigurationError.applicationSupportDirectoryUnavailable
        }

        return appSupportURL
            .appendingPathComponent(appSupportDirectoryName, isDirectory: true)
            .appendingPathComponent(fileName, isDirectory: false)
    }

    static func scriptsDirectory(fileManager: FileManager = .default) throws -> URL {
        let directory = try configFileURL(fileManager: fileManager)
            .deletingLastPathComponent()
            .appendingPathComponent("scripts", isDirectory: true)
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }

    static func parse(_ source: String) throws -> [UserCommand] {
        var commands: [UserCommand] = []
        var section = ""
        var draft: UserCommandDraft?
        var lineNumber = 0
        let lines = source.components(separatedBy: .newlines)

        func finishDraft() {
            guard let current = draft?.command else { return }
            commands.append(current)
        }

        while lineNumber < lines.count {
            let rawLine = lines[lineNumber]
            lineNumber += 1
            let strippedLine = stripComment(from: rawLine).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !strippedLine.isEmpty else { continue }

            if strippedLine == "[[commands]]" {
                finishDraft()
                draft = UserCommandDraft()
                section = "commands"
                continue
            }

            if strippedLine.hasPrefix("[") && strippedLine.hasSuffix("]") {
                finishDraft()
                draft = nil
                section = String(strippedLine.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
                continue
            }

            let parts = strippedLine.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else {
                throw UserCommandConfigurationError.invalidAssignment(line: lineNumber)
            }

            let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)

            if section == "", key == "version" {
                let version = try parseInt(value, line: lineNumber)
                guard version == 1 else {
                    throw UserCommandConfigurationError.unsupportedVersion(version)
                }
                continue
            }

            guard section == "commands", draft != nil else { continue }

            let resolvedValue: String
            if value.hasPrefix("'''") {
                resolvedValue = try parseMultilineLiteral(
                    initialValue: value,
                    lines: lines,
                    lineNumber: &lineNumber
                )
            } else {
                resolvedValue = value
            }
            try draft?.apply(key: key, value: resolvedValue, line: lineNumber)
        }

        finishDraft()
        return commands
    }

    private static func parseMultilineLiteral(
        initialValue: String,
        lines: [String],
        lineNumber: inout Int
    ) throws -> String {
        let body = String(initialValue.dropFirst(3))
        if let closeRange = body.range(of: "'''") {
            return String(body[..<closeRange.lowerBound])
        }

        var result = body.isEmpty ? "" : body + "\n"
        while lineNumber < lines.count {
            let rawLine = lines[lineNumber]
            lineNumber += 1
            if let closeRange = rawLine.range(of: "'''") {
                result += rawLine[..<closeRange.lowerBound]
                return result
            }
            result += rawLine + "\n"
        }

        throw UserCommandConfigurationError.unterminatedLiteral(line: lineNumber)
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

    fileprivate static func parseString(_ value: String, line: Int) throws -> String {
        guard value.hasPrefix("\""), value.hasSuffix("\""), value.count >= 2 else {
            throw UserCommandConfigurationError.invalidString(line: line)
        }

        return String(value.dropFirst().dropLast())
    }

    fileprivate static func parseStringArray(_ value: String, line: Int) throws -> [String] {
        guard value.hasPrefix("["), value.hasSuffix("]") else {
            throw UserCommandConfigurationError.invalidString(line: line)
        }

        let body = value.dropFirst().dropLast().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return [] }
        return try body.split(separator: ",", omittingEmptySubsequences: false).map { item in
            try parseString(item.trimmingCharacters(in: .whitespacesAndNewlines), line: line)
        }
    }

    fileprivate static func parseBool(_ value: String, line: Int) throws -> Bool {
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "true":
            return true
        case "false":
            return false
        default:
            throw UserCommandConfigurationError.invalidBool(line: line)
        }
    }

    private static func parseInt(_ value: String, line: Int) throws -> Int {
        guard let parsed = Int(value) else {
            throw UserCommandConfigurationError.invalidNumber(line: line)
        }
        return parsed
    }
}

private struct UserCommandDraft {
    var name: String?
    var run: String?
    var extensions: Set<String> = []
    var target: UserCommand.Target = .any
    var selection: UserCommand.Selection = .any
    var requireGit = false
    var terminal = false
    var shortcut: ShortcutInfo?
    var shell: String?

    var command: UserCommand? {
        guard
            let name = name?.trimmingCharacters(in: .whitespacesAndNewlines),
            !name.isEmpty,
            let run = run,
            !run.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return nil
        }
        return UserCommand(
            name: name,
            run: run,
            extensions: extensions,
            target: target,
            selection: selection,
            requireGit: requireGit,
            terminal: terminal,
            shortcut: shortcut,
            shell: shell
        )
    }

    mutating func apply(key: String, value: String, line: Int) throws {
        switch key {
        case "name":
            name = try UserCommandConfigurationLoader.parseString(value, line: line)
        case "run":
            if value.hasPrefix("\"") {
                run = try UserCommandConfigurationLoader.parseString(value, line: line)
            } else {
                run = value
            }
        case "extensions":
            extensions = Set(try UserCommandConfigurationLoader.parseStringArray(value, line: line).map {
                $0.trimmingCharacters(in: CharacterSet(charactersIn: ".").union(.whitespacesAndNewlines)).lowercased()
            })
        case "target":
            let rawValue = try UserCommandConfigurationLoader.parseString(value, line: line)
            guard let parsed = UserCommand.Target(rawValue: rawValue) else {
                throw UserCommandConfigurationError.invalidTarget(line: line)
            }
            target = parsed
        case "selection":
            let rawValue = try UserCommandConfigurationLoader.parseString(value, line: line)
            guard let parsed = UserCommand.Selection(rawValue: rawValue) else {
                throw UserCommandConfigurationError.invalidSelection(line: line)
            }
            selection = parsed
        case "requireGit":
            requireGit = try UserCommandConfigurationLoader.parseBool(value, line: line)
        case "terminal":
            terminal = try UserCommandConfigurationLoader.parseBool(value, line: line)
        case "shortcut":
            shortcut = try ShortcutConfigurationLoader.parseUserShortcut(
                try UserCommandConfigurationLoader.parseString(value, line: line),
                line: line
            )
        case "shell":
            shell = try UserCommandConfigurationLoader.parseString(value, line: line)
        default:
            break
        }
    }
}

enum UserCommandConfigurationError: LocalizedError {
    case applicationSupportDirectoryUnavailable
    case invalidAssignment(line: Int)
    case invalidString(line: Int)
    case invalidNumber(line: Int)
    case invalidBool(line: Int)
    case invalidTarget(line: Int)
    case invalidSelection(line: Int)
    case unterminatedLiteral(line: Int)
    case unsupportedVersion(Int)

    var errorDescription: String? {
        switch self {
        case .applicationSupportDirectoryUnavailable:
            return "Application Support directory is unavailable."
        case let .invalidAssignment(line):
            return "Invalid command assignment at line \(line)."
        case let .invalidString(line):
            return "Invalid command string at line \(line)."
        case let .invalidNumber(line):
            return "Invalid command number at line \(line)."
        case let .invalidBool(line):
            return "Invalid command boolean at line \(line). Use true or false."
        case let .invalidTarget(line):
            return "Invalid command target at line \(line). Use \"file\", \"folder\", \"current\", or \"any\"."
        case let .invalidSelection(line):
            return "Invalid command selection at line \(line). Use \"single\", \"multiple\", or \"any\"."
        case let .unterminatedLiteral(line):
            return "Unterminated command script literal near line \(line)."
        case let .unsupportedVersion(version):
            return "Unsupported config version \(version)."
        }
    }
}

enum UserCommandRunner {
    struct Invocation {
        let executableURL: URL
        let arguments: [String]
        let workingDirectory: URL
        let commandBody: String
    }

    static func execute(
        _ command: UserCommand,
        selection: [FileItem],
        currentDirectory: URL,
        terminalModel: BuiltInTerminalModel?,
        onError: @escaping (Error) -> Void
    ) {
        do {
            let scriptsDirectory = try UserCommandConfigurationLoader.scriptsDirectory()
            let invocation = try invocation(
                for: command,
                selection: selection,
                currentDirectory: currentDirectory,
                scriptsDirectory: scriptsDirectory
            )
            let process = Process()
            process.executableURL = invocation.executableURL
            process.arguments = invocation.arguments
            process.currentDirectoryURL = invocation.workingDirectory

            if command.terminal, let terminalModel {
                try executeCapturingOutput(
                    process,
                    command: command,
                    invocation: invocation,
                    terminalModel: terminalModel
                )
                return
            }

            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try process.run()
        } catch {
            onError(error)
        }
    }

    private static func executeCapturingOutput(
        _ process: Process,
        command: UserCommand,
        invocation: Invocation,
        terminalModel: BuiltInTerminalModel
    ) throws {
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        terminalModel.appendUserCommandOutput("$ \(command.name)\n# cwd: \(invocation.workingDirectory.path)\n")

        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor in
                terminalModel.appendUserCommandOutput(text)
            }
        }
        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor in
                terminalModel.appendUserCommandOutput(text)
            }
        }
        process.terminationHandler = { _ in
            outputPipe.fileHandleForReading.readabilityHandler = nil
            errorPipe.fileHandleForReading.readabilityHandler = nil
            Task { @MainActor in
                terminalModel.appendUserCommandOutput("\n")
            }
        }

        try process.run()
    }

    private static func invocation(
        for command: UserCommand,
        selection: [FileItem],
        currentDirectory: URL,
        scriptsDirectory: URL
    ) throws -> Invocation {
        let shellCommandLine = command.shell ?? ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let shellParts = splitShellCommandLine(shellCommandLine)
        let shellPath = shellParts.first ?? "/bin/zsh"
        let shellArguments = Array(shellParts.dropFirst())
        let workingDirectory = workingDirectory(selection: selection, currentDirectory: currentDirectory)
        let body = buildCommandBody(
            command.run,
            selection: selection,
            currentDirectory: currentDirectory,
            scriptsDirectory: scriptsDirectory
        )

        if body.contains("\n") {
            let scriptURL = try writeTemporaryScript(body, shellPath: shellPath)
            return Invocation(
                executableURL: URL(fileURLWithPath: shellPath),
                arguments: shellArguments + scriptArguments(shellPath: shellPath, scriptURL: scriptURL),
                workingDirectory: workingDirectory,
                commandBody: body
            )
        }

        return Invocation(
            executableURL: URL(fileURLWithPath: shellPath),
            arguments: shellArguments + ["-lc", body],
            workingDirectory: workingDirectory,
            commandBody: body
        )
    }

    static func testInvocation(
        for command: UserCommand,
        selection: [FileItem],
        currentDirectory: URL,
        scriptsDirectory: URL
    ) throws -> Invocation {
        try invocation(
            for: command,
            selection: selection,
            currentDirectory: currentDirectory,
            scriptsDirectory: scriptsDirectory
        )
    }

    private static func buildCommandBody(
        _ source: String,
        selection: [FileItem],
        currentDirectory: URL,
        scriptsDirectory: URL
    ) -> String {
        let firstURL = selection.first?.url ?? currentDirectory
        let firstDirectory = selection.first.map { $0.url.deletingLastPathComponent() } ?? currentDirectory
        let paths = selection.isEmpty ? shellQuote(currentDirectory.path) : selection.map { shellQuote($0.url.path) }.joined(separator: " ")
        let name = firstURL.lastPathComponent
        let stem = firstURL.deletingPathExtension().lastPathComponent
        let ext = firstURL.pathExtension

        return expandEnvironmentVariables(source)
            .replacingOccurrences(of: "{scripts}", with: scriptsDirectory.path)
            .replacingOccurrences(of: "{paths}", with: paths)
            .replacingOccurrences(of: "{path}", with: shellQuote(firstURL.path))
            .replacingOccurrences(of: "{cwd}", with: shellQuote(currentDirectory.path))
            .replacingOccurrences(of: "{dir}", with: shellQuote(firstDirectory.path))
            .replacingOccurrences(of: "{name}", with: shellQuote(name))
            .replacingOccurrences(of: "{stem}", with: shellQuote(stem))
            .replacingOccurrences(of: "{ext}", with: shellQuote(ext))
    }

    private static func writeTemporaryScript(_ body: String, shellPath: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("tfx", isDirectory: true)
            .appendingPathComponent("commands", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let scriptURL = directory.appendingPathComponent("command-\(UUID().uuidString)\(scriptExtension(shellPath: shellPath))")
        try body.write(to: scriptURL, atomically: true, encoding: .utf8)
        return scriptURL
    }

    private static func scriptExtension(shellPath: String) -> String {
        let name = URL(fileURLWithPath: shellPath).lastPathComponent.lowercased()
        if name.contains("pwsh") || name.contains("powershell") {
            return ".ps1"
        }
        return ".sh"
    }

    private static func scriptArguments(shellPath: String, scriptURL: URL) -> [String] {
        let name = URL(fileURLWithPath: shellPath).lastPathComponent.lowercased()
        if name.contains("pwsh") || name.contains("powershell") {
            return ["-NoProfile", "-File", scriptURL.path]
        }
        return [scriptURL.path]
    }

    private static func workingDirectory(selection: [FileItem], currentDirectory: URL) -> URL {
        let directory = selection.first?.url.deletingLastPathComponent() ?? currentDirectory
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory), isDirectory.boolValue {
            return directory
        }
        return URL(fileURLWithPath: NSHomeDirectory())
    }

    private static func shellQuote(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    private static func splitShellCommandLine(_ commandLine: String) -> [String] {
        var result: [String] = []
        var current = ""
        var quote: Character?
        var isEscaped = false

        for character in commandLine {
            if isEscaped {
                current.append(character)
                isEscaped = false
                continue
            }
            if character == "\\" {
                isEscaped = true
                continue
            }
            if let activeQuote = quote {
                if character == activeQuote {
                    quote = nil
                } else {
                    current.append(character)
                }
                continue
            }
            if character == "\"" || character == "'" {
                quote = character
                continue
            }
            if character.isWhitespace {
                if !current.isEmpty {
                    result.append(current)
                    current = ""
                }
            } else {
                current.append(character)
            }
        }

        if !current.isEmpty {
            result.append(current)
        }
        return result
    }

    private static func expandEnvironmentVariables(_ source: String) -> String {
        var result = ""
        var index = source.startIndex
        let environment = ProcessInfo.processInfo.environment

        while index < source.endIndex {
            guard source[index] == "$" else {
                result.append(source[index])
                index = source.index(after: index)
                continue
            }

            let next = source.index(after: index)
            if next < source.endIndex, source[next] == "{" {
                var nameEnd = source.index(after: next)
                while nameEnd < source.endIndex, source[nameEnd] != "}" {
                    nameEnd = source.index(after: nameEnd)
                }
                if nameEnd < source.endIndex {
                    let name = String(source[source.index(after: next)..<nameEnd])
                    result += environment[name] ?? ""
                    index = source.index(after: nameEnd)
                    continue
                }
            }

            var nameEnd = next
            while nameEnd < source.endIndex {
                let character = source[nameEnd]
                if character.isLetter || character.isNumber || character == "_" {
                    nameEnd = source.index(after: nameEnd)
                } else {
                    break
                }
            }
            if nameEnd > next {
                let name = String(source[next..<nameEnd])
                result += environment[name] ?? ""
                index = nameEnd
            } else {
                result.append(source[index])
                index = next
            }
        }

        return result
    }
}
#endif
