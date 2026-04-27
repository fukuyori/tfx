#if os(macOS)
import SwiftUI
import UniformTypeIdentifiers

struct FileBrowserDropDelegate: DropDelegate {
    let model: FileBrowserModel
    let targetDirectory: URL
    var highlightedDirectory: URL?
    var isEnabled = true
    var reloadRelatedPanes: (() -> Void)?

    func validateDrop(info: DropInfo) -> Bool {
        isEnabled && info.hasItemsConforming(to: [UTType.fileURL.identifier])
    }

    func dropEntered(info: DropInfo) {
        guard isEnabled, info.hasItemsConforming(to: [UTType.fileURL.identifier]) else { return }
        model.setDropTargetDirectory(highlightedDirectory)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        guard isEnabled, info.hasItemsConforming(to: [UTType.fileURL.identifier]) else {
            return DropProposal(operation: .forbidden)
        }

        model.setDropTargetDirectory(highlightedDirectory)
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        model.clearDropTargetDirectory(highlightedDirectory)
    }

    func performDrop(info: DropInfo) -> Bool {
        defer {
            model.clearDropTargetDirectory(highlightedDirectory)
        }

        guard isEnabled else { return false }
        return model.moveDroppedFiles(
            info.itemProviders(for: [UTType.fileURL.identifier]),
            to: targetDirectory,
            completion: reloadRelatedPanes
        )
    }
}

#endif
