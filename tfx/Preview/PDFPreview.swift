#if os(macOS)
import PDFKit
import SwiftUI

struct PDFPreview: NSViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        return view
    }

    func updateNSView(_ nsView: PDFView, context: Context) {
        guard context.coordinator.currentURL != url else { return }

        context.coordinator.cancellation?.cancel()
        let cancellation = PreviewLoadCancellation()
        context.coordinator.cancellation = cancellation
        context.coordinator.currentURL = url
        context.coordinator.generation += 1
        let generation = context.coordinator.generation
        let targetURL = url
        nsView.document = nil

        DispatchQueue.global(qos: .userInitiated).async {
            guard !cancellation.isCancelled else { return }
            let document = PDFDocument(url: targetURL)
            guard !cancellation.isCancelled else { return }

            DispatchQueue.main.async {
                guard context.coordinator.generation == generation, !cancellation.isCancelled else { return }
                nsView.document = document
            }
        }
    }

    static func dismantleNSView(_ nsView: PDFView, coordinator: Coordinator) {
        coordinator.generation += 1
        coordinator.cancellation?.cancel()
        coordinator.cancellation = nil
        nsView.document = nil
    }

    final class Coordinator {
        var currentURL: URL?
        var generation = 0
        var cancellation: PreviewLoadCancellation?
    }
}

#endif
