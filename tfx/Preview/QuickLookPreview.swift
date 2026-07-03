#if os(macOS)
import QuickLookUI
import SwiftUI

struct QuickLookPreview: NSViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> QLPreviewView {
        // The initializer is failable (QuickLook service
        // unavailable / misbehaving). Fall back to an inert
        // plain-initialized view instead of crashing the app
        // over a preview.
        guard let view = QLPreviewView(frame: .zero, style: .normal) else {
            return QLPreviewView()
        }
        view.autostarts = true
        return view
    }

    func updateNSView(_ nsView: QLPreviewView, context: Context) {
        guard context.coordinator.currentURL != url else { return }
        context.coordinator.currentURL = url
        let previewURL = url
        Task { @MainActor in
            await Task.yield()
            guard context.coordinator.currentURL == previewURL else { return }
            nsView.previewItem = previewURL as NSURL
        }
    }

    static func dismantleNSView(_ nsView: QLPreviewView, coordinator: Coordinator) {
        coordinator.currentURL = nil
        Task { @MainActor in
            await Task.yield()
            nsView.previewItem = nil
        }
    }

    final class Coordinator {
        var currentURL: URL?
    }
}

#endif
