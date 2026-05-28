#if os(macOS)
import Combine
import Foundation

@MainActor
final class BuiltInTerminalModel: ObservableObject {
    @Published var currentDirectory: URL
    @Published var transcript: String
    @Published var commandText = ""
    @Published var isRunning = false
    @Published var terminalExitRequestID = UUID()

    private var shellPath: String

    init(
        currentDirectory: URL = URL(fileURLWithPath: NSHomeDirectory()),
        shellPath: String = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
    ) {
        let initialDirectory = currentDirectory.standardizedFileURL
        self.currentDirectory = initialDirectory
        self.shellPath = shellPath.isEmpty ? "/bin/zsh" : shellPath
        transcript = "tfx built-in terminal\n\(Self.prompt(for: initialDirectory)) "
    }

    func followDirectory(_ directory: URL) {
        let standardizedDirectory = directory.standardizedFileURL
        guard currentDirectory != standardizedDirectory else { return }
        currentDirectory = standardizedDirectory
        transcript += "\ncd \(standardizedDirectory.path)\n\(Self.prompt(for: standardizedDirectory)) "
    }

    func submitCommand() {
        let command = commandText.trimmingCharacters(in: .whitespacesAndNewlines)
        commandText = ""
        guard !command.isEmpty, !isRunning else { return }

        transcript += command + "\n"
        if handleBuiltin(command) {
            transcript += Self.prompt(for: currentDirectory) + " "
            return
        }

        isRunning = true
        let directory = currentDirectory
        let shellPath = shellPath

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let output = Self.run(command, shellPath: shellPath, currentDirectory: directory)
            DispatchQueue.main.async {
                guard let self else { return }
                if !output.isEmpty {
                    self.transcript += output
                    if !output.hasSuffix("\n") {
                        self.transcript += "\n"
                    }
                }
                self.isRunning = false
                self.transcript += Self.prompt(for: self.currentDirectory) + " "
            }
        }
    }

    func insertPaths(_ urls: [URL]) {
        let arguments = urls
            .map { Self.shellQuotedPath($0.path) }
            .joined(separator: " ")
        guard !arguments.isEmpty else { return }

        if !commandText.isEmpty, commandText.last?.isWhitespace == false {
            commandText += " "
        }
        commandText += arguments
    }

    private func handleBuiltin(_ command: String) -> Bool {
        if Self.isExitCommand(command) {
            terminalExitRequestID = UUID()
            return true
        }

        guard command == "cd" || command.hasPrefix("cd ") else { return false }
        let rawPath = command == "cd" ? NSHomeDirectory() : Self.normalizedPathArgument(String(command.dropFirst(3)))
        let resolvedPath: String
        if rawPath.hasPrefix("~") {
            resolvedPath = (rawPath as NSString).expandingTildeInPath
        } else if rawPath.hasPrefix("/") {
            resolvedPath = rawPath
        } else {
            resolvedPath = currentDirectory.appendingPathComponent(rawPath).path
        }

        let url = URL(fileURLWithPath: resolvedPath).standardizedFileURL
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
            currentDirectory = url
        } else {
            transcript += "cd: no such directory: \(rawPath)\n"
        }
        return true
    }

    nonisolated static func isExitCommand(_ command: String) -> Bool {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed == "exit" || trimmed == "logout"
    }

    nonisolated private static func normalizedPathArgument(_ argument: String) -> String {
        let trimmed = argument.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return trimmed }

        let first = trimmed.first
        let last = trimmed.last
        if (first == "\"" && last == "\"") || (first == "'" && last == "'") {
            return String(trimmed.dropFirst().dropLast())
        }
        return trimmed.replacingOccurrences(of: "\\ ", with: " ")
    }

    nonisolated private static func run(_ command: String, shellPath: String, currentDirectory: URL) -> String {
        let process = Process()
        let outputPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: shellPath)
        process.arguments = ["-lc", command]
        process.currentDirectoryURL = currentDirectory
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return "Failed to run command: \(error.localizedDescription)\n"
        }
    }

    nonisolated static func shellQuotedPath(_ path: String) -> String {
        "'\(path.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    nonisolated private static func prompt(for directory: URL) -> String {
        "\(directory.path) $"
    }
}
#endif
