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
    }

    /// Handles the titlebar double-click-to-zoom gesture. Window
    /// `contentMinSize` and the per-configuration resize logic live
    /// in `MainPaneSplitView.Coordinator` — they're not a window
    /// delegate concern, they're a function of the layout state.
    final class Coordinator: NSObject {
        private weak var window: NSWindow?
        private weak var installedTitlebarView: NSView?
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
