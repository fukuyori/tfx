#if os(macOS)
import AppKit
import Foundation
import SwiftUI

/// Rendered JSON preview.
///
/// Loads the file off the main thread, parses it with `JSONSerialization`,
/// and pretty-prints it (sorted keys, no escaped slashes) into the same
/// monospaced `NSTextView` used by `RawTextPreview`. When parsing fails the
/// raw file contents are shown so the user can still inspect the file.
struct JSONPreview: NSViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSScrollView {
        MonospacedTextPreviewView.makeScrollView()
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
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
            let data = (try? Data(contentsOf: targetURL)) ?? Data()
            let displayed = Self.prettyPrint(data: data)
            guard !cancellation.isCancelled else { return }

            DispatchQueue.main.async {
                guard
                    context.coordinator.generation == generation,
                    !cancellation.isCancelled
                else {
                    return
                }
                textView.string = displayed
                textView.scroll(.zero)
            }
        }
    }

    static func dismantleNSView(_ nsView: NSScrollView, coordinator: Coordinator) {
        coordinator.generation += 1
        coordinator.cancellation?.cancel()
        coordinator.cancellation = nil
    }

    private static func prettyPrint(data: Data) -> String {
        guard
            let object = try? JSONSerialization.jsonObject(with: data, options: [.allowFragments]),
            let prettyData = try? JSONSerialization.data(
                withJSONObject: object,
                options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            ),
            let prettyString = String(data: prettyData, encoding: .utf8)
        else {
            // Parse failed — fall back to the raw bytes so the user can still
            // inspect the file rather than seeing an empty pane.
            return String(data: data, encoding: .utf8) ?? ""
        }
        return prettyString
    }

    final class Coordinator {
        var currentURL: URL?
        var generation = 0
        var cancellation: PreviewLoadCancellation?
    }
}

#endif
