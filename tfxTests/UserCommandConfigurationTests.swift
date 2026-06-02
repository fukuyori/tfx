#if os(macOS)
import Foundation
import Testing
@testable import tfx

@Suite("UserCommandConfiguration")
struct UserCommandConfigurationTests {
    @Test
    func commandErrorsIncludeCommandIndexAndName() throws {
        do {
            _ = try UserCommandConfigurationLoader.parse("""
            version = 1

            [[commands]]
            name = "Build Project"
            run = "swift build"
            target = "project"
            """)
            Issue.record("Expected command configuration error")
        } catch {
            let message = error.localizedDescription
            #expect(message.contains("Invalid user command #1 \"Build Project\""))
            #expect(message.contains("line 6"))
            #expect(message.contains("Invalid command target"))
        }
    }

    @Test
    func commandErrorsIncludeCommandIndexBeforeNameIsKnown() throws {
        do {
            _ = try UserCommandConfigurationLoader.parse("""
            version = 1

            [[commands]]
            name = Build Project
            run = "swift build"
            """)
            Issue.record("Expected command configuration error")
        } catch {
            let message = error.localizedDescription
            #expect(message.contains("Invalid user command #1"))
            #expect(message.contains("line 4"))
            #expect(message.contains("Invalid command string"))
        }
    }

    @Test
    func currentTargetMatchesEmptySelectionForEmptyAreaMenu() throws {
        let commands = try UserCommandConfigurationLoader.parse("""
        version = 1

        [[commands]]
        name = "git status"
        run = "git -C {cwd} status"
        target = "current"
        selection = "single"
        """)

        let command = try #require(commands.first)

        #expect(command.matches(selection: [], isGitRepository: false))
    }

    @Test
    func currentTargetInvocationUsesCurrentDirectoryWithoutSelection() throws {
        let commands = try UserCommandConfigurationLoader.parse("""
        version = 1

        [[commands]]
        name = "pwd"
        run = "printf {path}; printf {dir}; printf {cwd}"
        target = "current"
        """)

        let command = try #require(commands.first)
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("tfx-test-\(UUID().uuidString)", isDirectory: true)
        let scriptsDirectory = directory.appendingPathComponent("scripts", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let invocation = try UserCommandRunner.testInvocation(
            for: command,
            selection: [],
            currentDirectory: directory,
            scriptsDirectory: scriptsDirectory
        )

        #expect(invocation.workingDirectory.path == directory.path)
        #expect(invocation.commandBody == "printf '\(directory.path)'; printf '\(directory.path)'; printf '\(directory.path)'")
    }

    @Test
    func folderTargetCanMatchExtensionFilter() throws {
        let commands = try UserCommandConfigurationLoader.parse("""
        version = 1

        [[commands]]
        name = "swift run"
        run = '''
        cd {dir}
        swift run
        '''
        extensions = ["xcodeproj"]
        target = "folder"
        terminal = true
        """)

        let command = try #require(commands.first)
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("tfx-test-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("App.xcodeproj", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: directory.deletingLastPathComponent())
        }
        let item = FileItem(url: directory)

        #expect(command.matches(selection: [item], isGitRepository: false))
    }

    @Test
    func dirTokenUsesSelectedItemParentDirectory() throws {
        let commands = try UserCommandConfigurationLoader.parse("""
        version = 1

        [[commands]]
        name = "swift run"
        run = '''
        cd {dir}
        swift run
        '''
        extensions = ["xcodeproj"]
        target = "folder"
        terminal = true
        """)

        let command = try #require(commands.first)
        let parent = FileManager.default.temporaryDirectory
            .appendingPathComponent("tfx-test-\(UUID().uuidString)", isDirectory: true)
        let project = parent.appendingPathComponent("App.xcodeproj", isDirectory: true)
        let scriptsDirectory = parent.appendingPathComponent("scripts", isDirectory: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: parent)
        }

        let invocation = try UserCommandRunner.testInvocation(
            for: command,
            selection: [FileItem(url: project)],
            currentDirectory: parent,
            scriptsDirectory: scriptsDirectory
        )

        #expect(invocation.workingDirectory.path == parent.path)
        #expect(invocation.commandBody.contains("cd '\(parent.path)'"))
        #expect(invocation.commandBody.contains("swift run"))
    }

    @Test
    func nameTokenUsesSelectedFolderNameForFolderSelection() throws {
        let commands = try UserCommandConfigurationLoader.parse("""
        version = 1

        [[commands]]
        name = "swift run"
        run = '''
        cd {dir}
        cd {name}
        swift run
        '''
        extensions = ["xcodeproj"]
        target = "folder"
        terminal = true
        """)

        let command = try #require(commands.first)
        let parent = FileManager.default.temporaryDirectory
            .appendingPathComponent("tfx-test-\(UUID().uuidString)", isDirectory: true)
        let project = parent.appendingPathComponent("App.xcodeproj", isDirectory: true)
        let scriptsDirectory = parent.appendingPathComponent("scripts", isDirectory: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: parent)
        }

        let invocation = try UserCommandRunner.testInvocation(
            for: command,
            selection: [FileItem(url: project)],
            currentDirectory: parent,
            scriptsDirectory: scriptsDirectory
        )

        #expect(invocation.commandBody.contains("cd 'App.xcodeproj'"))
    }

    @Test
    @MainActor
    func terminalCommandStreamsOutputWithoutWritingToInteractiveShell() async throws {
        let commands = try UserCommandConfigurationLoader.parse("""
        version = 1

        [[commands]]
        name = "echo"
        run = "printf user_command_output"
        target = "current"
        terminal = true
        """)

        let command = try #require(commands.first)
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("tfx-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let terminalModel = BuiltInTerminalModel(currentDirectory: directory, shellPath: "/bin/sh")
        UserCommandRunner.execute(
            command,
            selection: [],
            currentDirectory: directory,
            terminalModel: terminalModel,
            onError: { error in
                Issue.record("Unexpected command error: \(error)")
            }
        )

        for _ in 0..<100 where !terminalModel.commandOutputTranscript.contains("user_command_output") {
            try await Task.sleep(for: .milliseconds(50))
        }

        #expect(terminalModel.activeTab == .output)
        #expect(terminalModel.commandOutputTranscript.contains("user_command_output"))
        #expect(!terminalModel.transcript.contains("user_command_output"))
    }
}
#endif
