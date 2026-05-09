#if os(macOS)
import AppKit
import SwiftUI

struct MultiPreviewItem<Content: View, Info: View>: View {
    let url: URL
    let isSelected: Bool
    let isPreviewActive: Bool
    @Binding var selectedURLs: Set<URL>
    let requestPreview: () -> Void
    let releasePreview: () -> Void
    @ViewBuilder let content: () -> Content
    @ViewBuilder let info: () -> Info

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                FileIcon(url: url)
                Text(displayName)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(.system(size: 12, design: .monospaced))
            .foregroundStyle(.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor))

            Group {
                if isPreviewActive {
                    content()
                } else {
                    DeferredPreviewPlaceholder(url: url)
                }
            }
            .frame(height: 220)
            .clipped()

            info()
        }
        .background(Color(nsColor: .textBackgroundColor))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isSelected ? Color.green : Color(nsColor: .separatorColor), lineWidth: isSelected ? 2 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(
            PreviewDragSelectionOverlay(url: url, selectedURLs: $selectedURLs)
        )
        .onAppear(perform: requestPreview)
        .onDisappear(perform: releasePreview)
    }

    private var displayName: String {
        url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent
    }
}

#endif
