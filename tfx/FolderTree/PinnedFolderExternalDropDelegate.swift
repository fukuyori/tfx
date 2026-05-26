#if os(macOS)
import AppKit
import SwiftUI

struct PinnedFolderExternalDropOverlay: NSViewRepresentable {
    let model: FileBrowserModel
    let rowHeight: CGFloat

    func makeNSView(context: Context) -> PinnedFolderExternalDropView {
        PinnedFolderExternalDropView(model: model, rowHeight: rowHeight)
    }

    func updateNSView(_ nsView: PinnedFolderExternalDropView, context: Context) {
        nsView.model = model
        nsView.rowHeight = rowHeight
    }
}

final class PinnedFolderExternalDropView: NSView {
    weak var model: FileBrowserModel?
    var rowHeight: CGFloat

    init(model: FileBrowserModel, rowHeight: CGFloat) {
        self.model = model
        self.rowHeight = rowHeight
        super.init(frame: .zero)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) {
        rowHeight = 26
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL])
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        updatePreview(for: sender)
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        updatePreview(for: sender)
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        model?.cancelExternalPinDropPreview()
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        model?.cancelExternalPinDropPreview()
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        canAccept(sender)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let model, canAccept(sender) else { return false }

        let insertionIndex = model.pinnedFolderInsertionIndex ?? model.pinnedFolders.count
        model.pinnedExternalDropCompletedAt = Date()
        model.cancelExternalPinDropPreview()

        let urls = sender.draggingPasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL] ?? []

        model.acceptExternalPinDrop(urls: urls, at: insertionIndex)
        return true
    }

    private func updatePreview(for sender: NSDraggingInfo) -> NSDragOperation {
        guard let model, canAccept(sender), !model.isDraggingPinnedFolder else {
            return []
        }

        let point = convert(sender.draggingLocation, from: nil)
        model.updateExternalPinDropPreview(y: bounds.height - point.y, rowHeight: rowHeight)
        return .move
    }

    private func canAccept(_ sender: NSDraggingInfo) -> Bool {
        sender.draggingPasteboard.canReadObject(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        )
    }
}

#endif
