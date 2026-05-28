#if os(macOS)
import AppKit
import SwiftUI

/// Shared factory for the read-only monospaced `NSTextView` used by the
/// raw-text and pretty-printed-JSON previews.
enum MonospacedTextPreviewView {
    static func makeScrollView(
        fonts: DesignFontTokens = .default,
        textColor: NSColor = .textColor
    ) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = false
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear

        if let textView = scrollView.documentView as? NSTextView {
            textView.isEditable = false
            textView.isSelectable = true
            textView.isRichText = false
            textView.drawsBackground = false
            textView.backgroundColor = .clear
            textView.textColor = textColor
            textView.font = fonts.nsFont(for: .previewCode)
            textView.textContainerInset = NSSize(width: 8, height: 8)
            textView.isAutomaticQuoteSubstitutionEnabled = false
            textView.isAutomaticDashSubstitutionEnabled = false
            textView.isAutomaticTextReplacementEnabled = false
            textView.isAutomaticSpellingCorrectionEnabled = false
            textView.isAutomaticLinkDetectionEnabled = false
            textView.isContinuousSpellCheckingEnabled = false
            textView.textContainer?.widthTracksTextView = true
        }
        return scrollView
    }
}

/// Read-only plain-text preview backed by an `NSTextView`.
///
/// Used as the "source" view for Markdown, HTML, CSV, and JSON files when the
/// preview pane's rendering toggle is off. The file contents are loaded off
/// the main thread and assigned to the text view on the main queue once
/// decoded.
struct RawTextPreview: NSViewRepresentable {
    let url: URL
    @Environment(\.design) private var design
    @Environment(\.theme) private var theme

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSScrollView {
        MonospacedTextPreviewView.makeScrollView(
            fonts: design.fonts,
            textColor: NSColor(theme.fileForeground)
        )
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        nsView.drawsBackground = false
        nsView.backgroundColor = .clear

        if let textView = nsView.documentView as? NSTextView {
            textView.font = design.fonts.nsFont(for: .previewCode)
            textView.drawsBackground = false
            textView.backgroundColor = .clear
            textView.textColor = NSColor(theme.fileForeground)
        }

        guard context.coordinator.currentURL != url else { return }

        context.coordinator.cancellation?.cancel()
        let cancellation = PreviewLoadCancellation()
        context.coordinator.cancellation = cancellation
        context.coordinator.currentURL = url
        context.coordinator.generation += 1
        let generation = context.coordinator.generation
        let targetURL = url

        guard let textView = nsView.documentView as? NSTextView else { return }
        textView.string = ""

        DispatchQueue.global(qos: .userInitiated).async {
            guard !cancellation.isCancelled else { return }
            let outcome = PreviewTextLoader.load(at: targetURL)
            guard !cancellation.isCancelled else { return }
            let text: String
            switch outcome {
            case let .success(loaded):
                text = loaded
            case let .tooLarge(actualBytes):
                text = PreviewTextLoader.tooLargeMessage(actualBytes: actualBytes)
            }

            DispatchQueue.main.async {
                guard
                    context.coordinator.generation == generation,
                    !cancellation.isCancelled
                else {
                    return
                }
                textView.string = text
                textView.scroll(.zero)
            }
        }
    }

    static func dismantleNSView(_ nsView: NSScrollView, coordinator: Coordinator) {
        coordinator.generation += 1
        coordinator.cancellation?.cancel()
        coordinator.cancellation = nil
    }

    final class Coordinator {
        var currentURL: URL?
        var generation = 0
        var cancellation: PreviewLoadCancellation?
    }
}

#endif
