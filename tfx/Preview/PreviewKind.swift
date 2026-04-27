#if os(macOS)
import Foundation
import UniformTypeIdentifiers

enum PreviewKind {
    case pdf
    case video
    case markdown
    case quickLook

    nonisolated init(url: URL) {
        let extensionName = url.pathExtension.lowercased()
        let type = UTType(filenameExtension: extensionName)

        if ["md", "markdown", "mdown", "mkd"].contains(extensionName) {
            self = .markdown
        } else if type?.conforms(to: .pdf) == true {
            self = .pdf
        } else if type?.conforms(to: .movie) == true {
            self = .video
        } else {
            self = .quickLook
        }
    }
}

final class PreviewKindCache: @unchecked Sendable {
    nonisolated static let shared = PreviewKindCache()

    nonisolated(unsafe) private var cache: [String: PreviewKind] = [:]
    private let lock = NSLock()

    private init() {}

    nonisolated func kind(for url: URL) -> PreviewKind {
        let key = url.pathExtension.lowercased()
        lock.lock()
        if let cachedKind = cache[key] {
            lock.unlock()
            return cachedKind
        }
        lock.unlock()

        let kind = PreviewKind(url: url)
        lock.lock()
        cache[key] = kind
        lock.unlock()
        return kind
    }
}
#endif
