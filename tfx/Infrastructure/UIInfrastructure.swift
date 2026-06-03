#if os(macOS)
import AppKit
import Foundation
import SwiftUI

enum PerformanceTrace {
    /// `UserDefaults` key the Developer menu and `@AppStorage` bindings share.
    /// `TFX_PERFORMANCE_LOGS=1` in the environment is honored independently —
    /// it takes precedence for CI / scripted runs so the in-app toggle does
    /// not have to be flipped first.
    static let userDefaultsKey = "Developer.showsPerformanceLogs"

    nonisolated static func now() -> UInt64 {
        DispatchTime.now().uptimeNanoseconds
    }

    nonisolated static func isEnabled() -> Bool {
        if ProcessInfo.processInfo.environment["TFX_PERFORMANCE_LOGS"] == "1" {
            return true
        }
        return UserDefaults.standard.bool(forKey: userDefaultsKey)
    }

    nonisolated static func log(_ label: String, startedAt start: UInt64, detail: String = "") {
        guard isEnabled() else { return }

        let elapsedMilliseconds = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
        let suffix = detail.isEmpty ? "" : " \(detail)"
        print(String(format: "[tfx perf] %@ %.1fms%@", label, elapsedMilliseconds, suffix))
    }
}

struct WindowFrameAutosaver: NSViewRepresentable {
    let name: String
    var allowsTransparency = false

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            view.window?.setFrameAutosaveName(name)
            configureWindow(view.window, coordinator: context.coordinator)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            nsView.window?.setFrameAutosaveName(name)
            configureWindow(nsView.window, coordinator: context.coordinator)
        }
    }

    private func configureWindow(_ window: NSWindow?, coordinator: Coordinator) {
        guard let window else { return }

        window.isOpaque = !allowsTransparency
        window.backgroundColor = allowsTransparency ? .clear : .windowBackgroundColor
        coordinator.installTitlebarDoubleClick(on: window)
        coordinator.installMinSizeEnforcement(on: window)
    }

    final class Coordinator: NSObject, NSWindowDelegate {
        private weak var window: NSWindow?
        private weak var installedTitlebarView: NSView?
        private weak var previousDelegate: NSWindowDelegate?
        private lazy var doubleClickRecognizer: NSClickGestureRecognizer = {
            let recognizer = NSClickGestureRecognizer(
                target: self,
                action: #selector(handleTitlebarDoubleClick(_:))
            )
            recognizer.numberOfClicksRequired = 2
            return recognizer
        }()

        func installTitlebarDoubleClick(on window: NSWindow) {
            self.window = window
            guard let titlebarView = window.standardWindowButton(.closeButton)?.superview else {
                return
            }
            guard installedTitlebarView !== titlebarView else {
                return
            }

            if let installedTitlebarView {
                installedTitlebarView.removeGestureRecognizer(doubleClickRecognizer)
            }
            titlebarView.addGestureRecognizer(doubleClickRecognizer)
            installedTitlebarView = titlebarView
        }

        @objc private func handleTitlebarDoubleClick(_ recognizer: NSClickGestureRecognizer) {
            guard recognizer.state == .ended else { return }
            window?.zoom(nil)
        }

        /// Install ourselves as the window's delegate so that
        /// `windowWillResize(_:to:)` can clamp the proposed size to the
        /// dynamic per-configuration minimum. SwiftUI also installs a
        /// delegate, so we forward every other delegate method back to
        /// it via `responds(to:)` / `forwardingTarget(for:)`.
        func installMinSizeEnforcement(on window: NSWindow) {
            if window.delegate === self { return }
            previousDelegate = window.delegate
            window.delegate = self
        }

        // MARK: NSWindowDelegate (forwarding + min-size clamp)

        func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
            let minSize = currentRequiredContentMinSize(for: sender)
            // `frameSize` is in window-frame coordinates (includes
            // titlebar etc.); convert min content size to frame size
            // by adding the chrome delta computed from the current
            // frame minus the current content rect.
            let chromeWidth = sender.frame.width - sender.contentLayoutRect.width
            let chromeHeight = sender.frame.height - sender.contentLayoutRect.height
            let clamped = NSSize(
                width: max(frameSize.width, minSize.width + chromeWidth),
                height: max(frameSize.height, minSize.height + chromeHeight)
            )

            if let previous = previousDelegate,
               previous.responds(to: #selector(NSWindowDelegate.windowWillResize(_:to:))) {
                return previous.windowWillResize?(sender, to: clamped) ?? clamped
            }
            return clamped
        }

        /// Compute the live minimum content size by reading the
        /// visibility flags straight from `UserDefaults`. Avoids any
        /// coupling to SwiftUI state so the delegate can be invoked
        /// during a resize without triggering a render pass.
        private func currentRequiredContentMinSize(for window: NSWindow) -> NSSize {
            let defaults = UserDefaults.standard
            let snapshots: [PaneSnapshot] = LayoutPane.allCases.compactMap { pane in
                let isVisible = defaults.object(forKey: pane.visibilityStorageKey) as? Bool ?? pane.defaultVisibility
                guard isVisible else { return nil }
                let storedRaw = defaults.object(forKey: pane.widthStorageKey) as? Double ?? pane.defaultWidth
                let displayed = max(pane.minimumWidth, CGFloat(storedRaw))
                return PaneSnapshot(pane: pane, width: displayed)
            }
            let isSplit = defaults.object(forKey: "TerminalFileManager.isSplitViewVisible") as? Bool ?? false
            let width = TerminalFileManagerLayout.minimumWindowWidth(
                visiblePanes: snapshots,
                isSplitViewVisible: isSplit
            )
            return NSSize(width: width, height: TerminalFileManagerLayout.minimumWindowHeight)
        }

        // Forward any other delegate calls to SwiftUI's original delegate
        // so window restoration, key-window handling, etc., keep working.
        override func responds(to aSelector: Selector!) -> Bool {
            if super.responds(to: aSelector) { return true }
            return previousDelegate?.responds(to: aSelector) ?? false
        }

        override func forwardingTarget(for aSelector: Selector!) -> Any? {
            if let previous = previousDelegate, previous.responds(to: aSelector) {
                return previous
            }
            return super.forwardingTarget(for: aSelector)
        }
    }
}

