#if os(macOS)
import AppKit
import Foundation
import SwiftUI

enum PerformanceTrace {
    nonisolated static func now() -> UInt64 {
        DispatchTime.now().uptimeNanoseconds
    }

    nonisolated static func log(_ label: String, startedAt start: UInt64, detail: String = "") {
        guard ProcessInfo.processInfo.environment["TFX_PERFORMANCE_LOGS"] == "1" else { return }

        let elapsedMilliseconds = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
        let suffix = detail.isEmpty ? "" : " \(detail)"
        print(String(format: "[tfx perf] %@ %.1fms%@", label, elapsedMilliseconds, suffix))
    }
}

struct WindowFrameAutosaver: NSViewRepresentable {
    let name: String

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            view.window?.setFrameAutosaveName(name)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            nsView.window?.setFrameAutosaveName(name)
        }
    }
}

extension View {
    func quickHelp(_ message: String, text: Binding<String>) -> some View {
        onHover { isHovering in
            text.wrappedValue = isHovering ? message : ""
        }
        .accessibilityHint(message)
    }
}
#endif
