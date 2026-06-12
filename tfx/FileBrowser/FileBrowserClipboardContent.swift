#if os(macOS)
import AppKit
import ImageIO
import UniformTypeIdentifiers

/// One concrete way the system clipboard can be turned into a
/// file on disk. The cases are ordered roughly by user
/// expectation — when more than one shape is present (the
/// typical case, e.g. spreadsheet copies put both CSV/TSV and a
/// plain-text rendering on the pasteboard), the order of
/// `detectAll` is what drives the default Cmd+V behavior.
enum ClipboardContentSource {
    case image(Data)
    case csv(Data)
    case tsv(String)
    case url(URL)
    case rtf(Data)
    case plainText(String)

    var defaultExtension: String {
        switch self {
        case .image: return "png"
        case .csv, .tsv: return "csv"
        case .url: return "url"
        case .rtf: return "rtf"
        case .plainText: return "txt"
        }
    }
}

enum FileBrowserClipboardContent {
    /// Sources in priority order — earliest match wins for the
    /// default Cmd+V paste.
    ///
    /// CSV / TSV / RTF / URL are placed before `image` because
    /// every modern spreadsheet (Excel, Numbers, Google Sheets
    /// via Safari) also ships a rasterized PNG/TIFF preview of
    /// the selection on the pasteboard, and picking the image
    /// over the actual cell data is almost never what the user
    /// wants. The `image` slot is for true image producers
    /// (screenshots, Preview.app, scanners) that don't publish
    /// any text-shaped payload.
    static func detectAll(from pasteboard: NSPasteboard = .general) -> [ClipboardContentSource] {
        var sources: [ClipboardContentSource] = []

        if let csvData = csvData(from: pasteboard) {
            sources.append(.csv(csvData))
        } else if let tsvText = tsvText(from: pasteboard) {
            sources.append(.tsv(tsvText))
        }

        if let rtfData = pasteboard.data(forType: .rtf) {
            sources.append(.rtf(rtfData))
        }

        if let url = nonFileURL(from: pasteboard) {
            sources.append(.url(url))
        }

        if let imageData = imagePNGData(from: pasteboard) {
            sources.append(.image(imageData))
        }

        if let text = pasteboard.string(forType: .string), !text.isEmpty {
            sources.append(.plainText(text))
        }

        return sources
    }

    static func defaultSource(from pasteboard: NSPasteboard = .general) -> ClipboardContentSource? {
        detectAll(from: pasteboard).first
    }

    /// Force the plain-text representation. Used by
    /// `pasteAsText` (Phase 2). When no plain text is on the
    /// pasteboard but RTF / HTML is, returns nil instead of
    /// trying to flatten the markup — the user can fall back to
    /// regular Cmd+V if they want the `.rtf`/`.html` file.
    static func plainTextSource(from pasteboard: NSPasteboard = .general) -> ClipboardContentSource? {
        if let text = pasteboard.string(forType: .string), !text.isEmpty {
            return .plainText(text)
        }
        return nil
    }

    /// Write `source` to `directory` using `clipboardBaseName`
    /// + the source's default extension; conflict-resolves the
    /// name via `FileConflictResolver` and returns the resulting
    /// URL so the caller can enter inline rename on it.
    static func writeFile(
        _ source: ClipboardContentSource,
        in directory: URL,
        baseName: String
    ) throws -> URL {
        let filename = "\(baseName).\(source.defaultExtension)"
        let destination = FileConflictResolver.uniqueDestination(for: filename, in: directory)

        switch source {
        case .image(let data):
            try data.write(to: destination, options: .atomic)
        case .csv(let data):
            try data.write(to: destination, options: .atomic)
        case .tsv(let text):
            let csv = csvFromTSV(text)
            try Data(csv.utf8).write(to: destination, options: .atomic)
        case .url(let url):
            let body = urlShortcutBody(for: url)
            try Data(body.utf8).write(to: destination, options: .atomic)
        case .rtf(let data):
            try data.write(to: destination, options: .atomic)
        case .plainText(let text):
            try Data(text.utf8).write(to: destination, options: .atomic)
        }

        return destination
    }

    // MARK: - Format-specific clipboard readers

    /// Resolve any image-shaped clipboard data into PNG bytes.
    /// PNG passes through; TIFF / PDF / generic `public.image`
    /// data is round-tripped through `CGImageSource` →
    /// `CGImageDestination` so the on-disk file is always
    /// PNG regardless of what the producer put on the pasteboard
    /// (scanners and PDF viewers commonly use CF_DIB / CF_DIBV5
    /// equivalents like TIFF on macOS).
    private static func imagePNGData(from pasteboard: NSPasteboard) -> Data? {
        if let png = pasteboard.data(forType: .png) {
            return png
        }
        if let tiff = pasteboard.data(forType: .tiff), let png = pngData(from: tiff) {
            return png
        }
        if let pdf = pasteboard.data(forType: .pdf), let png = pngData(from: pdf) {
            return png
        }
        return nil
    }

