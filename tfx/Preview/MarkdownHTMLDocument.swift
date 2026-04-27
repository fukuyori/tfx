#if os(macOS)
import Foundation

enum MarkdownHTMLDocument {
    static let loadingHTML = """
    <!doctype html>
    <html>
    <head>
    <meta charset="utf-8">
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
