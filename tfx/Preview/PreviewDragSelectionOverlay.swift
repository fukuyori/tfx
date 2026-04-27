#if os(macOS)
import AppKit
import SwiftUI

struct PreviewDragSelectionOverlay: NSViewRepresentable {
    let url: URL
    @Binding var selectedURLs: Set<URL>

    func makeNSView(context: Context) -> PreviewDragSelectionView {
        PreviewDragSelectionView(url: url, selectedURLs: $selectedURLs)
    }

    func updateNSView(_ nsView: PreviewDragSelectionView, context: Context) {
        nsView.url = url
        nsView.selectedURLs = $selectedURLs
    }
}

final class PreviewDragSelectionView: NSView, NSDraggingSource {
    var url: URL
    var selectedURLs: Binding<Set<URL>>
    private var mouseDownEvent: NSEvent?
    private var hasStartedDrag = false

    init(url: URL, selectedURLs: Binding<Set<URL>>) {
        self.url = url
        self.selectedURLs = selectedURLs
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        url = URL(fileURLWithPath: "/")
        selectedURLs = .constant([])
        super.init(coder: coder)
    }

    override func mouseDown(with event: NSEvent) {
        mouseDownEvent = event
        hasStartedDrag = false

        let key = url.standardizedFileURL
        if event.modifierFlags.contains(.command) {
            if selectedURLs.wrappedValue.contains(key) {
                selectedURLs.wrappedValue.remove(key)
            } else {
                selectedURLs.wrappedValue.insert(key)
            }
        } else if !selectedURLs.wrappedValue.contains(key) {
            selectedURLs.wrappedValue = [key]
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard !hasStartedDrag, let mouseDownEvent else { return }
        hasStartedDrag = true

        let key = url.standardizedFileURL
        let dragURLs: [URL]
        if selectedURLs.wrappedValue.contains(key) {
            dragURLs = selectedURLs.wrappedValue.sorted {
                $0.path < $1.path
            }
        } else {
            selectedURLs.wrappedValue = [key]
            dragURLs = [key]
        }

        let draggingItems = dragURLs.map { dragURL in
            let item = NSDraggingItem(pasteboardWriter: dragURL as NSURL)
            item.setDraggingFrame(
                NSRect(x: bounds.midX - 16, y: bounds.midY - 16, width: 32, height: 32),
                contents: FileIconCache.shared.icon(for: dragURL, cacheKey: nil, size: 32)
            )
            return item
        }
        beginDraggingSession(with: draggingItems, event: mouseDownEvent, source: self)
    }

    override func mouseUp(with event: NSEvent) {
        guard !hasStartedDrag, !event.modifierFlags.contains(.command) else { return }
        selectedURLs.wrappedValue = [url.standardizedFileURL]
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        context == .outsideApplication ? .copy : [.copy, .move]
    }
}
#endif