    private static func pngData(from sourceData: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(sourceData as CFData, nil),
              CGImageSourceGetCount(source) > 0 else { return nil }
        let buffer = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            buffer,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else { return nil }
        CGImageDestinationAddImageFromSource(destination, source, 0, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return buffer as Data
    }

    private static func csvData(from pasteboard: NSPasteboard) -> Data? {
        let csvTypes: [NSPasteboard.PasteboardType] = [
            .init("public.comma-separated-values-text"),
            .init("public.comma-separated-values"),
            .init("com.microsoft.csv"),
        ]
        for type in csvTypes {
            if let data = pasteboard.data(forType: type), !data.isEmpty {
                return data
            }
        }
        return nil
    }

    /// Excel and Numbers both publish their selection as both
    /// HTML and tab-separated UTF-8. The TSV is usually under
    /// `public.utf8-tab-separated-values-text` /
    /// `public.tab-separated-values-text` but some producers
    /// only put it under `.string` — so as a last resort we
    /// sniff the plain text for tabs.
    private static func tsvText(from pasteboard: NSPasteboard) -> String? {
        let tsvTypes: [NSPasteboard.PasteboardType] = [
            .init("public.utf8-tab-separated-values-text"),
            .init("public.tab-separated-values-text"),
        ]
        for type in tsvTypes {
            if let text = pasteboard.string(forType: type), !text.isEmpty {
                return text
            }
        }
        if let text = pasteboard.string(forType: .string), looksTabSeparated(text) {
            return text
        }
        return nil
    }

    private static func looksTabSeparated(_ text: String) -> Bool {
        // Heuristic: at least one tab and at least one newline,
        // with the first non-empty line containing a tab. Avoids
        // misclassifying a plain log line that happens to have a
        // stray `\t`.
        guard text.contains("\t") else { return false }
        let firstLine = text.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
            .first
            .map(String.init) ?? ""
        return firstLine.contains("\t")
    }

    private static func nonFileURL(from pasteboard: NSPasteboard) -> URL? {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: false,
        ]
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL],
           let url = urls.first(where: { !$0.isFileURL && $0.scheme != nil }) {
            return url
        }

        // Fallback: some producers (notably Safari when copying
        // a hyperlink's text rather than the link itself, and
        // every plain-text source like Notes / Mail body / VS
        // Code) ship the URL only as `public.utf8-plain-text`
        // with no `public.url`. If the whole trimmed string is
        // one well-formed URL with a recognized network scheme,
        // treat it as a URL paste so the user lands on `.url`
        // instead of `.txt`.
        guard let raw = pasteboard.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty,
              !raw.contains(where: { $0.isWhitespace || $0.isNewline }),
              let url = URL(string: raw),
              let scheme = url.scheme?.lowercased(),
              ["http", "https", "ftp", "ftps", "sftp", "ssh", "mailto"].contains(scheme)
        else { return nil }
        return url
    }

    // MARK: - Writers

    /// Convert a tab-separated row dump into a strictly-quoted
    /// CSV body. Excel and Numbers paste tabs between cells and
    /// CR/LF between rows; the result is RFC-4180-shaped so
    /// downstream parsers don't choke on embedded commas /
    /// quotes / newlines inside cells.
    private static func csvFromTSV(_ text: String) -> String {
        var output = ""
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let lines = normalized.split(separator: "\n", omittingEmptySubsequences: false)
        for (lineIndex, line) in lines.enumerated() {
            let cells = line.split(separator: "\t", omittingEmptySubsequences: false)
            let quoted = cells.map { cell -> String in
                let raw = String(cell)
                let needsQuotes = raw.contains(",") || raw.contains("\"") || raw.contains("\n")
                if needsQuotes {
                    return "\"\(raw.replacingOccurrences(of: "\"", with: "\"\""))\""
                }
                return raw
            }
            output.append(quoted.joined(separator: ","))
            if lineIndex < lines.count - 1 {
                output.append("\r\n")
            }
        }
        return output
    }

    /// Body of a Windows-style `.url` Internet Shortcut. Finder
    /// recognizes this layout and treats it as a link when
    /// double-clicked.
    private static func urlShortcutBody(for url: URL) -> String {
        "[InternetShortcut]\r\nURL=\(url.absoluteString)\r\n"
    }
}

#endif
