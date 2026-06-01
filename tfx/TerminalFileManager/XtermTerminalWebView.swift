#if os(macOS)
import AppKit
import Combine
import SwiftUI
import WebKit

struct XtermTerminalWebView: NSViewRepresentable {
    @ObservedObject var model: BuiltInTerminalModel
    let isActive: Bool
    let theme: Theme
    let design: DesignTokens
    @FocusState.Binding var isInputFocused: Bool
    @Binding var isPathDropTarget: Bool
    let activate: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            model: model,
            isInputFocused: $isInputFocused,
            isPathDropTarget: $isPathDropTarget,
            activate: activate
        )
    }

    func makeNSView(context: Context) -> WKWebView {
        let userContentController = WKUserContentController()
        userContentController.add(context.coordinator, name: "terminalInput")
        userContentController.add(context.coordinator, name: "terminalFocus")
        userContentController.add(context.coordinator, name: "terminalResize")
        userContentController.add(context.coordinator, name: "terminalReady")
        userContentController.add(context.coordinator, name: "terminalError")

        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true

        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences = preferences
        configuration.userContentController = userContentController

        let view = TerminalDropWebView(frame: .zero, configuration: configuration)
        view.setValue(false, forKey: "drawsBackground")
        view.navigationDelegate = context.coordinator
        view.onFileDrop = { [weak coordinator = context.coordinator] urls in
            coordinator?.handleDroppedFileURLs(urls)
        }
        view.onFileDragStateChange = { [weak coordinator = context.coordinator] isTargeted in
            coordinator?.setPathDropTarget(isTargeted)
        }
        context.coordinator.webView = view
        context.coordinator.startObservingOutput()
        view.loadHTMLString(htmlDocument(), baseURL: nil)
        return view
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        context.coordinator.model = model
        context.coordinator.isActive = isActive
        context.coordinator.isInputFocused = $isInputFocused
        context.coordinator.isPathDropTarget = $isPathDropTarget
        context.coordinator.activate = activate
        context.coordinator.applyTheme(theme: theme, design: design)
        if isActive {
            context.coordinator.focusTerminal()
        } else {
            context.coordinator.blurTerminal()
        }
    }

    static func dismantleNSView(_ nsView: WKWebView, coordinator: Coordinator) {
        coordinator.stopObservingOutput()
        nsView.configuration.userContentController.removeScriptMessageHandler(forName: "terminalInput")
        nsView.configuration.userContentController.removeScriptMessageHandler(forName: "terminalFocus")
        nsView.configuration.userContentController.removeScriptMessageHandler(forName: "terminalResize")
        nsView.configuration.userContentController.removeScriptMessageHandler(forName: "terminalReady")
        nsView.configuration.userContentController.removeScriptMessageHandler(forName: "terminalError")
        nsView.stopLoading()
    }

    private func htmlDocument() -> String {
        let terminalTheme = XtermTheme(theme: theme, design: design)
        return """
        <!doctype html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline'; img-src data:; font-src data:; connect-src 'none'; base-uri 'none'; form-action 'none'">
        <style>
        \(XtermAssets.xtermStyleSheet)
        html, body {
          width: 100%;
          height: 100%;
          margin: 0;
          overflow: hidden;
          background: \(terminalTheme.background);
        }
        #terminal {
          width: 100%;
          height: 100%;
        }
        .xterm {
          height: 100%;
          padding: 10px;
          box-sizing: border-box;
        }
        </style>
        </head>
        <body>
        <div id="terminal"></div>
        <script>
        function tfxReportError(error) {
          let message = "";
          if (error && error.name) {
            message += error.name;
          }
          if (error && error.message) {
            message += (message ? ": " : "") + error.message;
          }
          if (!message) {
            message = String(error);
          }
          if (error && error.stack) {
            message += "\\n" + error.stack;
          }
          document.body.textContent = message;
          document.body.style.color = \(jsonString(terminalTheme.foreground));
          document.body.style.fontFamily = \(jsonString(terminalTheme.fontFamily));
          document.body.style.fontSize = "\(terminalTheme.fontSize)px";
          document.body.style.whiteSpace = "pre-wrap";
          document.body.style.padding = "10px";
          try {
            window.webkit.messageHandlers.terminalError.postMessage(message);
          } catch (_) {}
        }
        window.onerror = function(message, source, line, column, error) {
          tfxReportError(error || message);
        };
        window.onunhandledrejection = function(event) {
          tfxReportError(event.reason || "Unhandled promise rejection");
        };
        \(XtermAssets.xtermJavaScript)
        \(XtermAssets.fitAddonJavaScript)
        try {
          const fitAddon = new FitAddon.FitAddon();
          const term = new Terminal({
            allowProposedApi: true,
            cursorBlink: true,
            convertEol: false,
            fontFamily: \(jsonString(terminalTheme.fontFamily)),
            fontSize: \(terminalTheme.fontSize),
            letterSpacing: 0,
            scrollback: 5000,
            theme: \(terminalTheme.json)
          });
          term.loadAddon(fitAddon);
          term.open(document.getElementById('terminal'));
          term.onData(data => {
            window.webkit.messageHandlers.terminalInput.postMessage(data);
          });
          const terminalElement = document.getElementById('terminal');
          terminalElement.addEventListener('focusin', () => {
            window.webkit.messageHandlers.terminalFocus.postMessage(null);
          });
          terminalElement.addEventListener('mousedown', () => {
            window.webkit.messageHandlers.terminalFocus.postMessage(null);
          });
          function fitAndReport() {
            const container = document.getElementById('terminal');
            if (container && container.clientWidth > 0 && container.clientHeight > 0) {
              try {
                fitAddon.fit();
              } catch (error) {
                console.error(error);
              }
            }
            window.webkit.messageHandlers.terminalResize.postMessage({ cols: term.cols, rows: term.rows });
          }
          window.tfxWrite = function(data) {
            term.write(data);
          };
          window.tfxFocus = function() {
            term.focus();
          };
          window.tfxBlur = function() {
            term.blur();
          };
          window.tfxApplyTheme = function(options) {
            term.options.fontFamily = options.fontFamily;
            term.options.fontSize = options.fontSize;
            term.options.letterSpacing = 0;
            term.options.theme = options.theme;
            fitAndReport();
          };
          window.addEventListener('resize', fitAndReport);
          new ResizeObserver(fitAndReport).observe(document.body);
          requestAnimationFrame(() => {
            fitAndReport();
            term.focus();
            window.webkit.messageHandlers.terminalReady.postMessage({ cols: term.cols, rows: term.rows });
          });
        } catch (error) {
          tfxReportError(error);
        }
        </script>
        </body>
        </html>
        """
    }

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        var model: BuiltInTerminalModel
        var isActive = false
        var isInputFocused: FocusState<Bool>.Binding
        var isPathDropTarget: Binding<Bool>
        var activate: () -> Void
        weak var webView: WKWebView?

        private var outputCancellable: AnyCancellable?
        private var pendingOutput: [String] = []
        private var isReady = false

        init(
            model: BuiltInTerminalModel,
            isInputFocused: FocusState<Bool>.Binding,
            isPathDropTarget: Binding<Bool>,
            activate: @escaping () -> Void
        ) {
            self.model = model
            self.isInputFocused = isInputFocused
            self.isPathDropTarget = isPathDropTarget
            self.activate = activate
        }

        func startObservingOutput() {
            outputCancellable = model.$outputEvent
                .compactMap { $0?.text }
                .sink { [weak self] output in
                    self?.write(output)
                }
        }

        func stopObservingOutput() {
            outputCancellable?.cancel()
            outputCancellable = nil
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            switch message.name {
            case "terminalInput":
                guard let input = message.body as? String else { return }
                activate()
                model.sendTerminalInput(input)
            case "terminalFocus":
                activate()
                isInputFocused.wrappedValue = true
                webView?.window?.makeFirstResponder(webView)
            case "terminalResize":
                resize(from: message.body)
            case "terminalReady":
                isReady = true
                resize(from: message.body)
                model.open()
                flushPendingOutput()
                focusTerminal()
            case "terminalError":
                if let error = message.body as? String {
                    model.reportStartupError(error)
                }
            default:
                return
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            focusTerminal()
        }

        func applyTheme(theme: Theme, design: DesignTokens) {
            guard isReady else { return }
            let terminalTheme = XtermTheme(theme: theme, design: design)
            evaluate("window.tfxApplyTheme && window.tfxApplyTheme(\(terminalTheme.optionsJSON));")
        }

        func focusTerminal() {
            isInputFocused.wrappedValue = true
            DispatchQueue.main.async { [weak self] in
                guard let self, let webView = self.webView else { return }
                webView.window?.makeFirstResponder(webView)
                webView.evaluateJavaScript("window.tfxFocus && window.tfxFocus();", completionHandler: nil)
            }
        }

        func blurTerminal() {
            isInputFocused.wrappedValue = false
            DispatchQueue.main.async { [weak self] in
                guard let self, let webView = self.webView else { return }
                webView.evaluateJavaScript("window.tfxBlur && window.tfxBlur();", completionHandler: nil)
                if let firstResponder = webView.window?.firstResponder as? NSView,
                   firstResponder == webView || firstResponder.isDescendant(of: webView) {
                    webView.window?.makeFirstResponder(nil)
                }
            }
        }

        func handleDroppedFileURLs(_ urls: [URL]) {
            guard !urls.isEmpty else { return }
            setPathDropTarget(false)
            activate()
            isInputFocused.wrappedValue = true
            model.insertPaths(urls)
            focusTerminal()
        }

        func setPathDropTarget(_ isTargeted: Bool) {
            isPathDropTarget.wrappedValue = isTargeted
        }

        private func write(_ output: String) {
            guard isReady else {
                pendingOutput.append(output)
                return
            }
            evaluate("window.tfxWrite(\(Self.jsonString(output)));")
        }

        private func flushPendingOutput() {
            guard !pendingOutput.isEmpty else { return }
            let output = pendingOutput.joined()
            pendingOutput.removeAll()
            write(output)
        }

        private func resize(from body: Any) {
            guard let dictionary = body as? [String: Any],
                  let columns = dictionary["cols"] as? Int,
                  let rows = dictionary["rows"] as? Int
            else {
                return
            }
            model.resize(columns: columns, rows: rows)
        }

        private func evaluate(_ script: String) {
            DispatchQueue.main.async { [weak self] in
                self?.webView?.evaluateJavaScript(script, completionHandler: nil)
            }
        }

        private static func jsonString(_ value: String) -> String {
            guard let data = try? JSONSerialization.data(withJSONObject: [value]),
                  let json = String(data: data, encoding: .utf8),
                  json.count >= 2
            else {
                return "\"\""
            }
            return String(json.dropFirst().dropLast())
        }
    }
}

