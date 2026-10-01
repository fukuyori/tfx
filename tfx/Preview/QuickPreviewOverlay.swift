#if os(macOS)
import SwiftUI

/// A temporary, yazi-style preview displayed over the file panes.
struct QuickPreviewOverlay: View {
    let items: [FileItem]
    let close: () -> Void

    @Environment(\.design) private var design
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(theme.fileListBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme.paneBorderActive, lineWidth: 1))
        .shadow(color: .black.opacity(0.28), radius: 24, y: 8)
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black.opacity(0.18))
        .onExitCommand(perform: close)
    }

    @ViewBuilder
    private var content: some View {
        if items.count > 1 {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(items) { item in
                        Label(item.name, systemImage: item.isDirectory ? "folder" : "doc")
                            .lineLimit(1)
                    }
                }
                .font(design.fonts.swiftUIFont(for: .previewCode))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
            }
        } else if let item = items.first, item.isDirectory {
            QuickPreviewFolderListing(url: item.url)
        } else if let item = items.first {
            PreviewPane(urls: [item.url], showsFileInfo: false)
        } else {
            Text("Nothing selected.")
                .foregroundStyle(theme.secondaryForeground)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

}

private struct QuickPreviewFolderListing: View {
    let url: URL
    @State private var entries: [String] = []
    @State private var message: String?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 3) {
                if let message {
                    Text(message).foregroundStyle(.secondary)
                }
                ForEach(entries, id: \.self) { entry in
                    Text(entry)
                        .lineLimit(1)
                }
            }
            .font(.system(size: 12, design: .monospaced))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
        }
        .task(id: url) {
            let path = url
            let result = await Task.detached(priority: .utility) { () -> (entries: [String], message: String?) in
                guard let enumerator = FileManager.default.enumerator(
                    at: path,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: [.skipsHiddenFiles]
                ) else { return ([], "(empty folder)") }
                var urls: [URL] = []
                var wasCapped = false
                while let entry = enumerator.nextObject() as? URL {
                    if urls.count == 5_000 {
                        wasCapped = true
                        break
                    }
                    urls.append(entry)
                }
                let sorted = urls.sorted {
                    let left = (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                    let right = (try? $1.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                    if left != right { return left }
                    return $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
                }
                let limit = 500
                let names = sorted.prefix(limit).map { value in
                    let isDirectory = (try? value.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                    return value.lastPathComponent + (isDirectory ? "/" : "")
                }
                if names.isEmpty { return ([], "(empty folder)") }
                return (names, wasCapped || sorted.count > limit ? "… first \(limit) entries shown" : nil)
            }.value
            entries = result.entries
            message = result.message
        }
    }
}
#endif
