#if os(macOS)
import Foundation
import Testing
@testable import tfx

/// Focused tests for `FileBrowserModel` mutators.
///
/// Touches model state only; async reload completion isn't awaited. The
/// model's reload work happens on background queues and finishes after the
/// test if it hasn't already — the model is `[weak self]` driven, so a torn
/// down model simply drops in-flight work.
@Suite("FileBrowserModel")
@MainActor
struct FileBrowserModelTests {
    private static func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("tfx-model-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test
    func initialStateReflectsInitialDirectory() throws {
        let dir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let model = FileBrowserModel(initialDirectory: dir)
        #expect(model.currentDirectory == dir.standardizedFileURL)
        #expect(!model.canGoBack)
        #expect(!model.canGoForward)
        #expect(model.selectedItemIDs.isEmpty)
        #expect(model.primarySelectedItemID == nil)
        #expect(!model.isParentDirectorySelected)
    }

    @Test
    func navigateRecordsHistory() throws {
        let dirA = try Self.makeTempDir()
        let dirB = try Self.makeTempDir()
        defer {
            try? FileManager.default.removeItem(at: dirA)
            try? FileManager.default.removeItem(at: dirB)
        }

        let model = FileBrowserModel(initialDirectory: dirA)
        model.navigate(to: dirB)
        #expect(model.currentDirectory == dirB.standardizedFileURL)
        #expect(model.canGoBack)
        #expect(!model.canGoForward)
    }

    @Test
    func goBackRestoresPreviousDirectory() throws {
        let dirA = try Self.makeTempDir()
        let dirB = try Self.makeTempDir()
        defer {
            try? FileManager.default.removeItem(at: dirA)
            try? FileManager.default.removeItem(at: dirB)
        }

        let model = FileBrowserModel(initialDirectory: dirA)
        model.navigate(to: dirB)
        model.goBack()
        #expect(model.currentDirectory == dirA.standardizedFileURL)
        #expect(!model.canGoBack)
        #expect(model.canGoForward)
    }

    @Test
    func goForwardReturnsToLaterDirectory() throws {
        let dirA = try Self.makeTempDir()
        let dirB = try Self.makeTempDir()
        defer {
            try? FileManager.default.removeItem(at: dirA)
            try? FileManager.default.removeItem(at: dirB)
        }

        let model = FileBrowserModel(initialDirectory: dirA)
        model.navigate(to: dirB)
        model.goBack()
        model.goForward()
        #expect(model.currentDirectory == dirB.standardizedFileURL)
        #expect(model.canGoBack)
        #expect(!model.canGoForward)
    }

    @Test
    func newNavigationClearsForwardStack() throws {
        let dirA = try Self.makeTempDir()
        let dirB = try Self.makeTempDir()
        let dirC = try Self.makeTempDir()
        defer {
            try? FileManager.default.removeItem(at: dirA)
            try? FileManager.default.removeItem(at: dirB)
            try? FileManager.default.removeItem(at: dirC)
        }

        let model = FileBrowserModel(initialDirectory: dirA)
        model.navigate(to: dirB)
        model.goBack()
        #expect(model.canGoForward)
        model.navigate(to: dirC)
        #expect(!model.canGoForward)
    }

    @Test
    func clearSelectionResetsAllSelectionState() throws {
        let dir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let model = FileBrowserModel(initialDirectory: dir)
        let dummy = dir.appendingPathComponent("dummy").standardizedFileURL
        model.selectedItemIDs = [dummy]
        model.primarySelectedItemID = dummy
        model.selectionAnchorItemID = dummy
        model.isParentDirectorySelected = true

        model.clearSelection()

        #expect(model.selectedItemIDs.isEmpty)
        #expect(model.primarySelectedItemID == nil)
        #expect(model.selectionAnchorItemID == nil)
        #expect(!model.isParentDirectorySelected)
    }

    @Test
    func navigateClearsSelection() throws {
        let dirA = try Self.makeTempDir()
        let dirB = try Self.makeTempDir()
        defer {
            try? FileManager.default.removeItem(at: dirA)
            try? FileManager.default.removeItem(at: dirB)
        }

        let model = FileBrowserModel(initialDirectory: dirA)
        let dummy = dirA.appendingPathComponent("dummy").standardizedFileURL
        model.selectedItemIDs = [dummy]
        model.primarySelectedItemID = dummy

        model.navigate(to: dirB)

        #expect(model.selectedItemIDs.isEmpty)
        #expect(model.primarySelectedItemID == nil)
    }

    @Test
    func navigateToSameDirectoryIsNoOp() throws {
        let dir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let model = FileBrowserModel(initialDirectory: dir)
        model.navigate(to: dir)
        // No history is recorded since the destination matches current.
        #expect(!model.canGoBack)
    }
}
#endif