private final class TerminalDropWebView: WKWebView {
    var onFileDrop: (([URL]) -> Void)?
    var onFileDragStateChange: ((Bool) -> Void)?

    override init(frame: CGRect, configuration: WKWebViewConfiguration) {
        super.init(frame: frame, configuration: configuration)
        registerForDraggedTypes([.fileURL])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let operation = droppedFileURLs(from: sender).isEmpty ? NSDragOperation() : .copy
        onFileDragStateChange?(operation == .copy)
        return operation
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        let operation = droppedFileURLs(from: sender).isEmpty ? NSDragOperation() : .copy
        onFileDragStateChange?(operation == .copy)
        return operation
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        onFileDragStateChange?(false)
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        onFileDragStateChange?(false)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = droppedFileURLs(from: sender)
        guard !urls.isEmpty else {
            onFileDragStateChange?(false)
            return false
        }
        onFileDrop?(urls)
        onFileDragStateChange?(false)
        return true
    }

    private func droppedFileURLs(from sender: NSDraggingInfo) -> [URL] {
        let pasteboard = sender.draggingPasteboard
        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true
        ]
        return pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL] ?? []
    }
}

private struct XtermTheme {
    let background: String
    let foreground: String
    let cursor: String
    let selectionBackground: String
    let fontFamily: String
    let fontSize: Int

