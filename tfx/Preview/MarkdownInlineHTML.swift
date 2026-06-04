#if os(macOS)
import Foundation
import UniformTypeIdentifiers

enum MarkdownInlineHTML {
    /// Largest local image we are willing to inline as a `data:` URL.
    /// A pathological markdown could otherwise reference a multi-hundred-
    /// MB file and blow up the rendered document / memory.
    static let maxEmbeddedImageBytes = 25 * 1024 * 1024

    static func inlineHTML(_ text: String, baseDirectory: URL? = nil) -> String {
        var html = escapeHTML(text)
        html = html.replacingOccurrences(of: #"`([^`]+)`"#, with: "<code>$1</code>", options: .regularExpression)
        html = html.replacingOccurrences(of: #"\*\*([^*]+)\*\*"#, with: "<strong>$1</strong>", options: .regularExpression)
        html = html.replacingOccurrences(of: #"\*([^*]+)\*"#, with: "<em>$1</em>", options: .regularExpression)
        html = rewriteLinkedImages(in: html, baseDirectory: baseDirectory)
        html = rewriteImages(in: html, baseDirectory: baseDirectory)
        html = rewriteLinks(in: html)
        return html
    }

    /// Replace linked image badges such as
    /// `[![Rust](https://img.shields.io/...)](https://www.rust-lang.org/)`
    /// before normal link rewriting sees the inner image syntax.
    private static func rewriteLinkedImages(in html: String, baseDirectory: URL?) -> String {
        guard let regex = try? NSRegularExpression(
            pattern: #"\[!\[([^\]]*)\]\(([^)]+)\)\]\(([^)]+)\)"#
        ) else {
            return html
        }
        let nsHTML = html as NSString
        let matches = regex.matches(
            in: html,
            range: NSRange(location: 0, length: nsHTML.length)
        )

        let result = nsHTML.mutableCopy() as! NSMutableString
        for match in matches.reversed() {
            let alt = nsHTML.substring(with: match.range(at: 1))
            let imageURL = nsHTML.substring(with: match.range(at: 2))
            let linkURL = nsHTML.substring(with: match.range(at: 3))

            let imageHTML = imageElement(alt: alt, rawURL: imageURL, baseDirectory: baseDirectory)
            let replacement: String
            if isSafeURL(linkURL) {
                replacement = "<a href=\"\(escapeAttribute(linkURL))\">\(imageHTML)</a>"
            } else {
                replacement = imageHTML
            }
            result.replaceCharacters(in: match.range, with: replacement)
        }
        return result as String
    }

    private static func rewriteImages(in html: String, baseDirectory: URL?) -> String {
        guard let regex = try? NSRegularExpression(
            pattern: #"!\[([^\]]*)\]\(([^)]+)\)"#
        ) else {
            return html
        }
        let nsHTML = html as NSString
        let matches = regex.matches(
            in: html,
            range: NSRange(location: 0, length: nsHTML.length)
        )

        let result = nsHTML.mutableCopy() as! NSMutableString
        for match in matches.reversed() {
            let alt = nsHTML.substring(with: match.range(at: 1))
            let rawURL = nsHTML.substring(with: match.range(at: 2))
            result.replaceCharacters(in: match.range, with: imageElement(alt: alt, rawURL: rawURL, baseDirectory: baseDirectory))
        }
        return result as String
    }

    private static func imageElement(alt: String, rawURL: String, baseDirectory: URL?) -> String {
        // Remote (`http`/`https`) and already-embedded (`data:`) images
        // keep their original `src`: their loading is governed by the
        // document CSP (and, for remote, the "load external images"
        // toggle). A local file reference can never load that way —
        // `baseURL` is nil and the CSP doesn't allow `file:` — so read
        // the file ourselves and inline it as a `data:` URL, which the
        // hardened `img-src data:` policy already permits.
        let scheme = urlScheme(of: rawURL)
        switch scheme {
        case "http", "https", "data":
            guard isSafeImageURL(rawURL) else { return escapeHTML(alt) }
            return "<img alt=\"\(escapeAttribute(alt))\" src=\"\(escapeAttribute(rawURL))\">"
        case "file", nil:
            if let dataURL = localImageDataURL(forRawURL: rawURL, baseDirectory: baseDirectory) {
                return "<img alt=\"\(escapeAttribute(alt))\" src=\"\(escapeAttribute(dataURL))\">"
            }
            // Couldn't resolve or read the file — degrade to alt text so
            // the document still reads cleanly instead of showing a
            // broken-image glyph.
            return escapeHTML(alt)
        default:
            // Unknown / disallowed scheme (e.g. `javascript:`): drop it.
            return escapeHTML(alt)
        }
    }

    /// Read a locally-referenced image and return it as a `data:` URL,
    /// or nil when the path can't be resolved, isn't a recognized image
    /// type, exceeds `maxEmbeddedImageBytes`, or can't be read.
    private static func localImageDataURL(forRawURL rawURL: String, baseDirectory: URL?) -> String? {
        guard let fileURL = resolveLocalImageURL(rawURL, baseDirectory: baseDirectory) else {
            return nil
        }
        guard let mimeType = imageMIMEType(for: fileURL) else { return nil }
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let size = attributes[.size] as? Int,
              size <= maxEmbeddedImageBytes else {
            return nil
        }
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return "data:\(mimeType);base64,\(data.base64EncodedString())"
    }

    /// Turn a markdown image path into a filesystem URL. Strips an
    /// optional title (`![alt](path "title")`), percent-decodes, expands
    /// `~`, and resolves relative paths against the markdown file's own
    /// directory.
    private static func resolveLocalImageURL(_ rawURL: String, baseDirectory: URL?) -> URL? {
        var path = stripImageTitle(rawURL).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else { return nil }

        if path.lowercased().hasPrefix("file://") {
            return URL(string: path)?.standardizedFileURL
        }

        if let decoded = path.removingPercentEncoding {
            path = decoded
        }

        let expanded = (path as NSString).expandingTildeInPath
        if expanded.hasPrefix("/") {
            return URL(fileURLWithPath: expanded).standardizedFileURL
        }

        guard let baseDirectory else { return nil }
        // Force the base to be treated as a directory: without a trailing
        // slash, a relative path would resolve against the directory's
        // *parent*, so `image.png` next to the markdown file would miss.
        let directory = URL(fileURLWithPath: baseDirectory.path, isDirectory: true)
        return URL(fileURLWithPath: expanded, relativeTo: directory).standardizedFileURL
    }

    /// Drop a trailing markdown image title — `path "title"` or
    /// `path 'title'` — leaving just the path/URL portion.
    private static func stripImageTitle(_ rawURL: String) -> String {
        let trimmed = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        for quote in ["\"", "'"] where trimmed.contains(" \(quote)") && trimmed.hasSuffix(quote) {
            if let spaceQuoteRange = trimmed.range(of: " \(quote)") {
                return String(trimmed[trimmed.startIndex..<spaceQuoteRange.lowerBound])
                    .trimmingCharacters(in: .whitespaces)
            }
        }
        return trimmed
    }

    /// MIME type for an image file, or nil when the file isn't a
    /// recognized image (so we never read non-image files into memory).
    private static func imageMIMEType(for url: URL) -> String? {
        guard let type = UTType(filenameExtension: url.pathExtension.lowercased()),
              type.conforms(to: .image) else {
            return nil
        }
        if let mime = type.preferredMIMEType {
            return mime
        }
        // SVG has no system-preferred MIME on some OS versions.
        return url.pathExtension.lowercased() == "svg" ? "image/svg+xml" : nil
    }

    /// Lowercased URL scheme, or nil when the string has no scheme
    /// (a bare relative or absolute filesystem path).
    private static func urlScheme(of rawURL: String) -> String? {
        let trimmed = stripImageTitle(rawURL)
        guard let colon = trimmed.firstIndex(of: ":") else { return nil }
        let candidate = trimmed[trimmed.startIndex..<colon]
        // A real scheme is letters/digits/+-. only; anything else before
        // the colon (slash, space, dot of a filename) means it's a path.
        guard !candidate.isEmpty,
              candidate.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "+" || $0 == "-" || $0 == "." }),
              candidate.first?.isLetter == true else {
            return nil
        }
        return candidate.lowercased()
    }

    /// Replace `[text](url)` runs with `<a href="…">…</a>` only when the
    /// URL uses a scheme we consider safe for an offline preview. Other
    /// schemes — most importantly `javascript:` and `data:` — are
    /// stripped and the link is rendered as plain text, so a malicious
    /// markdown file can't smuggle script execution through a link.
    /// The URL itself is also re-escaped after capture so an attacker
    /// can't use an `&quot;` in the URL to break out of the `href`
    /// attribute when WKWebView HTML-decodes the entity at parse time.
    private static func rewriteLinks(in html: String) -> String {
        guard let regex = try? NSRegularExpression(
            pattern: #"\[([^\]]+)\]\(([^)]+)\)"#
        ) else {
            return html
        }
        let nsHTML = html as NSString
        let matches = regex.matches(
            in: html,
            range: NSRange(location: 0, length: nsHTML.length)
        )

        // Build the output by walking matches in reverse so the
        // ranges captured by NSRegularExpression stay valid even as
        // we splice replacement strings into the working buffer.
        let result = nsHTML.mutableCopy() as! NSMutableString
        for match in matches.reversed() {
            let label = nsHTML.substring(with: match.range(at: 1))
            let rawURL = nsHTML.substring(with: match.range(at: 2))

            let replacement: String
            if isSafeURL(rawURL) {
                replacement = "<a href=\"\(escapeAttribute(rawURL))\">\(label)</a>"
            } else {
                // Drop the URL entirely — keep just the link label so
                // the document still reads naturally without smuggling
                // an unsafe href into the DOM.
                replacement = label
            }
            result.replaceCharacters(in: match.range, with: replacement)
        }
        return result as String
    }

    /// A URL is considered safe to render as a hyperlink when its
    /// scheme is one the preview is willing to open. The WKWebView
    /// navigation delegate enforces the same allow-list at click time;
    /// this check at HTML-generation time means unsafe URLs never
    /// reach the DOM in the first place.
    private static func isSafeURL(_ rawURL: String) -> Bool {
        let trimmed = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        // A scheme is the chunk before the first `:` — but parens,
        // spaces, and other non-scheme characters before that disqualify
        // it (markdown lets free text appear in URL position).
        guard let colon = trimmed.firstIndex(of: ":") else {
            // No scheme: treat as relative. Preview disallows relative
            // navigation because `baseURL` is nil, but the href is
            // harmless either way.
            return true
        }
        let scheme = trimmed[trimmed.startIndex..<colon].lowercased()
        let schemeAllowed: Set<String> = ["http", "https", "mailto"]
        return schemeAllowed.contains(scheme)
    }

    private static func isSafeImageURL(_ rawURL: String) -> Bool {
        let trimmed = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let colon = trimmed.firstIndex(of: ":") else {
            return true
        }
        let scheme = trimmed[trimmed.startIndex..<colon].lowercased()
        let schemeAllowed: Set<String> = ["http", "https", "data"]
        return schemeAllowed.contains(scheme)
    }

    /// True when the markdown source references at least one image that
    /// would be fetched over the network (`http` / `https`). Embedded
    /// `data:` images and local/relative paths don't count. This drives
    /// whether the preview offers a "load external images" button at
    /// all — there is no point showing it for a document that has no
    /// remote images to load.
    ///
    /// The pattern matches the same `![alt](url)` syntax the renderer
    /// rewrites, so it also catches the inner image of a linked-image
    /// badge `[![alt](imgURL)](linkURL)`.
    static func containsExternalImageReference(in markdown: String) -> Bool {
        guard let regex = try? NSRegularExpression(
            pattern: #"!\[[^\]]*\]\(([^)]+)\)"#
        ) else {
            return false
        }
        let nsMarkdown = markdown as NSString
        let matches = regex.matches(
            in: markdown,
            range: NSRange(location: 0, length: nsMarkdown.length)
        )
        for match in matches where isExternalImageURL(nsMarkdown.substring(with: match.range(at: 1))) {
            return true
        }
        return false
    }

    private static func isExternalImageURL(_ rawURL: String) -> Bool {
        let trimmed = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let colon = trimmed.firstIndex(of: ":") else {
            return false
        }
        let scheme = trimmed[trimmed.startIndex..<colon].lowercased()
        return scheme == "http" || scheme == "https"
    }

    static func escapeHTML(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    /// Attribute-safe escaping for values placed inside a double-quoted
    /// `href`. Re-encodes `&quot;` that arrived from the initial
    /// `escapeHTML` pass so the WKWebView's HTML decoder cannot turn it
    /// back into a literal `"` and close the attribute.
    private static func escapeAttribute(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
#endif
