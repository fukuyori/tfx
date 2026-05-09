#if os(macOS)
import AppKit
import SwiftUI

struct FileRowInteractionOverlay: NSViewRepresentable {
    let item: FileItem
    let model: FileBrowserModel
    let activate: () -> Void

    func makeNSView(context: Context) -> FileRowInteractionView {
        FileRowInteractionView(item: item, model: model, activate: activate)
    }

    func updateNSView(_ nsView: FileRowInteractionView, context: Context) {
        nsView.item = item
        nsView.model = model
        nsView.activate = activate
    }
}

final class FileRowInteractionView: NSView, NSDraggingSource {
    var item: FileItem
    weak var model: FileBrowserModel?
    var activate: () -> Void
    private var mouseDownEvent: NSEvent?
    private var hasStartedDrag = false

    init(item: FileItem, model: FileBrowserModel, activate: @escaping () -> Void) {
        self.item = item
        self.model = model
        self.activate = activate
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        item = FileItem(url: URL(fileURLWithPath: "/"))
        activate = {}
        super.init(coder: coder)
    }

    override func mouseDown(with event: NSEvent) {
        activate()
        mouseDownEvent = event
        hasStartedDrag = false

        if event.clickCount >= 2 {
            model?.select(item)
            model?.open(item)
            return
        }

        model?.selectForMouseDown(item, modifiers: event.modifierFlags)
    }

    override func mouseDragged(with event: NSEvent) {
        guard !hasStartedDrag, let mouseDownEvent, let model else { return }
        hasStartedDrag = true

        let dragItems = model.dragItemsForFileRow(item)
        guard !dragItems.isEmpty else { return }

        let draggingItems = dragItems.map { dragItem in
            let item = NSDraggingItem(pasteboardWriter: dragItem.url as NSURL)
            item.setDraggingFrame(
                NSRect(x: bounds.midX - 16, y: bounds.midY - 16, width: 32, height: 32),
                contents: FileIconCache.shared.icon(for: dragItem.url, cacheKey: dragItem.iconCacheKey, size: 32)
            )
            return item
        }
        beginDraggingSession(with: draggingItems, event: mouseDownEvent, source: self)
    }

    override func mouseUp(with event: NSEvent) {
        guard !hasStartedDrag else { return }
        model?.selectForMouseUp(item, modifiers: event.modifierFlags)
    }

    override func rightMouseDown(with event: NSEvent) {
        nextResponder?.rightMouseDown(with: event)
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        context == .outsideApplication ? .copy : [.copy, .move]
    }
}
#endif
