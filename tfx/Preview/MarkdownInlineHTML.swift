#if os(macOS)
import Foundation

enum MarkdownInlineHTML {
    static func inlineHTML(_ text: String) -> String {
        var html = escapeHTML(text)
        html = html.replacingOccurrences(of: #"`([^`]+)`"#, with: "<code>$1</code>", options: .regularExpression)
        html = html.replacingOccurrences(of: #"\*\*([^*]+)\*\*"#, with: "<strong>$1</strong>", options: .regularExpression)
        html = html.replacingOccurrences(of: #"\*([^*]+)\*"#, with: "<em>$1</em>", options: .regularExpression)
        html = rewriteLinks(in: html)
        return html
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
