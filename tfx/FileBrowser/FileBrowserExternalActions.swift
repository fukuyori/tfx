#if os(macOS)
import AppKit
import Foundation

enum FileBrowserExternalActions {
    static let tfxClipboardOperationType = NSPasteboard.PasteboardType("org.spumoni.tfx.file-operation")

    nonisolated static func isDirectory(_ url: URL) -> Bool {
        if let aliasTarget = resolvedAliasURL(for: url) {
            return isDirectory(aliasTarget)
        }

        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    nonisolated static func directoryURLForNavigation(_ url: URL) -> URL? {
        let fileURL = resolvedAliasURL(for: url) ?? (url.isFileURL ? url : URL(fileURLWithPath: url.path))
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return nil
        }

        let values = try? fileURL.resourceValues(forKeys: [.isSymbolicLinkKey])
        if values?.isSymbolicLink == true {
            return fileURL.resolvingSymlinksInPath().standardizedFileURL
        }

        return fileURL.standardizedFileURL
    }

    nonisolated static func resolvedAliasURL(for url: URL) -> URL? {
        let fileURL = url.isFileURL ? url : URL(fileURLWithPath: url.path)
        let values = try? fileURL.resourceValues(forKeys: [.isAliasFileKey])
        guard values?.isAliasFile == true else { return nil }
        return try? URL(resolvingAliasFileAt: fileURL, options: [])
    }

    nonisolated static func resolvedOpenURL(for url: URL) -> URL {
        resolvedAliasURL(for: url) ?? url
    }

    static func open(_ url: URL) {
        NSWorkspace.shared.open(resolvedOpenURL(for: url))
    }

    static func openApplication(_ url: URL, onError: @escaping (Error) -> Void) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true

        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, error in
            if let error {
                DispatchQueue.main.async {
                    onError(error)
                }
            }
        }
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

    static func writeFileURLsToPasteboard(_ urls: [URL], operation: FileClipboard.Operation) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects(urls as [NSURL])
        NSPasteboard.general.setString(operation == .move ? "move" : "copy", forType: tfxClipboardOperationType)
    }

    static func fileClipboardFromPasteboard(defaultOperation: FileClipboard.Operation = .copy) -> FileClipboard? {
        let pasteboard = NSPasteboard.general
        let classes = [NSURL.self]
        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true
        ]

        guard let objects = pasteboard.readObjects(forClasses: classes, options: options) as? [URL],
              !objects.isEmpty else {
            return nil
        }

        let operationString = pasteboard.string(forType: tfxClipboardOperationType)
        let operation: FileClipboard.Operation = operationString == "move" ? .move : defaultOperation
        return FileClipboard(urls: objects, operation: operation)
    }
}

enum FileBrowserClipboardActions {
    static func clipboard(for items: [FileItem], operation: FileClipboard.Operation) -> FileClipboard? {
        let urls = items.map(\.url)
        guard !urls.isEmpty else { return nil }

        FileBrowserExternalActions.writeFileURLsToPasteboard(urls, operation: operation)
        return FileClipboard(urls: urls, operation: operation)
    }
}

#endif
