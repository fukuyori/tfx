#if os(macOS)
import AppKit
import Foundation

enum FileBrowserExternalActions {
    static func isDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    static func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    static func chooseDirectory(startingAt directory: URL) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = directory
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func openTerminal(at directory: URL, onError: @escaping (Error) -> Void) {
        let terminalURL = URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app")
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true

        NSWorkspace.shared.open(
            [directory],
            withApplicationAt: terminalURL,
            configuration: configuration
        ) { _, error in
            if let error {
                DispatchQueue.main.async {
                    onError(error)
                }
            }
        }
    }

    static func revealInFinder(_ urls: [URL]) {
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }

    static func copyPath(_ url: URL) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.path(percentEncoded: false), forType: .string)
    }

    static func writeFileURLsToPasteboard(_ urls: [URL]) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects(urls as [NSURL])
    }
}

enum FileBrowserClipboardActions {
    static func clipboard(for items: [FileItem], operation: FileClipboard.Operation) -> FileClipboard? {
        let urls = items.map(\.url)
        guard !urls.isEmpty else { return nil }

        FileBrowserExternalActions.writeFileURLsToPasteboard(urls)
        return FileClipboard(urls: urls, operation: operation)
    }
}

#endif
