#if os(macOS)
import Foundation

final class FilePermissionCache {
    static let shared = FilePermissionCache()

    nonisolated(unsafe) private let cache = NSCache<NSString, NSNumber>()

    nonisolated func permissions(for url: URL) -> Int? {
        let key = NSString(string: url.path)
        if let cachedPermissions = cache.object(forKey: key) {
            return cachedPermissions.intValue
        }
        // Cache miss: schedule a background fill instead of doing
        // synchronous `attributesOfItem` on the caller (usually
        // the main thread, mid-scroll). The cell renders `-` for
        // this frame; the next render after the fill picks up the
        // cached value. This eliminates the scroll stutter that
        // hit large directories before the prefetch pass caught
        // up.
        fill(for: url)
        return nil
    }

    nonisolated func prefetch(for urls: [URL], cancellation: MetadataPrefetchCancellation) {
        // `prefetch` itself is invoked from the background
        // metadata-prefetch work item, so do the disk read
        // inline (`fillNow`) — going through `fill` would
        // re-dispatch each item to another global queue for no
        // benefit, just 1000 extra GCD enqueues per directory
        // load.
        for (index, url) in urls.enumerated() {
            if index.isMultiple(of: 64), cancellation.isCancelled {
                return
            }
            fillNow(for: url)
        }
    }

    /// Synchronously read POSIX permissions from disk and cache
    /// the result. Called only from a background context — either
    /// the prefetch pass or the on-miss background dispatch from
    /// `permissions(for:)`.
    nonisolated private func fillNow(for url: URL) {
        let key = NSString(string: url.path)
        guard cache.object(forKey: key) == nil else { return }
        guard
            let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
            let permissions = (attributes[.posixPermissions] as? NSNumber)?.intValue
        else { return }
        cache.setObject(NSNumber(value: permissions), forKey: key)
    }

    nonisolated private func fill(for url: URL) {
        DispatchQueue.global(qos: .utility).async {
            self.fillNow(for: url)
        }
    }
}

final class FileKindCache {
    static let shared = FileKindCache()

    nonisolated(unsafe) private let cache = NSCache<NSString, NSString>()

    nonisolated func kind(for url: URL, isDirectory: Bool) -> String {
        let key = NSString(string: url.path)
        if let cachedKind = cache.object(forKey: key) {
            return cachedKind as String
        }
        // Cache miss: return the cheap fallback now, fill the
        // accurate localized-type-description in the background.
        // The next render after the fill picks up the real
        // value. Avoids `url.resourceValues(...)` (a possibly
        // slow LaunchServices lookup) on the caller's thread.
        let fallback = isDirectory ? String(localized: "Folder") : url.pathExtension.uppercased()
        fill(url: url, isDirectory: isDirectory)
        return fallback
    }

    nonisolated func prefetch(for items: [FileItem], cancellation: MetadataPrefetchCancellation) {
        // Already runs on the background metadata-prefetch
        // queue — do the lookup inline (`fillNow`) instead of
        // re-dispatching each item.
        for (index, item) in items.enumerated() {
            if index.isMultiple(of: 64), cancellation.isCancelled {
                return
            }
            fillNow(url: item.url, isDirectory: item.isDirectory)
        }
    }

    nonisolated private func fillNow(url: URL, isDirectory: Bool) {
        let key = NSString(string: url.path)
        guard cache.object(forKey: key) == nil else { return }
        let values = try? url.resourceValues(forKeys: [.localizedTypeDescriptionKey])
        let kind = values?.localizedTypeDescription
            ?? (isDirectory ? String(localized: "Folder") : url.pathExtension.uppercased())
        cache.setObject(NSString(string: kind), forKey: key)
    }

    nonisolated private func fill(url: URL, isDirectory: Bool) {
        DispatchQueue.global(qos: .utility).async {
            self.fillNow(url: url, isDirectory: isDirectory)
        }
    }
}

final class FolderDisplayNameCache: @unchecked Sendable {
    nonisolated static let shared = FolderDisplayNameCache()

    nonisolated(unsafe) private let cache = NSCache<NSString, NSString>()

    private init() {}

    nonisolated func displayName(for url: URL) -> String {
        if url.path == "/" {
            return "/"
        }

        let key = NSString(string: url.standardizedFileURL.path)
        if let cachedName = cache.object(forKey: key) {
            return cachedName as String
        }

        let displayName = FileManager.default.displayName(atPath: url.path)
        let resolvedName = displayName.isEmpty ? url.lastPathComponent : displayName
        cache.setObject(NSString(string: resolvedName), forKey: key)
        return resolvedName
    }
}

final class FileDisplayTextCache: @unchecked Sendable {
    nonisolated static let shared = FileDisplayTextCache()

    nonisolated(unsafe) private let sizeCache = NSCache<NSNumber, NSString>()
    nonisolated(unsafe) private let dateCache = NSCache<NSString, NSString>()
    nonisolated(unsafe) private let sizeFormatter = ByteCountFormatter()
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
    private let sizeLock = NSLock()
    private let dateLock = NSLock()

    private init() {
        sizeFormatter.countStyle = .file
    }

    nonisolated func sizeText(byteCount: Int64) -> String {
        let key = NSNumber(value: byteCount)
        if let cachedText = sizeCache.object(forKey: key) {
            return cachedText as String
        }

        sizeLock.lock()
        let text = sizeFormatter.string(fromByteCount: byteCount)
        sizeLock.unlock()
        sizeCache.setObject(NSString(string: text), forKey: key)
        return text
    }

    nonisolated func dateText(for date: Date?) -> String {
        guard let date else { return "-" }

        let key = NSString(string: String(format: "%.0f", date.timeIntervalSinceReferenceDate))
        if let cachedText = dateCache.object(forKey: key) {
            return cachedText as String
        }

        dateLock.lock()
        let text = dateFormatter.string(from: date)
        dateLock.unlock()
        dateCache.setObject(NSString(string: text), forKey: key)
        return text
    }
}
#endif
