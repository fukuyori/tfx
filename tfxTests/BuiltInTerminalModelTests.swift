#if os(macOS)
import Foundation
import Testing
@testable import tfx

@Suite("BuiltInTerminalModel")
@MainActor
struct BuiltInTerminalModelTests {
    @Test
    func shellQuotedPathEscapesSingleQuotes() {
        #expect(BuiltInTerminalModel.shellQuotedPath("/tmp/has space/it's.txt") == "'/tmp/has space/it'\\''s.txt'")
    }

    @Test
    func insertPathsAppendsQuotedArguments() {
        let model = BuiltInTerminalModel(currentDirectory: URL(fileURLWithPath: "/tmp"))
        model.commandText = "cat"

        model.insertPaths([
            URL(fileURLWithPath: "/tmp/a file.txt"),
            URL(fileURLWithPath: "/tmp/it's.txt")
        ])

        #expect(model.commandText == "cat '/tmp/a file.txt' '/tmp/it'\\''s.txt'")
    }

    @Test
    func submitCommandStreamsPTYOutput() async throws {
        let model = BuiltInTerminalModel(
            currentDirectory: URL(fileURLWithPath: "/tmp"),
            shellPath: "/bin/sh"
        )
        model.commandText = "printf tfx_pty_ok"

        model.submitCommand()

        for _ in 0..<50 where !model.transcript.contains("tfx_pty_ok") {
            try await Task.sleep(for: .milliseconds(50))
        }

        #expect(model.transcript.contains("tfx_pty_ok"))
        model.commandText = "exit"
        model.submitCommand()
    }

    @Test
    func submitCommandHidesANSIControlSequences() async throws {
        let model = BuiltInTerminalModel(
            currentDirectory: URL(fileURLWithPath: "/tmp"),
            shellPath: "/bin/sh"
        )
        model.commandText = "printf '\\033[31mred\\033[0m'"

        model.submitCommand()

        for _ in 0..<50 where !model.transcript.contains("red") {
            try await Task.sleep(for: .milliseconds(50))
        }

        #expect(model.transcript.contains("red"))
        #expect(!model.transcript.contains("\u{001B}"))
        model.commandText = "exit"
        model.submitCommand()
    }

    @Test
    func insertPathsWritesSeparatedArgumentsToRunningPTY() async throws {
        let model = BuiltInTerminalModel(
            currentDirectory: URL(fileURLWithPath: "/tmp"),
            shellPath: "/bin/sh"
        )
        model.open()
        model.sendText("printf %s ")
        model.insertPaths([URL(fileURLWithPath: "/tmp/a file.txt")])
        model.sendReturn()

        for _ in 0..<50 where !model.transcript.contains("/tmp/a file.txt") {
            try await Task.sleep(for: .milliseconds(50))
        }

        #expect(model.transcript.contains("/tmp/a file.txt"))
        model.commandText = "exit"
        model.submitCommand()
    }

    @Test
    func terminalInputCDUpdatesCurrentDirectory() {
        let initialDirectory = URL(fileURLWithPath: NSHomeDirectory())
        let targetDirectory = URL(fileURLWithPath: "/tmp").standardizedFileURL
        let model = BuiltInTerminalModel(
            currentDirectory: initialDirectory,
            shellPath: "/bin/sh"
        )

        model.sendTerminalInput("cd /tmp\r")

        #expect(model.currentDirectory == targetDirectory)
        model.commandText = "exit"
        model.submitCommand()
    }

    @Test
    func closeAllowsFollowingDirectoryBeforeReopen() {
        let model = BuiltInTerminalModel(
            currentDirectory: URL(fileURLWithPath: NSHomeDirectory()),
            shellPath: "/bin/sh"
        )
        let targetDirectory = URL(fileURLWithPath: "/tmp").standardizedFileURL

        model.open()
        model.close()
        model.followDirectory(targetDirectory)

        #expect(model.currentDirectory == targetDirectory)
    }

    @Test
    func exitCommandRequestsPaneClose() {
        let model = BuiltInTerminalModel(currentDirectory: URL(fileURLWithPath: "/tmp"))
        let initialRequestID = model.terminalExitRequestID
        model.commandText = "exit"

        model.submitCommand()

        #expect(model.terminalExitRequestID != initialRequestID)
    }

    @Test(arguments: ["exit", " logout ", "cd /tmp", "exit now"])
    func exitCommandRecognition(command: String) {
        let expected = command.trimmingCharacters(in: .whitespacesAndNewlines) == "exit"
            || command.trimmingCharacters(in: .whitespacesAndNewlines) == "logout"
        #expect(BuiltInTerminalModel.isExitCommand(command) == expected)
    }
}
#endif
