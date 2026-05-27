#if os(macOS)
import Foundation

/// Shared file loader for the text-based previews (raw text, JSON, CSV).
///
/// Each of those views previously called `String(contentsOf:)` /
/// `Data(contentsOf:)` directly, with no upper bound on the bytes
/// pulled into memory. A pathological file (a several-GB log or an
/// intentionally crafted bomb dropped into a watched folder) would
/// blow out tfx's resident memory just by being selected.
///
/// The loader caps the eagerly read size at `maxBytes` and returns a
/// `.tooLarge` sentinel above the cap so each preview can render a
/// neutral "file too large to preview" message instead of attempting
/// the load. Network-mounted or FileProvider-backed files report the
/// metadata size cheaply, so the cap check is essentially free.
enum PreviewTextLoader {
    /// Hard cap on the bytes a single text-based preview will load
    /// into memory. 50 MB comfortably fits typical source files, logs,
    /// and CSV dumps while keeping a misbehaving file from exhausting
    /// the process. Larger limits would mostly hurt UX (long parse
    /// time) without unlocking realistic use cases.
    static let maxBytes: Int64 = 50 * 1024 * 1024

    enum Outcome {
        case success(String)
        case tooLarge(actualBytes: Int64)
    }

    static func load(at url: URL) -> Outcome {
        let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey])
        let size = Int64(resourceValues?.fileSize ?? 0)
        if size > maxBytes {
            return .tooLarge(actualBytes: size)
        }

        if let text = try? String(contentsOf: url, encoding: .utf8) {
            return .success(text)
        }
        let data = (try? Data(contentsOf: url)) ?? Data()
        return .success(String(decoding: data, as: UTF8.self))
    }

    /// User-visible label for the "too big to preview" placeholder.
    /// Built from `ByteCountFormatter` so the user sees the same units
    /// Finder shows (e.g. `120 MB`).
    static func tooLargeMessage(actualBytes: Int64) -> String {
        let actual = ByteCountFormatter.string(fromByteCount: actualBytes, countStyle: .file)
        let limit = ByteCountFormatter.string(fromByteCount: maxBytes, countStyle: .file)
        return String(localized: "File too large to preview (\(actual) / limit \(limit)).")
    }
}
#endif
