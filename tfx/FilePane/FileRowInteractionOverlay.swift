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
    private var mouseDownWasSelected = false
    private var hasStartedDrag = false
    private var hasStartedRangeSelection = false
    private var trackingArea: NSTrackingArea?

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

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingArea {
            removeTrackingArea(trackingArea)
        }

        let nextTrackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(nextTrackingArea)
        trackingArea = nextTrackingArea
    }

    override func mouseDown(with event: NSEvent) {
        activate()
        mouseDownEvent = event
        mouseDownWasSelected = model?.isSelected(item) == true
        hasStartedDrag = false
        hasStartedRangeSelection = false

        if event.clickCount >= 2 {
            model?.select(item)
            model?.open(item)
            return
        }

        model?.selectForMouseDown(item, modifiers: event.modifierFlags)
    }

    override func mouseDragged(with event: NSEvent) {
        guard !hasStartedDrag, let mouseDownEvent, let model else { return }

        let horizontalOffset = event.locationInWindow.x - mouseDownEvent.locationInWindow.x
        let verticalOffset = event.locationInWindow.y - mouseDownEvent.locationInWindow.y
        let isVerticalRangeSelection = abs(verticalOffset) >= abs(horizontalOffset)

        if isVerticalRangeSelection {
            if !hasStartedRangeSelection {
                hasStartedRangeSelection = true
                model.beginMouseRangeSelection(from: item, modifiers: mouseDownEvent.modifierFlags)
            }

            model.updateMouseRangeSelection(startingAt: item, verticalOffset: verticalOffset, rowHeight: max(bounds.height, 1))
            return
        }

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

    override func mouseEntered(with event: NSEvent) {
        guard NSEvent.pressedMouseButtons & 1 == 1 else { return }
        model?.updateMouseRangeSelection(to: item)
    }

    override func mouseUp(with event: NSEvent) {
        if hasStartedRangeSelection {
            model?.finishMouseRangeSelection()
            return
        }

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
