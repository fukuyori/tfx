#if os(macOS)
import SwiftUI
import UniformTypeIdentifiers

struct FileBrowserDropDelegate: DropDelegate {
    let model: FileBrowserModel
    let targetDirectory: URL
    var highlightedDirectory: URL?
    var isEnabled = true
    var reloadRelatedPanes: (() -> Void)?

    /// When `highlightedDirectory` is nil the drop targets the
    /// pane's current directory rather than a specific folder
    /// row, and we flip the pane-level highlight (`FilePane`'s
    /// border overlay) instead of a row background.
    private var isPaneLevelDrop: Bool { highlightedDirectory == nil }

    func validateDrop(info: DropInfo) -> Bool {
        isEnabled && info.hasItemsConforming(to: [UTType.fileURL.identifier])
    }

    func dropEntered(info: DropInfo) {
        guard isEnabled, info.hasItemsConforming(to: [UTType.fileURL.identifier]) else { return }
        if isPaneLevelDrop {
            model.setPaneDropTarget(true)
        } else {
            model.setDropTargetDirectory(highlightedDirectory)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        guard isEnabled, info.hasItemsConforming(to: [UTType.fileURL.identifier]) else {
            return DropProposal(operation: .forbidden)
        }

        if isPaneLevelDrop {
            model.setPaneDropTarget(true)
        } else {
            model.setDropTargetDirectory(highlightedDirectory)
        }
        return DropProposal(operation: dropOperation == .copy ? .copy : .move)
    }

    func dropExited(info: DropInfo) {
        if isPaneLevelDrop {
            model.setPaneDropTarget(false)
        } else {
            model.clearFileListDropTarget()
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        defer {
            if isPaneLevelDrop {
                model.setPaneDropTarget(false)
            } else {
                model.markFileListDropCompleted(on: highlightedDirectory)
                model.clearFileListDropTarget()
            }
        }

        guard isEnabled else { return false }
        let completion = {
            if isPaneLevelDrop {
                model.setPaneDropTarget(false)
            } else {
                model.markFileListDropCompleted(on: highlightedDirectory)
                model.clearFileListDropTarget()
            }
            reloadRelatedPanes?()
        }
        return model.moveDroppedFiles(
            info.itemProviders(for: [UTType.fileURL.identifier]),
            to: targetDirectory,
            operation: dropOperation,
            completion: completion
        )
    }

    private var dropOperation: FileClipboard.Operation {
        NSEvent.modifierFlags.contains(.option) ? .copy : .move
    }
}

#endif
