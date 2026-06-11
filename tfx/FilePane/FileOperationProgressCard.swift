#if os(macOS)
import SwiftUI

/// In-pane card surfacing a running file operation. Shows the
/// operation's OS-localized description, a determinate progress
/// bar driven by `Progress.fractionCompleted`, the file name
/// currently being copied, and a Cancel button wired to
/// `Progress.cancel()` so the underlying chunk-copy loop can
/// stop between chunks and remove the partial destination file.
struct FileOperationProgressCard: View {
    @ObservedObject var operation: FileOperationProgressViewModel
    @Environment(\.design) private var design
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(operation.kind.title)
                        .font(design.fonts.swiftUIFont(for: .statusLine, weight: .semibold))
                    if !operation.currentFileName.isEmpty {
                        Text(operation.currentFileName)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundStyle(theme.secondaryForeground)
                    }
                }
                ProgressView(value: max(0, min(1, operation.fractionCompleted)))
                    .progressViewStyle(.linear)
                if !operation.localizedDescription.isEmpty {
                    Text(operation.localizedDescription)
                        .font(design.fonts.swiftUIFont(for: .caption))
                        .foregroundStyle(theme.secondaryForeground)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                operation.cancel()
            } label: {
                Text("Cancel")
            }
            .buttonStyle(.bordered)
        }
        .font(design.fonts.swiftUIFont(for: .statusLine))
        .padding(10)
        .background(theme.statusLineBackground.opacity(design.opacity.background))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(theme.paneBorderActive, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

#endif
