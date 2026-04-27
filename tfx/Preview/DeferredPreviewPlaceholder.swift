#if os(macOS)
import SwiftUI

struct DeferredPreviewPlaceholder: View {
    let url: URL

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: iconName)
                .font(.system(size: 24))
            Text("Preview queued")
                .font(.system(size: 12, design: .monospaced))
            Text(displayName)
                .font(.system(size: 11, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
        }
        .foregroundStyle(.secondary)
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
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
        case .quickLook:
            return "doc"
        }
    }
}
#endif
