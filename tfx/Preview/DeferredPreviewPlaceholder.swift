#if os(macOS)
import SwiftUI

struct DeferredPreviewPlaceholder: View {
    let url: URL
    @Environment(\.design) private var design
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: iconName)
                .font(design.fonts.swiftUIFont(for: .title))
            Text("Preview queued")
                .font(design.fonts.swiftUIFont(for: .previewCode))
            Text(displayName)
                .font(design.fonts.swiftUIFont(for: .caption))
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(theme.secondaryForeground)
                .frame(maxWidth: .infinity)
        }
        .foregroundStyle(theme.secondaryForeground)
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var displayName: String {
        url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent
    }

    private var iconName: String {
        switch PreviewKindCache.shared.kind(for: url) {
        case .pdf:
            return "doc.richtext"
        case .video:
            return "film"
        case .markdown:
            return "doc.text"
        case .csv:
            return "tablecells"
        case .json:
            return "curlybraces"
        case .text:
            return "doc.plaintext"
        case .quickLook:
            return "doc"
        }
    }
}
#endif