extension View {
    func quickHelp(_ message: LocalizedStringResource, text: Binding<String>) -> some View {
        let resolved = String(localized: message)
        return modifier(QuickHelpBubbleModifier(message: resolved))
    }

    /// Hover-help variant that appends the keyboard shortcut display string
    /// after the label, separated by two spaces (matching macOS menu items).
    func quickHelp(
        _ message: LocalizedStringResource,
        shortcut: ShortcutInfo,
        text: Binding<String>
    ) -> some View {
        let resolved = String(localized: message)
        let combined = "\(resolved)  \(shortcut.displayString)"
        return modifier(QuickHelpBubbleModifier(message: combined))
    }

    func quickHelp(_ message: LocalizedStringResource) -> some View {
        modifier(QuickHelpBubbleModifier(message: String(localized: message)))
    }

    /// Apply a `ShortcutInfo` as a `.keyboardShortcut` binding.
    func keyboardShortcut(_ info: ShortcutInfo) -> some View {
        keyboardShortcut(info.key, modifiers: info.modifiers)
    }

    /// Show `cursor` while the pointer is over this view.
    ///
    /// Uses `NSCursor.push` / `.pop` driven by `onHover`. The hit region is
    /// whatever SwiftUI is currently using for events on this view, including
    /// any `contentShape` overrides — so for thin resize bars, expand the
    /// hit area with `contentShape(Rectangle().inset(by:))` first.
    func cursor(_ cursor: NSCursor) -> some View {
        onHover { isHovering in
            if isHovering {
                cursor.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

private struct QuickHelpBubbleModifier: ViewModifier {
    let message: String

    func body(content: Content) -> some View {
        content
            .help(Text(message))
            .accessibilityHint(Text(message))
    }
}
#endif
