#if os(macOS)
import Foundation

enum MarkdownHTMLDocument {
    /// Content-Security-Policy that locks the markdown preview down to
    /// inline `<style>` only. `default-src 'none'` blocks every other
    /// resource type by default; `style-src 'unsafe-inline'` re-enables
    /// just the inline stylesheet the renderer ships. Crucially this
    /// blocks `<script>` execution (`script-src` falls back to
    /// `default-src 'none'`), external `<img>` and `<iframe>` loads,
    /// and `connect-src` (no fetch/XHR), defending against an
    /// attacker-controlled markdown source even if a future renderer
    /// change inadvertently lets HTML through. WKWebView already has
    /// JavaScript globally disabled in `WKWebViewConfiguration`; the
    /// CSP is defense in depth.
    private static let csp = "default-src 'none'; style-src 'unsafe-inline'; img-src data:; base-uri 'none'; form-action 'none'"

    static let loadingHTML = """
    <!doctype html>
    <html>
    <head>
    <meta charset="utf-8">
    <meta http-equiv="Content-Security-Policy" content="\(csp)">
    <style>
    :root { color-scheme: light dark; }
    body {
      margin: 0;
      padding: 20px;
      font: -apple-system-body;
      color: color-mix(in srgb, CanvasText 55%, Canvas);
      background: Canvas;
    }
    </style>
    </head>
    <body>Loading preview...</body>
    </html>
    """

    static func document(body: String) -> String {
        """
        <!doctype html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta http-equiv="Content-Security-Policy" content="\(csp)">
        <style>
        :root { color-scheme: light dark; }
        body {
          margin: 0;
          padding: 20px;
          font: -apple-system-body;
          line-height: 1.55;
          color: CanvasText;
          background: Canvas;
        }
        code, pre {
          font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
        }
        pre {
          padding: 12px;
          overflow: auto;
          border-radius: 6px;
          background: color-mix(in srgb, CanvasText 8%, Canvas);
        }
        blockquote {
          margin-left: 0;
          padding-left: 14px;
          border-left: 3px solid color-mix(in srgb, CanvasText 35%, Canvas);
          color: color-mix(in srgb, CanvasText 75%, Canvas);
        }
        table {
          display: block;
          max-width: 100%;
          margin: 1em 0;
          overflow-x: auto;
          border-collapse: collapse;
        }
        th,
        td {
          padding: 6px 10px;
          border: 1px solid color-mix(in srgb, CanvasText 22%, Canvas);
          vertical-align: top;
        }
        th {
          font-weight: 600;
          background: color-mix(in srgb, CanvasText 8%, Canvas);
        }
        tbody tr:nth-child(even) {
          background: color-mix(in srgb, CanvasText 4%, Canvas);
        }
        img { max-width: 100%; height: auto; }
        a { color: LinkText; }
        </style>
        </head>
        <body>
        \(body)
        </body>
        </html>
        """
    }
}

extension MarkdownHTMLRenderer {
    static var loadingHTML: String {
        MarkdownHTMLDocument.loadingHTML
    }
}
#endif
