#if os(macOS)
import SwiftUI

struct PreviewPane: View {
    let urls: [URL]
    @State private var selectedPreviewURLs: Set<URL> = []
    @State private var visibleMultiPreviewURLs: Set<URL> = []
    @State private var activeMultiPreviewURLs: Set<URL> = []
    @AppStorage("Preview.showsRawSource") private var showsRawSource = false
    private let maxActiveMultiPreviews = 3
    @Environment(\.design) private var design
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            if anyURLSupportsRawSourceToggle {
                renderingModeToggle
            }
            content
        }
        .background(previewBackground)
    }

    @ViewBuilder
    private var content: some View {
        Group {
            if urls.count == 1, let url = urls.first {
                VStack(spacing: 0) {
                    preview(for: url)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    if !shouldHideFileInfo(for: url) {
                        PreviewFileInfoView(url: url)
                    }
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
                                if !shouldHideFileInfo(for: url) {
                                    PreviewFileInfoView(url: url)
                                }
                            }
                        }
                    }
                    .padding(10)
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(design.fonts.swiftUIFont(for: .title))
                    Text("No preview")
                }
                .font(design.fonts.swiftUIFont(for: .previewCode))
                .foregroundStyle(theme.secondaryForeground)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        if shouldShowRawSource(for: url) {
            RawTextPreview(url: url)
        } else {
            switch PreviewKindCache.shared.kind(for: url) {
            case .pdf:
                PDFPreview(url: url)
            case .video:
                VideoPreview(url: url)
            case .markdown:
                MarkdownPreview(url: url)
            case .csv:
                CSVPreview(url: url)
            case .json:
                JSONPreview(url: url)
            case .text:
                RawTextPreview(url: url)
            case .quickLook:
                QuickLookPreview(url: url)
            }
        }
    }

    private var renderingModeToggle: some View {
        HStack {
            Spacer()
            Button {
                showsRawSource.toggle()
            } label: {
                Image(systemName: "eye")
                    .font(design.fonts.swiftUIFont(for: .header, weight: .semibold))
                    .foregroundStyle(showsRawSource ? Color.secondary : Color.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background {
                        if !showsRawSource {
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color.accentColor)
                        }
                    }
            }
            .buttonStyle(.plain)
            .help(toggleHelpText)
            .accessibilityLabel(toggleHelpText)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(theme.headerBackground.opacity(design.opacity.background))
    }

    private var toggleHelpText: Text {
        // Describe what clicking the button will do, matching macOS toolbar
        // conventions.
        showsRawSource ? Text("Show rendered preview") : Text("Show source")
    }

    private var anyURLSupportsRawSourceToggle: Bool {
        urls.contains { Self.supportsRawSourceToggle($0) }
    }

    private var previewBackground: Color {
        theme.fileListBackground.opacity(design.opacity.background)
    }

    private func shouldShowRawSource(for url: URL) -> Bool {
        showsRawSource && Self.supportsRawSourceToggle(url)
    }

    /// Suppress the file-info strip when the rendered Markdown/HTML view is
    /// taking over the pane. The strip reappears in source mode so the user
    /// keeps file metadata visible while reading raw text.
    private func shouldHideFileInfo(for url: URL) -> Bool {
        !showsRawSource && Self.supportsRawSourceToggle(url)
    }

    /// True when the URL has a rendered form that is meaningfully different
    /// from its raw text. Markdown, HTML, CSV / TSV, and JSON all qualify.
    static func supportsRawSourceToggle(_ url: URL) -> Bool {
        switch PreviewKindCache.shared.kind(for: url) {
        case .markdown, .csv, .json:
            return true
        case .pdf, .video, .text, .quickLook:
            break
        }
        let ext = url.pathExtension.lowercased()
        return ext == "html" || ext == "htm"
    }
}

#endif
