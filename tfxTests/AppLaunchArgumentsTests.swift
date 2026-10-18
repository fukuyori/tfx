#if os(macOS)
import AppKit
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
    func newWindowIsRequestedByNewOrLayoutOptions() {
        #expect(!AppLaunchArguments.parse(arguments: ["tfx"]).requestsNewWindow)
        #expect(!AppLaunchArguments.parse(arguments: ["tfx", "/"]).requestsNewWindow)
        #expect(AppLaunchArguments.parse(arguments: ["tfx", "--new"]).requestsNewWindow)
        #expect(AppLaunchArguments.parse(arguments: ["tfx", "-2"]).requestsNewWindow)
        #expect(AppLaunchArguments.parse(arguments: ["tfx", "-P"]).requestsNewWindow)
        #expect(AppLaunchArguments.parse(arguments: ["tfx", "-t"]).requestsNewWindow)
        #expect(AppLaunchArguments.parse(arguments: ["tfx", "-g", "800x600"]).requestsNewWindow)
    }

    @Test
    @MainActor
    func hostForwardingFallsBackOutsideTfxTerminal() {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)

        #expect(!AppOpenDirectoryForwarding.forwardToHost(directory, environment: [:]))
        #expect(!AppOpenDirectoryForwarding.forwardToHost(directory, environment: ["TFX_PID": "not-a-pid"]))
        // Our own PID is never treated as the host.
        #expect(!AppOpenDirectoryForwarding.forwardToHost(
            directory,
            environment: ["TFX_PID": String(ProcessInfo.processInfo.processIdentifier)]
        ))
    }

    @Test
    func forwardedRequestsAreValidated() throws {
        let ownPID: pid_t = 4242
        let folder = FileManager.default.temporaryDirectory.standardizedFileURL
        let file = folder.appendingPathComponent("tfx-forward-\(UUID().uuidString).txt")
        try Data().write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }

        #expect(AppOpenDirectoryForwarding.requestedDirectory(
            from: ["pid": Int(ownPID), "path": folder.path], ownPID: ownPID
        ) == folder)
        // Addressed to another tfx.
        #expect(AppOpenDirectoryForwarding.requestedDirectory(
            from: ["pid": Int(ownPID) + 1, "path": folder.path], ownPID: ownPID
        ) == nil)
        // Not a folder, missing, relative, or malformed.
        #expect(AppOpenDirectoryForwarding.requestedDirectory(
            from: ["pid": Int(ownPID), "path": file.path], ownPID: ownPID
        ) == nil)
        #expect(AppOpenDirectoryForwarding.requestedDirectory(
            from: ["pid": Int(ownPID), "path": "/no/such/tfx/folder"], ownPID: ownPID
        ) == nil)
        #expect(AppOpenDirectoryForwarding.requestedDirectory(
            from: ["pid": Int(ownPID), "path": "tmp"], ownPID: ownPID
        ) == nil)
        #expect(AppOpenDirectoryForwarding.requestedDirectory(from: nil, ownPID: ownPID) == nil)
    }

    @Test
    @MainActor
    func openDocumentsEventYieldsFileURLs() {
        func event(with directObject: NSAppleEventDescriptor) -> NSAppleEventDescriptor {
            let event = NSAppleEventDescriptor(
                eventClass: AEEventClass(kCoreEventClass),
                eventID: AEEventID(kAEOpenDocuments),
                targetDescriptor: nil,
                returnID: AEReturnID(kAutoGenerateReturnID),
                transactionID: AETransactionID(kAnyTransactionID)
            )
            event.setParam(directObject, forKeyword: keyDirectObject)
            return event
        }
        let first = URL(fileURLWithPath: "/tmp", isDirectory: true)
        let second = URL(fileURLWithPath: "/usr", isDirectory: true)

        let single = AppOpenDirectoryDelegate.fileURLs(in: event(with: NSAppleEventDescriptor(fileURL: first)))
        #expect(single.map(\.path) == [first.path])

        let list = NSAppleEventDescriptor.list()
        list.insert(NSAppleEventDescriptor(fileURL: first), at: 1)
        list.insert(NSAppleEventDescriptor(fileURL: second), at: 2)
        #expect(AppOpenDirectoryDelegate.fileURLs(in: event(with: list)).map(\.path) == [first.path, second.path])
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
