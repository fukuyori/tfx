#if os(macOS)
import AppKit
import Foundation
import UniformTypeIdentifiers

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
        open(url) { _ in }
    }

    static func open(_ url: URL, onError: @escaping (Error) -> Void) {
        let resolved = resolvedOpenURL(for: url)
        do {
            let configuration = try AppLaunchConfigurationLoader.load()
            if let appReference = configuration.application(forFile: resolved) {
                try open([resolved], withApplication: appReference, onError: onError)
                return
            }
        } catch {
            DispatchQueue.main.async {
                onError(error)
            }
            return
        }

        NSWorkspace.shared.open(resolved)
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

    static func applicationsToOpen(_ url: URL) -> [URL] {
        NSWorkspace.shared.urlsForApplications(toOpen: resolvedOpenURL(for: url))
    }

    static func defaultApplicationToOpen(_ url: URL) -> URL? {
        NSWorkspace.shared.urlForApplication(toOpen: resolvedOpenURL(for: url))
    }

    static func applicationDisplayName(_ appURL: URL) -> String {
        let name = FileManager.default.displayName(atPath: appURL.path)
        if !name.isEmpty {
            // displayName usually drops the ".app" suffix already, but be defensive.
            if name.hasSuffix(".app") {
                return String(name.dropLast(4))
            }
            return name
        }
        return appURL.deletingPathExtension().lastPathComponent
    }

    static func applicationIcon(_ appURL: URL) -> NSImage {
        NSWorkspace.shared.icon(forFile: appURL.path)
    }

    static func open(_ urls: [URL], withApplicationAt appURL: URL, onError: @escaping (Error) -> Void) {
        let resolved = urls.map { resolvedOpenURL(for: $0) }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true

        NSWorkspace.shared.open(
            resolved,
            withApplicationAt: appURL,
            configuration: configuration
        ) { _, error in
            if let error {
                DispatchQueue.main.async {
                    onError(error)
                }
            }
        }
    }

    static func open(_ urls: [URL], withApplication appReference: ApplicationReference, onError: @escaping (Error) -> Void) throws {
        guard let appURL = appReference.resolvedURL() else {
            throw AppLaunchConfigurationError.applicationUnavailable(String(describing: appReference))
        }

        open(urls, withApplicationAt: appURL, onError: onError)
    }

    static func chooseApplication() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        return panel.runModal() == .OK ? panel.url : nil
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
        let terminalURL: URL
        do {
            let configuration = try AppLaunchConfigurationLoader.load()
            if let configuredTerminal = configuration.terminalApplication {
                guard let resolvedURL = configuredTerminal.resolvedURL() else {
                    throw AppLaunchConfigurationError.applicationUnavailable(String(describing: configuredTerminal))
                }
                terminalURL = resolvedURL
            } else {
                terminalURL = URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app")
            }
        } catch {
            DispatchQueue.main.async {
                onError(error)
            }
            return
        }

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
