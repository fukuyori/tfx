#if os(macOS)
import SwiftUI
import UniformTypeIdentifiers

/// Drop delegate scoped to an executable file's name cell. Drops
/// are routed to the executable as arguments — `.app` bundles
/// launch via `NSWorkspace.open(_:withApplicationAt:...)`,
/// regular executables run via `Process` with each dropped URL's
/// path appended as an argument. Hover state is recorded in the
/// model via the same `highlightedDropDirectory` slot the folder
/// delegate uses, so the name cell shows the same pill highlight.
struct FileExecuteDropDelegate: DropDelegate {
    let model: FileBrowserModel
    let executableURL: URL
    let isApplicationBundle: Bool
    var isEnabled = true

    func validateDrop(info: DropInfo) -> Bool {
        isEnabled && info.hasItemsConforming(to: [UTType.fileURL.identifier])
    }

    func dropEntered(info: DropInfo) {
        guard isEnabled, info.hasItemsConforming(to: [UTType.fileURL.identifier]) else { return }
        model.setDropTargetDirectory(executableURL)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        guard isEnabled, info.hasItemsConforming(to: [UTType.fileURL.identifier]) else {
            return DropProposal(operation: .forbidden)
        }
        model.setDropTargetDirectory(executableURL)
        // Always advertise `.copy` here — the dropped items are
        // not actually consumed; they only become arguments to
        // the target executable. `.copy` reads as "open with"
        // in the cursor decoration, which matches the intent.
        return DropProposal(operation: .copy)
    }

    func dropExited(info: DropInfo) {
        model.clearDropTargetDirectory(executableURL)
    }

    func performDrop(info: DropInfo) -> Bool {
        defer { model.clearDropTargetDirectory(executableURL) }
        guard isEnabled else { return false }
        return model.executeDroppedFiles(
            info.itemProviders(for: [UTType.fileURL.identifier]),
            on: executableURL,
            isApplicationBundle: isApplicationBundle
        )
    }
}

#endif
