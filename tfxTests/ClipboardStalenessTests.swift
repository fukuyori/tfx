#if os(macOS)
import AppKit
import Foundation
import Testing
@testable import tfx

/// Covers the internal-clipboard staleness fix: the pane-local
/// `FileBrowserModel.clipboard` snapshot must never shadow fresher
/// system-pasteboard content, and a completed move-paste must not
/// leave a re-pastable "move" payload behind.
///
/// Pasteboard tests run against uniquely named pasteboards so the
/// user's real clipboard is never touched; the one test that needs
/// `NSPasteboard.general` only reads its `changeCount`.
@Suite("ClipboardStaleness")
@MainActor
struct ClipboardStalenessTests {
    private static func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("tfx-clipboard-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func makePasteboard() -> NSPasteboard {
        NSPasteboard(name: NSPasteboard.Name("org.spumoni.tfx.tests.\(UUID().uuidString)"))
    }

    @Test
    func pasteboardRoundTripKeepsOperation() throws {
        let dir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let fileURL = dir.appendingPathComponent("a.txt")
        FileManager.default.createFile(atPath: fileURL.path, contents: Data())

        let pasteboard = Self.makePasteboard()
        defer { pasteboard.releaseGlobally() }

        FileBrowserExternalActions.writeFileURLsToPasteboard([fileURL], operation: .move, pasteboard: pasteboard)
        let clipboard = try #require(FileBrowserExternalActions.fileClipboardFromPasteboard(pasteboard: pasteboard))
        #expect(clipboard.operation == .move)
        #expect(clipboard.urls.map(\.standardizedFileURL.path) == [fileURL.standardizedFileURL.path])
    }

    @Test
    func clearAfterMovePasteClearsMatchingMovePayload() throws {
        let dir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let fileURL = dir.appendingPathComponent("a.txt")
        FileManager.default.createFile(atPath: fileURL.path, contents: Data())

        let pasteboard = Self.makePasteboard()
        defer { pasteboard.releaseGlobally() }

        FileBrowserExternalActions.writeFileURLsToPasteboard([fileURL], operation: .move, pasteboard: pasteboard)
        FileBrowserExternalActions.clearPasteboardAfterMovePaste(of: [fileURL], pasteboard: pasteboard)
        #expect(FileBrowserExternalActions.fileClipboardFromPasteboard(pasteboard: pasteboard) == nil)
    }

    @Test
    func clearAfterMovePasteLeavesCopyPayload() throws {
        let dir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let fileURL = dir.appendingPathComponent("a.txt")
        FileManager.default.createFile(atPath: fileURL.path, contents: Data())

        let pasteboard = Self.makePasteboard()
        defer { pasteboard.releaseGlobally() }

        FileBrowserExternalActions.writeFileURLsToPasteboard([fileURL], operation: .copy, pasteboard: pasteboard)
        FileBrowserExternalActions.clearPasteboardAfterMovePaste(of: [fileURL], pasteboard: pasteboard)
        #expect(FileBrowserExternalActions.fileClipboardFromPasteboard(pasteboard: pasteboard) != nil)
    }

    @Test
    func clearAfterMovePasteLeavesUnrelatedMovePayload() throws {
        let dir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let movedURL = dir.appendingPathComponent("a.txt")
        let otherURL = dir.appendingPathComponent("b.txt")
        for url in [movedURL, otherURL] {
            FileManager.default.createFile(atPath: url.path, contents: Data())
        }

        let pasteboard = Self.makePasteboard()
        defer { pasteboard.releaseGlobally() }

        // A different app / pane has since written its own move
        // payload — clearing here would destroy someone else's cut.
        FileBrowserExternalActions.writeFileURLsToPasteboard([otherURL], operation: .move, pasteboard: pasteboard)
        FileBrowserExternalActions.clearPasteboardAfterMovePaste(of: [movedURL], pasteboard: pasteboard)
        #expect(FileBrowserExternalActions.fileClipboardFromPasteboard(pasteboard: pasteboard) != nil)
    }

    @Test
    func pasteOperationPlanSkipsMissingSources() throws {
        let sourceDir = try Self.makeTempDir()
        let targetDir = try Self.makeTempDir()
        defer {
            try? FileManager.default.removeItem(at: sourceDir)
            try? FileManager.default.removeItem(at: targetDir)
        }
        let existingURL = sourceDir.appendingPathComponent("present.txt")
        let missingURL = sourceDir.appendingPathComponent("gone.txt")
        FileManager.default.createFile(atPath: existingURL.path, contents: Data())

        let clipboard = FileClipboard(urls: [existingURL, missingURL], operation: .copy)
        let plan = try #require(try FileBrowserFileOperations.pasteOperationPlan(clipboard, into: targetDir))
        #expect(plan.requests.map(\.sourceURL.standardizedFileURL.path) == [existingURL.standardizedFileURL.path])

        let allMissing = FileClipboard(urls: [missingURL], operation: .copy)
        #expect(try FileBrowserFileOperations.pasteOperationPlan(allMissing, into: targetDir) == nil)
    }

    @Test
    func validatedInternalClipboardDropsStaleSnapshot() throws {
        let dir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let fileURL = dir.appendingPathComponent("a.txt")
        FileManager.default.createFile(atPath: fileURL.path, contents: Data())

        let model = FileBrowserModel(initialDirectory: dir)
        let snapshot = FileClipboard(urls: [fileURL], operation: .copy)

        // Matching changeCount — the snapshot is current and survives.
        model.clipboard = snapshot
        model.clipboardPasteboardChangeCount = NSPasteboard.general.changeCount
        #expect(model.validatedInternalClipboard() != nil)
        #expect(model.clipboard != nil)

        // The pasteboard has been written since (simulated by an
        // outdated recorded count) — the snapshot is dropped for good.
        model.clipboardPasteboardChangeCount = NSPasteboard.general.changeCount - 1
        #expect(model.validatedInternalClipboard() == nil)
        #expect(model.clipboard == nil)
        #expect(model.clipboardPasteboardChangeCount == nil)
    }
}
#endif
