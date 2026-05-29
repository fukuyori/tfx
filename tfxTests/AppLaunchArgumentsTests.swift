#if os(macOS)
import Foundation
import Testing
@testable import tfx

@Suite("AppLaunchArguments")
struct AppLaunchArgumentsTests {
    @Test
    func parsesStartupAndVisibilityOptions() {
        let parsed = AppLaunchArguments.parse(arguments: [
            "tfx",
            "-2",
            "-P",
            "-t",
        ])

        #expect(parsed.startupLayout == .split)
        #expect(parsed.previewVisible == false)
        #expect(parsed.terminalVisible == true)
    }

    @Test
    func lastStartupAndVisibilityOptionWins() {
        let parsed = AppLaunchArguments.parse(arguments: [
            "tfx",
            "--single",
            "--restore",
            "--preview",
            "--no-preview",
            "--terminal",
            "--no-terminal",
        ])

        #expect(parsed.startupLayout == .restore)
        #expect(parsed.previewVisible == false)
        #expect(parsed.terminalVisible == false)
    }

    @Test
    func parsesVersionOption() {
        let parsed = AppLaunchArguments.parse(arguments: ["tfx", "-v"])

        #expect(parsed.shouldPrintVersion)
    }

    @Test
    func parsesHelpOption() {
        let parsed = AppLaunchArguments.parse(arguments: ["tfx", "-h"])

        #expect(parsed.shouldPrintHelp)
        #expect(AppLaunchArguments.helpText.contains("--help"))
        #expect(AppLaunchArguments.helpText.contains("--version"))
    }

    @Test
    func parsesFirstValidDirectory() throws {
        let temporaryDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let parsed = AppLaunchArguments.parse(arguments: [
            "tfx",
            "--split",
            "/definitely/missing",
            temporaryDirectory.path,
        ])

        #expect(parsed.initialDirectory == temporaryDirectory.standardizedFileURL)
    }
}
#endif
