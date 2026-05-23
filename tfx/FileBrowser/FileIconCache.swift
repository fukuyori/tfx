#if os(macOS)
import AppKit
import SwiftUI
import UniformTypeIdentifiers

final class FileIconCache: @unchecked Sendable {
    nonisolated static let shared = FileIconCache()

    nonisolated(unsafe) private let cache = NSCache<NSString, NSImage>()

    private init() {}

    nonisolated func icon(for url: URL, cacheKey _: String?, size: CGFloat = 18) -> NSImage {
        let resolvedSize = max(size, 1)
        let pathCacheKey = "path:\(url.standardizedFileURL.path)"
        let key = NSString(string: "\(pathCacheKey):\(Int(resolvedSize))")
        if let cachedIcon = cache.object(forKey: key) {
            return cachedIcon
        }

        let icon = (NSWorkspace.shared.icon(forFile: url.path).copy() as? NSImage)
            ?? fallbackIcon(for: url)
        icon.size = NSSize(width: resolvedSize, height: resolvedSize)
        cache.setObject(icon, forKey: key)
        return icon
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

    var body: some View {
        Image(nsImage: FileIconCache.shared.icon(for: url, cacheKey: cacheKey))
            .renderingMode(.original)
            .resizable()
            .frame(width: 18, height: 18)
            .accessibilityHidden(true)
    }
}
#endif
