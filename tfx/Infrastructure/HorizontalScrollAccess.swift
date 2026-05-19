#if os(macOS)
import AppKit
import SwiftUI

/// Bridges a SwiftUI `ScrollView` to its underlying `NSScrollView` and
/// registers a horizontal scroll closure on the supplied `FileBrowserModel`.
///
/// The closure clamps to the document bounds, so calling it from the
/// keyboard handler simply nudges the view by the requested delta without
/// over-scrolling. Embed this view inside the scroll content (typically as
/// a `.background`) so `enclosingScrollView` resolves to the correct
/// `NSScrollView`.
struct HorizontalScrollAccess: NSViewRepresentable {
    let model: FileBrowserModel

    func makeNSView(context: Context) -> HorizontalScrollAccessView {
        HorizontalScrollAccessView(model: model)
    }

    func updateNSView(_ nsView: HorizontalScrollAccessView, context: Context) {
        nsView.model = model
        nsView.refreshHandler()
    }

    static func dismantleNSView(_ nsView: HorizontalScrollAccessView, coordinator: ()) {
        nsView.clearHandler()
    }
}

final class HorizontalScrollAccessView: NSView {
    weak var model: FileBrowserModel?

    init(model: FileBrowserModel) {
        self.model = model
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        refreshHandler()
    }

    func refreshHandler() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard let scrollView = self.enclosingScrollView else {
                self.model?.horizontalScrollHandler = nil
                return
            }
            self.model?.horizontalScrollHandler = { [weak scrollView] delta in
                guard let scrollView else { return }
                Self.scroll(scrollView, by: delta)
            }
        }
    }

    func clearHandler() {
        model?.horizontalScrollHandler = nil
    }

    private static func scroll(_ scrollView: NSScrollView, by delta: CGFloat) {
        guard let documentView = scrollView.documentView else { return }
        let visible = scrollView.documentVisibleRect
        let maxX = max(0, documentView.bounds.width - visible.width)
        let nextX = max(0, min(maxX, visible.origin.x + delta))
        let nextOrigin = NSPoint(x: nextX, y: visible.origin.y)
        scrollView.contentView.scroll(to: nextOrigin)
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }
}

#endif
