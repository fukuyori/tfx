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

        guard
            let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
            let permissions = (attributes[.posixPermissions] as? NSNumber)?.intValue
        else {
            return nil
        }

        cache.setObject(NSNumber(value: permissions), forKey: key)
        return permissions
    }

    nonisolated func prefetch(for urls: [URL], cancellation: MetadataPrefetchCancellation) {
        for (index, url) in urls.enumerated() {
            if index.isMultiple(of: 64), cancellation.isCancelled {
                return
            }

            _ = permissions(for: url)
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

        let values = try? url.resourceValues(forKeys: [.localizedTypeDescriptionKey])
        let kind = values?.localizedTypeDescription ?? (isDirectory ? "Folder" : url.pathExtension.uppercased())
        cache.setObject(NSString(string: kind), forKey: key)
        return kind
    }

    nonisolated func prefetch(for items: [FileItem], cancellation: MetadataPrefetchCancellation) {
        for (index, item) in items.enumerated() {
            if index.isMultiple(of: 64), cancellation.isCancelled {
                return
            }

            _ = kind(for: item.url, isDirectory: item.isDirectory)
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
