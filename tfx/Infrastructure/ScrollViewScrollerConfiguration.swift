#if os(macOS)
import AppKit
import SwiftUI

struct ScrollViewScrollerConfiguration: NSViewRepresentable {
    let axes: Axis.Set
    let autohidesScrollers: Bool

    func makeNSView(context: Context) -> ScrollerConfigurationView {
        ScrollerConfigurationView(axes: axes, autohidesScrollers: autohidesScrollers)
    }

    func updateNSView(_ nsView: ScrollerConfigurationView, context: Context) {
        nsView.axes = axes
        nsView.autohidesScrollers = autohidesScrollers
        nsView.configureEnclosingScrollView()
    }
}

final class ScrollerConfigurationView: NSView {
    var axes: Axis.Set
    var autohidesScrollers: Bool

    init(axes: Axis.Set, autohidesScrollers: Bool) {
        self.axes = axes
        self.autohidesScrollers = autohidesScrollers
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        axes = []
        autohidesScrollers = true
        super.init(coder: coder)
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        configureEnclosingScrollView()
    }

    func configureEnclosingScrollView() {
        DispatchQueue.main.async { [weak self] in
            guard let self, let scrollView = self.enclosingScrollView else { return }
            if self.axes.contains(.horizontal) {
                scrollView.hasHorizontalScroller = true
            }
            if self.axes.contains(.vertical) {
                scrollView.hasVerticalScroller = true
            }
            scrollView.autohidesScrollers = self.autohidesScrollers
        }
    }
}
#endif
