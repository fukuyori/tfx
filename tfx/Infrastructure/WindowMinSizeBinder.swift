#if os(macOS)
import AppKit
import SwiftUI

/// Background view that imperatively binds `NSWindow.contentMinSize`
/// to a dynamic value driven by SwiftUI state.
///
/// Putting `.frame(minWidth: dynamicValue)` on the root view causes
/// SwiftUI to re-propagate the value to `contentMinSize` every layout
/// pass, which races with our own `applyWindowContentMinSize` calls
/// and (worse) creates a render-loop that pegs the CPU when SwiftUI
/// re-runs `body` while a resize is in progress.
///
/// This binder instead lives in the view tree as a side-effecting
/// `NSViewRepresentable`. SwiftUI invokes `updateNSView` whenever the
/// `minSize` input changes — exactly when the visibility flags it is
/// computed from change — and we set `contentMinSize` directly. Each
/// frame is set at most once per visibility-flag change; the value
/// is constant between flag changes, so SwiftUI does not see a moving
/// target and there is no render loop.
struct WindowMinSizeBinder: NSViewRepresentable {
    let minSize: NSSize

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            apply(to: view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            apply(to: nsView.window)
        }
    }

    private func apply(to window: NSWindow?) {
        guard let window else { return }
        window.contentMinSize = minSize
        // If the user previously shrunk the window below the new
        // minimum (e.g. preview was off and they pulled it small,
        // then turned preview on), grow it to fit. Origin is kept so
        // the window does not visually jump.
        var frame = window.frame
        let chromeWidth = window.frame.width - window.contentLayoutRect.width
        let chromeHeight = window.frame.height - window.contentLayoutRect.height
        let needed = NSSize(
            width: minSize.width + chromeWidth,
            height: minSize.height + chromeHeight
        )
        var didResize = false
        if frame.width < needed.width {
            frame.size.width = needed.width
            didResize = true
        }
        if frame.height < needed.height {
            frame.size.height = needed.height
            didResize = true
        }
        if didResize {
            window.setFrame(frame, display: true, animate: false)
        }
    }
}
#endif
