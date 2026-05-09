#if os(macOS)
import SwiftUI

struct PreviewPane: View {
    let urls: [URL]
    @State private var selectedPreviewURLs: Set<URL> = []
    @State private var visibleMultiPreviewURLs: Set<URL> = []
    @State private var activeMultiPreviewURLs: Set<URL> = []
    private let maxActiveMultiPreviews = 3

    var body: some View {
        Group {
            if urls.count == 1, let url = urls.first {
                VStack(spacing: 0) {
                    preview(for: url)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    PreviewFileInfoView(url: url)
                }
            } else if !urls.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(urls, id: \.self) { url in
                            MultiPreviewItem(
                                url: url,
                                isSelected: selectedPreviewURLs.contains(url.standardizedFileURL),
                                isPreviewActive: activeMultiPreviewURLs.contains(url.standardizedFileURL),
                                selectedURLs: $selectedPreviewURLs,
                                requestPreview: {
                                    requestMultiPreview(for: url)
                                },
                                releasePreview: {
                                    releaseMultiPreview(for: url)
                                }
                            ) {
                                preview(for: url)
                            } info: {
                                PreviewFileInfoView(url: url)
                            }
                        }
                    }
                    .padding(10)
                }
                .background(Color(nsColor: .textBackgroundColor))
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 28))
                    Text("No preview")
                }
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .textBackgroundColor))
            }
        }
        .onChange(of: urls) {
            let availableURLs = Set(urls.map(\.standardizedFileURL))
            selectedPreviewURLs = selectedPreviewURLs.intersection(availableURLs)
            visibleMultiPreviewURLs = visibleMultiPreviewURLs.intersection(availableURLs)
            updateActiveMultiPreviews()
        }
    }

    private func requestMultiPreview(for url: URL) {
        visibleMultiPreviewURLs.insert(url.standardizedFileURL)
        updateActiveMultiPreviews()
    }

    private func releaseMultiPreview(for url: URL) {
        visibleMultiPreviewURLs.remove(url.standardizedFileURL)
        updateActiveMultiPreviews()
    }

    private func updateActiveMultiPreviews() {
        activeMultiPreviewURLs = Set(
            urls
                .map(\.standardizedFileURL)
                .filter { visibleMultiPreviewURLs.contains($0) }
                .prefix(maxActiveMultiPreviews)
        )
    }

    @ViewBuilder
    private func preview(for url: URL) -> some View {
        switch PreviewKindCache.shared.kind(for: url) {
        case .pdf:
            PDFPreview(url: url)
        case .video:
            VideoPreview(url: url)
        case .markdown:
            MarkdownPreview(url: url)
        case .quickLook:
            QuickLookPreview(url: url)
        }
    }
}

#endif
