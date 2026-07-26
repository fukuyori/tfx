#if os(macOS)
import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Snapshot of the in-flight drag over one folder-tree row.
struct FolderTreeDropContext {
    let targetDirectory: URL
    let draggedURLs: [URL]
    let isValidTarget: Bool
    let defaultOperation: FileClipboard.Operation
}

/// Drop delegate for FOLDERS-tree rows: files dragged from a file pane
/// (or another app) can be dropped onto a tree node to move or copy
/// them into that folder.
///
/// Operation choice follows the Finder convention: a same-volume drag
/// defaults to Move, a cross-volume drag defaults to Copy; holding
/// Option forces Copy and holding Command forces Move. Dropping items
/// onto themselves or onto one of their own descendants is refused.
struct FolderTreeFileDropDelegate: DropDelegate {
    let model: FileBrowserModel
    let targetDirectory: URL

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [UTType.fileURL.identifier])
    }

    func dropEntered(info: DropInfo) {
        guard validateDrop(info: info) else { return }
        let context = Self.makeContext(target: targetDirectory)
        model.folderTreeDropContext = context
        guard context.isValidTarget else { return }
        model.setDropTargetDirectory(targetDirectory)
        model.scheduleFolderTreeSpringExpansion(of: targetDirectory)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        guard validateDrop(info: info) else {
            return DropProposal(operation: .forbidden)
        }
        let context = currentContext()
        guard context.isValidTarget else {
            return DropProposal(operation: .forbidden)
        }
        model.setDropTargetDirectory(targetDirectory)
        return DropProposal(operation: resolvedOperation(context) == .copy ? .copy : .move)
    }

    func dropExited(info: DropInfo) {
        model.cancelFolderTreeSpringExpansion()
        model.clearDropTargetDirectory(targetDirectory)
        if model.folderTreeDropContext?.targetDirectory == targetDirectory.standardizedFileURL {
            model.folderTreeDropContext = nil
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        model.cancelFolderTreeSpringExpansion()
        let context = currentContext()
        model.folderTreeDropContext = nil

        let clear = { [model] in
            model.clearFileListDropTarget()
        }
        guard context.isValidTarget else {
            clear()
            return false
        }

        let accepted = model.moveDroppedFiles(
            info.itemProviders(for: [UTType.fileURL.identifier]),
            to: targetDirectory,
            operation: resolvedOperation(context),
            completion: clear
        )
        if !accepted {
            clear()
        }
        return accepted
    }

    // MARK: - Context

    private func currentContext() -> FolderTreeDropContext {
        if let context = model.folderTreeDropContext,
           context.targetDirectory == targetDirectory.standardizedFileURL {
            return context
        }
        let context = Self.makeContext(target: targetDirectory)
        model.folderTreeDropContext = context
        return context
    }

    /// Modifier override beats the volume-based default.
    private func resolvedOperation(_ context: FolderTreeDropContext) -> FileClipboard.Operation {
        let modifiers = NSEvent.modifierFlags
        if modifiers.contains(.option) { return .copy }
        if modifiers.contains(.command) { return .move }
        return context.defaultOperation
    }

    static func makeContext(target: URL) -> FolderTreeDropContext {
        // AppKit keeps the dragged file URLs on the drag pasteboard for
        // the whole session (both tfx's own `beginDraggingSession` drags
        // and drags arriving from Finder or other apps), so they can be
        // inspected before the drop happens — `NSItemProvider` loading
        // is only available asynchronously in `performDrop`.
        let draggedURLs = (NSPasteboard(name: .drag)
            .readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? [])
            .map(\.standardizedFileURL)

        let standardizedTarget = target.standardizedFileURL
        return FolderTreeDropContext(
            targetDirectory: standardizedTarget,
            draggedURLs: draggedURLs,
            isValidTarget: isValidTarget(standardizedTarget, draggedURLs: draggedURLs),
            defaultOperation: defaultOperation(for: draggedURLs, target: standardizedTarget)
        )
    }

    /// A target is invalid when it *is* one of the dragged items or
    /// lives inside one (moving a folder into its own subtree would
    /// destroy it; the deeper copy cases are re-checked by the file
    /// operation layer, this is the immediate cursor feedback).
    static func isValidTarget(_ target: URL, draggedURLs: [URL]) -> Bool {
        let targetPath = target.path
        for dragged in draggedURLs {
            let draggedPath = dragged.path
            if targetPath == draggedPath || targetPath.hasPrefix(draggedPath + "/") {
                return false
            }
        }
        return true
    }

    /// Finder-style default: Move within one volume, Copy across
    /// volumes. Unknown volumes (external drags with unreadable
    /// metadata) fall back to Move, matching the file panes' default.
    static func defaultOperation(for draggedURLs: [URL], target: URL) -> FileClipboard.Operation {
        guard !draggedURLs.isEmpty,
              let targetVolume = volumeURL(of: target) else {
            return .move
        }
        for dragged in draggedURLs {
            guard let sourceVolume = volumeURL(of: dragged) else { continue }
            if sourceVolume != targetVolume {
                return .copy
            }
        }
        return .move
    }

    private static func volumeURL(of url: URL) -> URL? {
        (try? url.resourceValues(forKeys: [.volumeURLKey]))?.volume?.standardizedFileURL
    }
}
#endif
