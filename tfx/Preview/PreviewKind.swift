#if os(macOS)
import Foundation
import UniformTypeIdentifiers

enum PreviewKind {
    case pdf
    case video
    case markdown
    case csv
    case json
    /// Plain-text formats with no separate rendered form — config files,
    /// logs, and similar. Displayed directly through `RawTextPreview` so we
    /// don't depend on Quick Look having a generator for the extension.
    case text
    case quickLook

    nonisolated init(url: URL) {
        let extensionName = url.pathExtension.lowercased()
        let type = UTType(filenameExtension: extensionName)

        if ["md", "markdown", "mdown", "mkd"].contains(extensionName) {
            self = .markdown
        } else if ["csv", "tsv"].contains(extensionName) {
            self = .csv
        } else if extensionName == "json" {
            self = .json
        } else if Self.plainTextExtensions.contains(extensionName) {
            self = .text
        } else if type?.conforms(to: .pdf) == true {
            self = .pdf
        } else if type?.conforms(to: .movie) == true {
            self = .video
        } else {
            self = .quickLook
        }
    }

    /// Extensions routed to the built-in plain-text preview. Limited to
    /// common config and log formats so we do not steal Quick Look's
    /// syntax-highlighted source-code rendering for `.swift`, `.py`, etc.
    nonisolated private static let plainTextExtensions: Set<String> = [
        "toml",
        "yaml", "yml",
        "ini", "cfg", "conf",
        "log",
        "txt",
        "env",
    ]
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
