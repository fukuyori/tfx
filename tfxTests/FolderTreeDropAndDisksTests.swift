#if os(macOS)
import AppKit
import SwiftUI
import Testing
@testable import tfx

@Suite("FolderTreeFileDrop")
struct FolderTreeFileDropTests {
    @Test
    func refusesDroppingItemOntoItself() {
        let folder = URL(fileURLWithPath: "/tmp/source", isDirectory: true)
        #expect(!FolderTreeFileDropDelegate.isValidTarget(folder, draggedURLs: [folder]))
    }

    @Test
    func refusesDroppingFolderIntoItsOwnDescendant() {
        let folder = URL(fileURLWithPath: "/tmp/source", isDirectory: true)
        let descendant = URL(fileURLWithPath: "/tmp/source/child/grandchild", isDirectory: true)
        #expect(!FolderTreeFileDropDelegate.isValidTarget(descendant, draggedURLs: [folder]))
    }

    @Test
    func allowsSiblingFolderTargetWithSharedNamePrefix() {
        // "/tmp/source-backup" must not be mistaken for a descendant of
        // "/tmp/source" by a naive string-prefix comparison.
        let folder = URL(fileURLWithPath: "/tmp/source", isDirectory: true)
        let sibling = URL(fileURLWithPath: "/tmp/source-backup", isDirectory: true)
        #expect(FolderTreeFileDropDelegate.isValidTarget(sibling, draggedURLs: [folder]))
    }

    @Test
    func allowsUnrelatedTarget() {
        let folder = URL(fileURLWithPath: "/tmp/a", isDirectory: true)
        let target = URL(fileURLWithPath: "/tmp/b", isDirectory: true)
        #expect(FolderTreeFileDropDelegate.isValidTarget(target, draggedURLs: [folder]))
    }

    @Test
    func sameVolumeDragDefaultsToMove() throws {
        let fileManager = FileManager.default
        let base = fileManager.temporaryDirectory
            .appendingPathComponent("tfx-tree-drop-\(UUID().uuidString)", isDirectory: true)
        let source = base.appendingPathComponent("source", isDirectory: true)
        let target = base.appendingPathComponent("target", isDirectory: true)
        try fileManager.createDirectory(at: source, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: target, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: base) }

        #expect(FolderTreeFileDropDelegate.defaultOperation(for: [source], target: target) == .move)
    }

    @Test
    func emptyDragListDefaultsToMove() {
        let target = URL(fileURLWithPath: "/tmp", isDirectory: true)
        #expect(FolderTreeFileDropDelegate.defaultOperation(for: [], target: target) == .move)
    }
}

@Suite("ConfigFileEditor", .serialized)
struct ConfigFileEditorTests {
    /// Runs `body` with the config-editor default temporarily set to
    /// `path`, restoring the user's real value afterwards — the tests
    /// share the app's standard UserDefaults.
    private func withStoredEditorPath(_ path: String?, body: () -> Void) {
        let defaults = UserDefaults.standard
        let original = defaults.string(forKey: ConfigFileEditor.editorDefaultsKey)
        defer {
            if let original {
                defaults.set(original, forKey: ConfigFileEditor.editorDefaultsKey)
            } else {
                defaults.removeObject(forKey: ConfigFileEditor.editorDefaultsKey)
            }
        }
        if let path {
            defaults.set(path, forKey: ConfigFileEditor.editorDefaultsKey)
        } else {
            defaults.removeObject(forKey: ConfigFileEditor.editorDefaultsKey)
        }
        body()
    }

    @Test
    func unsetEditorFallsBackToSystemDefault() {
        withStoredEditorPath(nil) {
            #expect(ConfigFileEditor.configuredEditorURL == nil)
        }
    }

    @Test
    func deletedEditorFallsBackToSystemDefault() {
        withStoredEditorPath("/Applications/NoSuchEditor.app") {
            #expect(ConfigFileEditor.configuredEditorURL == nil)
        }
    }

    @Test
    func existingEditorIsUsed() {
        let textEdit = "/System/Applications/TextEdit.app"
        withStoredEditorPath(textEdit) {
            #expect(ConfigFileEditor.configuredEditorURL?.path == textEdit)
        }
    }
}

@Suite("VolumeList")
struct VolumeListTests {
    @Test
    func loadVolumesIncludesRootVolume() {
        let volumes = VolumeListStore.loadVolumes()
        #expect(!volumes.isEmpty)

        let root = volumes.first { $0.url.path == "/" }
        #expect(root != nil)
        #expect((root?.totalCapacity ?? 0) > 0)
    }

    @Test
    func usedFractionStaysWithinBounds() {
        let volume = VolumeInfo(
            url: URL(fileURLWithPath: "/", isDirectory: true),
            name: "Macintosh HD",
            totalCapacity: 1_000,
            availableCapacity: 250,
            icon: NSImage()
        )
        #expect(volume.usedFraction == 0.75)

        let empty = VolumeInfo(
            url: URL(fileURLWithPath: "/", isDirectory: true),
            name: "Empty",
            totalCapacity: 0,
            availableCapacity: 0,
            icon: NSImage()
        )
        #expect(empty.usedFraction == 0)
    }
}
#endif
