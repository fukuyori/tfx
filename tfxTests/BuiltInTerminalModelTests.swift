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