    init(theme: Theme, design: DesignTokens) {
        background = Self.hex(theme.fileListBackground)
        foreground = Self.hex(theme.fileForeground)
        cursor = Self.hex(theme.directoryForeground)
        selectionBackground = Self.hex(theme.fileListRowSelected)

        let font = design.fonts.nsFont(for: .previewCode)
        fontFamily = Self.cssFontFamily(for: design.fonts.monoFamily, resolvedFont: font)
        fontSize = max(8, Int(round(font.pointSize)))
    }

    var json: String {
        """
        {
          "background": \(jsonString(background)),
          "foreground": \(jsonString(foreground)),
          "cursor": \(jsonString(cursor)),
          "selectionBackground": \(jsonString(selectionBackground))
        }
        """
    }

    var optionsJSON: String {
        """
        {
          "fontFamily": \(jsonString(fontFamily)),
          "fontSize": \(fontSize),
          "theme": \(json)
        }
        """
    }

    private static func hex(_ color: Color) -> String {
        let nsColor = NSColor(color).usingColorSpace(.sRGB) ?? .textColor
        let red = Int(round(nsColor.redComponent * 255))
        let green = Int(round(nsColor.greenComponent * 255))
        let blue = Int(round(nsColor.blueComponent * 255))
        return String(format: "#%02X%02X%02X", red, green, blue)
    }

    nonisolated private static func cssFontFamily(for configuredFamily: String?, resolvedFont: NSFont) -> String {
        let fallback = "\"SF Mono\", Menlo, Monaco, \"Courier New\", monospace"
        guard let configuredFamily, !configuredFamily.isEmpty else {
            return fallback
        }

        let candidates = [
            configuredFamily,
            resolvedFont.familyName,
            resolvedFont.fontName
        ]
        let configuredStack = candidates
            .compactMap { $0 }
            .reduce(into: [String]()) { result, family in
                guard !result.contains(family) else { return }
                result.append(family)
            }
            .map(quoteFontFamily)
            .joined(separator: ", ")

        return "\(configuredStack), \(fallback)"
    }

    nonisolated private static func quoteFontFamily(_ family: String) -> String {
        "\"\(family.replacingOccurrences(of: "\"", with: "\\\""))\""
    }
}

private func jsonString(_ value: String) -> String {
    guard let data = try? JSONSerialization.data(withJSONObject: [value]),
          let json = String(data: data, encoding: .utf8),
          json.count >= 2
    else {
        return "\"\""
    }
    return String(json.dropFirst().dropLast())
}
#endif
