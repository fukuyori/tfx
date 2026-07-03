#if os(macOS)
import AppKit
import SwiftUI
import UniformTypeIdentifiers

final class FileIconCache: @unchecked Sendable {
    nonisolated static let shared = FileIconCache()

    nonisolated(unsafe) private let cache = NSCache<NSString, NSImage>()

    private init() {
        // Path-keyed entries would otherwise accumulate one
        // NSImage per visited file for the whole session.
        // Generous enough that a big visible working set never
        // thrashes, small enough to bound long-session memory.
        cache.countLimit = 4_096
    }

    nonisolated func icon(for url: URL, cacheKey: String?, size: CGFloat = 18) -> NSImage {
        let resolvedSize = max(size, 1)
        let key = NSString(string: "\(baseKey(for: url, cacheKey: cacheKey)):\(Int(resolvedSize))")
        if let cachedIcon = cache.object(forKey: key) {
            return cachedIcon
        }

        let icon = (NSWorkspace.shared.icon(forFile: url.path).copy() as? NSImage)
            ?? fallbackIcon(for: url)
        icon.size = NSSize(width: resolvedSize, height: resolvedSize)
        cache.setObject(icon, forKey: key)
        return icon
    }

    /// Plain files with an extension share one cached image per
    /// extension (`FileItem.iconCacheKey` = "file.<ext>"): their
    /// `NSWorkspace` icon is the file-type icon, identical for
    /// every `.swift` / `.png` / … file, so 10k same-type files
    /// cost one LaunchServices query instead of 10k — which is
    /// what caused per-row main-thread hitches when scrolling
    /// past the 1,000-item prefetch horizon. Directories (and
    /// bundles, whose `iconCacheKey` is "directory") stay
    /// path-keyed: Desktop / Documents / `.app` icons genuinely
    /// differ per path. Extensionless files ("file") also stay
    /// path-keyed — executables get a distinct icon from plain
    /// documents. Callers without a `FileItem` pass nil and get
    /// the conservative path key.
    nonisolated private func baseKey(for url: URL, cacheKey: String?) -> String {
        if let cacheKey, cacheKey.hasPrefix("file."), !cacheKey.hasSuffix(".") {
            return "ext:\(cacheKey)"
        }
        return "path:\(url.standardizedFileURL.path)"
    }

    /// Background-friendly bulk prefetch. Warms the cache for the given
    /// items at the default row icon size so the first SwiftUI render path
    /// does not need to call `NSWorkspace.shared.icon(forFile:)` on the
    /// main thread. Bails out periodically when the cancellation signals.
    nonisolated func prefetch(for items: [FileItem], cancellation: MetadataPrefetchCancellation) {
        for (index, item) in items.enumerated() {
            if index.isMultiple(of: 64), cancellation.isCancelled {
                return
            }
            _ = icon(for: item.url, cacheKey: item.iconCacheKey)
        }
    }

    nonisolated private func fallbackIcon(for url: URL) -> NSImage {
        if let contentType = UTType(filenameExtension: url.pathExtension) {
            return NSWorkspace.shared.icon(for: contentType)
        }

        return NSWorkspace.shared.icon(for: url.hasDirectoryPath ? .folder : .data)
    }
}

struct FileIcon: View {
    let url: URL
    var cacheKey: String? = nil
    /// Override that, when non-nil, renders the row icon as a colored
    /// `folder.fill` SF Symbol instead of the standard `NSWorkspace` icon.
    /// Used to mimic Finder's behavior of tinting the folder body with
    /// the primary tag color.
    var folderTagColor: Color? = nil

    /// Legacy convenience initializer for callers that do not have a
    /// `FileItem` in scope (preview panes, drag images, etc.).
    init(url: URL, cacheKey: String? = nil) {
        self.url = url
        self.cacheKey = cacheKey
        self.folderTagColor = nil
    }

    /// File-row initializer that resolves the primary tag color when the
    /// item is a directory. Files keep the standard icon — their tags
    /// remain visible through the tag-column dots.
    init(item: FileItem) {
        self.url = item.url
        self.cacheKey = item.iconCacheKey
        if item.isDirectory, let color = item.tags.first(where: { $0.color != nil })?.color {
            self.folderTagColor = color
        } else {
            self.folderTagColor = nil
        }
    }

    var body: some View {
        if let folderTagColor {
            Image(systemName: "folder.fill")
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(folderTagColor)
                .frame(width: 18, height: 18)
                .accessibilityHidden(true)
        } else {
            Image(nsImage: FileIconCache.shared.icon(for: url, cacheKey: cacheKey))
                .renderingMode(.original)
                .resizable()
                .frame(width: 18, height: 18)
                .accessibilityHidden(true)
        }
    }
}
#endif
