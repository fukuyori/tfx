#if os(macOS)
import SwiftUI
import WebKit

struct MarkdownPreview: NSViewRepresentable {
    let url: URL
    let allowsExternalImages: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        // Hardened configuration for previewing untrusted markdown:
        // 1. JavaScript is disabled so a `javascript:` URL or injected
        //    `<script>` in user content can't run.
        // 2. The base URL is nil at load time (see `updateNSView`) so
        //    relative `file://` references can't read arbitrary local
        //    files. Both together turn the WKWebView into a strictly
        //    layout/styling renderer.
        // 3. A `WKNavigationDelegate` is attached to refuse navigations
        //    to anything other than `http`, `https`, and `mailto` —
        //    defense-in-depth in case a link still slips through, and
        //    so any external link is opened with `NSWorkspace` rather
        //    than letting the WebView race the OS for handling.
        let configuration = WKWebViewConfiguration()
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = false
        configuration.defaultWebpagePreferences = preferences

        let view = WKWebView(frame: .zero, configuration: configuration)
        view.setValue(false, forKey: "drawsBackground")
        view.navigationDelegate = context.coordinator
        return view
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        guard context.coordinator.currentURL != url ||
              context.coordinator.allowsExternalImages != allowsExternalImages else { return }

        context.coordinator.cancellation?.cancel()
        let cancellation = PreviewLoadCancellation()
        context.coordinator.cancellation = cancellation
        context.coordinator.currentURL = url
        context.coordinator.allowsExternalImages = allowsExternalImages
        context.coordinator.generation += 1
        let generation = context.coordinator.generation
        let targetURL = url
        let allowsExternalImages = allowsExternalImages

        nsView.loadHTMLString(MarkdownHTMLRenderer.loadingHTML, baseURL: nil)

        DispatchQueue.global(qos: .userInitiated).async {
            guard !cancellation.isCancelled else { return }
            // Route through the shared size-capped loader like
            // every other text preview: an unbounded read of a
            // multi-GB file (plus the HTML expansion on top)
            // could exhaust the process just by selecting it.
            let markdown: String
            switch PreviewTextLoader.load(at: targetURL) {
            case let .success(text):
                markdown = text
            case let .tooLarge(actualBytes):
                markdown = PreviewTextLoader.tooLargeMessage(actualBytes: actualBytes)
            }
            guard !cancellation.isCancelled else { return }
            guard let html = MarkdownHTMLRenderer.htmlDocument(
                for: markdown,
                allowsExternalImages: allowsExternalImages,
                baseDirectory: targetURL.deletingLastPathComponent(),
                cancellation: cancellation
            ) else { return }

            DispatchQueue.main.async {
                guard context.coordinator.generation == generation, !cancellation.isCancelled else { return }
                // baseURL nil: relative paths inside the rendered HTML
                // (intentional or attacker-injected) cannot resolve to
                // a `file://` URL and read arbitrary local files.
                nsView.loadHTMLString(html, baseURL: nil)
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

    final class Coordinator: NSObject, WKNavigationDelegate {
        var currentURL: URL?
        var allowsExternalImages = false
        var generation = 0
        var cancellation: PreviewLoadCancellation?

        /// Allow the initial `loadHTMLString` and the rendered document,
        /// but route any link click to `NSWorkspace` only when the link
        /// uses one of the safe schemes. Anything else is cancelled.
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            switch navigationAction.navigationType {
            case .linkActivated:
                if let url = navigationAction.request.url, isSafeLinkScheme(url) {
                    NSWorkspace.shared.open(url)
                }
                decisionHandler(.cancel)
            case .other:
                // Initial document loads from `loadHTMLString` arrive
                // with `.other`. Allow them so the rendered HTML can
                // show up at all.
                decisionHandler(.allow)
            default:
                decisionHandler(.cancel)
            }
        }

        private func isSafeLinkScheme(_ url: URL) -> Bool {
            switch url.scheme?.lowercased() {
            case "http", "https", "mailto": return true
            default: return false
            }
        }
    }

}

#endif
