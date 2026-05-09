#if os(macOS)
import AppKit
import SwiftUI

struct KeyboardEventHandler: NSViewRepresentable {
    let isEnabled: Bool
    let onKeyDown: (NSEvent) -> Bool

    func makeNSView(context: Context) -> KeyHandlingNSView {
        let view = KeyHandlingNSView()
        view.onKeyDown = onKeyDown
        view.isEnabled = isEnabled
        return view
    }

    func updateNSView(_ nsView: KeyHandlingNSView, context: Context) {
        nsView.onKeyDown = onKeyDown
        nsView.isEnabled = isEnabled

        if isEnabled {
            DispatchQueue.main.async {
                nsView.becomeKeyboardHandlerIfAppropriate()
            }
        }
    }
}

final class KeyHandlingNSView: NSView {
    var isEnabled = true
    var onKeyDown: ((NSEvent) -> Bool)?

    override var acceptsFirstResponder: Bool {
        true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        if isEnabled {
            DispatchQueue.main.async {
                self.becomeKeyboardHandlerIfAppropriate()
            }
        }
    }

    override func keyDown(with event: NSEvent) {
        if isEnabled, onKeyDown?(event) == true {
            return
        }

        super.keyDown(with: event)
    }

    func becomeKeyboardHandlerIfAppropriate() {
        guard isEnabled, let window else { return }

        if window.firstResponder is NSTextView {
            return
        }

        if window.firstResponder !== self {
            window.makeFirstResponder(self)
        }
    }
}
#endif
