#if os(macOS)
import SwiftUI
import WebKit

struct MarkdownPreview: NSViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let view = WKWebView()
        view.setValue(false, forKey: "drawsBackground")
        return view
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        guard context.coordinator.currentURL != url else { return }

        context.coordinator.cancellation?.cancel()
        let cancellation = PreviewLoadCancellation()
        context.coordinator.cancellation = cancellation
        context.coordinator.currentURL = url
        context.coordinator.generation += 1
        let generation = context.coordinator.generation
        let targetURL = url

        nsView.loadHTMLString(MarkdownHTMLRenderer.loadingHTML, baseURL: nil)

        DispatchQueue.global(qos: .userInitiated).async {
            guard !cancellation.isCancelled else { return }
            let markdown = (try? String(contentsOf: targetURL, encoding: .utf8))
                ?? String(decoding: ((try? Data(contentsOf: targetURL)) ?? Data()), as: UTF8.self)
            guard !cancellation.isCancelled else { return }
            guard let html = MarkdownHTMLRenderer.htmlDocument(for: markdown, cancellation: cancellation) else { return }

            DispatchQueue.main.async {
                guard context.coordinator.generation == generation, !cancellation.isCancelled else { return }
                nsView.loadHTMLString(html, baseURL: targetURL.deletingLastPathComponent())
            }
        }
    }

    static func dismantleNSView(_ nsView: WKWebView, coordinator: Coordinator) {
        coordinator.generation += 1
        coordinator.cancellation?.cancel()
        coordinator.cancellation = nil
        nsView.stopLoading()
        nsView.loadHTMLString(MarkdownHTMLRenderer.loadingHTML, baseURL: nil)
    }

    final class Coordinator {
        var currentURL: URL?
        var generation = 0
        var cancellation: PreviewLoadCancellation?
    }

}

#endif
