#if os(macOS)
import SwiftUI

struct PreviewPane: View {
    enum PreviewDisplay: Equatable {
        case noPreview
        case rawSource
        case rendered
    }

    let urls: [URL]
    @State private var selectedPreviewURLs: Set<URL> = []
    @State private var visibleMultiPreviewURLs: Set<URL> = []
    @State private var activeMultiPreviewURLs: Set<URL> = []
    @State private var isPrimaryPreviewReady = false
    @State private var allowsExternalImages = false
    /// Standardized URLs of the markdown files that actually reference a
    /// remote (`http`/`https`) image. Populated asynchronously by
    /// `detectExternalImages`; the "load external images" button only
    /// appears for files in this set.
    @State private var markdownURLsWithExternalImages: Set<URL> = []
    @AppStorage("Preview.showsRawSource") private var showsRawSource = false
    private let maxActiveMultiPreviews = 3
    private let primaryPreviewDelayNanoseconds: UInt64 = 120_000_000
    @Environment(\.design) private var design
    @Environment(\.theme) private var theme
    @EnvironmentObject private var previewConfigurationStore: PreviewConfigurationStore
    @EnvironmentObject private var shortcutStore: ShortcutStore
    @State private var hoverHelpText: String = ""

    var body: some View {
        VStack(spacing: 0) {
            if shouldShowPreviewControls {
                previewControls
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
                    primaryPreview(for: url)
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
            isPrimaryPreviewReady = false
            allowsExternalImages = false
            let availableURLs = Set(urls.map(\.standardizedFileURL))
            selectedPreviewURLs = selectedPreviewURLs.intersection(availableURLs)
            visibleMultiPreviewURLs = visibleMultiPreviewURLs.intersection(availableURLs)
            updateActiveMultiPreviews()
        }
        .onChange(of: showsRawSource) {
            isPrimaryPreviewReady = false
            allowsExternalImages = false
        }
        .onChange(of: previewConfigurationStore.configuration) {
            isPrimaryPreviewReady = false
            allowsExternalImages = false
        }
        .task(id: externalImageDetectionKey) {
            await detectExternalImages()
        }
    }

    /// Markdown files in the current selection, in display order.
    private var markdownURLs: [URL] {
        urls.filter { PreviewKindCache.shared.kind(for: $0) == .markdown }
    }

    /// Re-run external-image detection whenever the set of markdown
    /// files being previewed changes.
    private var externalImageDetectionKey: String {
        markdownURLs.map { $0.standardizedFileURL.path }.joined(separator: "\n")
    }

    /// Read each previewed markdown file off the main thread and record
    /// which ones reference a remote image, so `shouldShowExternalImageButton`
    /// can hide the button for documents that have nothing to load.
    private func detectExternalImages() async {
        let targets = markdownURLs
        guard !targets.isEmpty else {
            markdownURLsWithExternalImages = []
            return
        }
        var found: Set<URL> = []
        for url in targets {
            let hasExternalImage = await Task.detached(priority: .utility) { () -> Bool in
                let markdown: String
                if let utf8 = try? String(contentsOf: url, encoding: .utf8) {
                    markdown = utf8
                } else {
                    markdown = String(decoding: (try? Data(contentsOf: url)) ?? Data(), as: UTF8.self)
                }
                return MarkdownInlineHTML.containsExternalImageReference(in: markdown)
            }.value
            if Task.isCancelled { return }
            if hasExternalImage {
                found.insert(url.standardizedFileURL)
            }
        }
        if Task.isCancelled { return }
        markdownURLsWithExternalImages = found
    }

    @ViewBuilder
    private func primaryPreview(for url: URL) -> some View {
        if isPrimaryPreviewReady {
            preview(for: url)
        } else {
            DeferredPreviewPlaceholder(url: url)
                .task(id: primaryPreviewTaskID(for: url)) {
                    try? await Task.sleep(nanoseconds: primaryPreviewDelayNanoseconds)
                    guard !Task.isCancelled else { return }
                    isPrimaryPreviewReady = true
                }
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
        let mode = previewMode(for: url)
        let display = Self.previewDisplay(
            mode: mode,
            showsRawSource: showsRawSource,
            supportsRawSourceToggle: Self.supportsRawSourceToggle(url, mode: mode)
        )

        switch display {
        case .noPreview:
            noPreviewView
        case .rawSource:
            RawTextPreview(url: url)
        case .rendered:
            renderedPreview(for: url)
        }
    }

    @ViewBuilder
    private func renderedPreview(for url: URL) -> some View {
        switch PreviewKindCache.shared.kind(for: url) {
        case .pdf:
            PDFPreview(url: url)
        case .video:
            VideoPreview(url: url)
        case .markdown:
            MarkdownPreview(url: url, allowsExternalImages: shouldAllowExternalImages(for: url))
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

    private var noPreviewView: some View {
        VStack(spacing: 8) {
            Image(systemName: "eye.slash")
                .font(design.fonts.swiftUIFont(for: .title))
            Text("No preview")
        }
        .font(design.fonts.swiftUIFont(for: .previewCode))
        .foregroundStyle(theme.secondaryForeground)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var previewControls: some View {
        HStack {
            Spacer()

            if shouldShowExternalImageButton {
                externalImageButton
            }

            if anyURLSupportsRawSourceToggle {
                renderingModeToggle
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(theme.headerBackground.opacity(design.opacity.background))
    }

    private var renderingModeToggle: some View {
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
        .keyboardShortcut(shortcutStore.info(.toggleRendered))
        .quickHelp(
            toggleHelpTextResource,
            shortcut: shortcutStore.info(.toggleRendered),
            text: $hoverHelpText
        )
        .accessibilityLabel(toggleHelpText)
    }

    private var externalImageButton: some View {
        Button {
            allowsExternalImages = true
        } label: {
            Image(systemName: "photo")
                .font(design.fonts.swiftUIFont(for: .header, weight: .semibold))
                .foregroundStyle(Color.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.accentColor)
                }
        }
        .buttonStyle(.plain)
        .keyboardShortcut(shortcutStore.info(.loadExternalImages))
        .quickHelp(
            "Load external images",
            shortcut: shortcutStore.info(.loadExternalImages),
            text: $hoverHelpText
        )
        .accessibilityLabel(Text("Load external images"))
        .padding(.trailing, 8)
    }

    private var shouldShowExternalImageButton: Bool {
        guard previewConfigurationStore.configuration.markdownExternalImages == .button else { return false }
        guard !allowsExternalImages else { return false }
        return urls.contains { url in
            !shouldShowRawSource(for: url) &&
                !isForcedTextOrNoPreview(for: url) &&
                PreviewKindCache.shared.kind(for: url) == .markdown &&
                markdownURLsWithExternalImages.contains(url.standardizedFileURL)
        }
    }

    private var shouldShowPreviewControls: Bool {
        anyURLSupportsRawSourceToggle || shouldShowExternalImageButton
    }

    private var toggleHelpText: Text {
        // Describe what clicking the button will do, matching macOS toolbar
        // conventions.
        showsRawSource ? Text("Show rendered preview") : Text("Show source")
    }

    private var toggleHelpTextResource: LocalizedStringResource {
        showsRawSource ? "Show rendered preview" : "Show source"
    }

    private var anyURLSupportsRawSourceToggle: Bool {
        urls.contains { url in
            Self.supportsRawSourceToggle(url, mode: previewMode(for: url))
        }
    }

    private var previewBackground: Color {
        theme.fileListBackground.opacity(design.opacity.background)
    }

    private func primaryPreviewTaskID(for url: URL) -> String {
        let configuration = previewConfigurationStore.configuration
        return "\(url.standardizedFileURL.path)|\(showsRawSource)|\(allowsExternalImages)|\(configuration.mode(for: url).rawValue)|\(configuration.markdownExternalImages.rawValue)"
    }

    private func shouldShowRawSource(for url: URL) -> Bool {
        showsRawSource &&
            Self.supportsRawSourceToggle(url, mode: previewMode(for: url))
    }

    /// Suppress the file-info strip when the rendered Markdown/HTML view is
    /// taking over the pane. The strip reappears in source mode so the user
    /// keeps file metadata visible while reading raw text.
    private func shouldHideFileInfo(for url: URL) -> Bool {
        guard !isForcedTextOrNoPreview(for: url) else { return false }
        return !shouldShowRawSource(for: url) && Self.supportsRawSourceToggle(url)
    }

    private func previewMode(for url: URL) -> PreviewConfiguration.Mode {
        previewConfigurationStore.configuration.mode(for: url)
    }

    private func isForcedTextOrNoPreview(for url: URL) -> Bool {
        switch previewMode(for: url) {
        case .text, .none:
            return true
        case .auto, .rendered:
            return false
        }
    }

    private func shouldAllowExternalImages(for url: URL) -> Bool {
        guard PreviewKindCache.shared.kind(for: url) == .markdown else { return false }
        switch previewConfigurationStore.configuration.markdownExternalImages {
        case .always:
            return true
        case .button:
            return allowsExternalImages
        case .never:
            return false
        }
    }

    static func previewDisplay(
        mode: PreviewConfiguration.Mode,
        showsRawSource: Bool,
        supportsRawSourceToggle: Bool
    ) -> PreviewDisplay {
        switch mode {
        case .text:
            return .rawSource
        case .auto, .rendered:
            return showsRawSource && supportsRawSourceToggle ? .rawSource : .rendered
        case .none:
            return .noPreview
        }
    }

    /// True when the URL has a rendered form that is meaningfully different
    /// from its raw text. Markdown, HTML, CSV / TSV, and JSON all qualify.
    static func supportsRawSourceToggle(_ url: URL) -> Bool {
        supportsRawSourceToggle(url, mode: .auto)
    }

    static func supportsRawSourceToggle(_ url: URL, mode: PreviewConfiguration.Mode) -> Bool {
        switch mode {
        case .auto, .rendered:
            break
        case .text, .none:
            return false
        }

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
