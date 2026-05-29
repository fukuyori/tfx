#if os(macOS)
import Foundation

enum AppLaunchArguments {
    struct Parsed: Equatable {
        var initialDirectory: URL?
        var startupLayout: StartupLayoutMode?
        var previewVisible: Bool?
        var terminalVisible: Bool?
        var shouldPrintHelp = false
        var shouldPrintVersion = false
    }

    static func parse(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        currentDirectoryPath: String = FileManager.default.currentDirectoryPath
    ) -> Parsed {
        var parsed = Parsed()

        for argument in arguments.dropFirst() {
            switch argument {
            case "--help", "-h":
                parsed.shouldPrintHelp = true
            case "--version", "-v":
                parsed.shouldPrintVersion = true
            case "--single", "-1":
                parsed.startupLayout = .single
            case "--split", "-2":
                parsed.startupLayout = .split
            case "--restore", "-r":
                parsed.startupLayout = .restore
            case "--preview", "-p":
                parsed.previewVisible = true
            case "--no-preview", "-P":
                parsed.previewVisible = false
            case "--terminal", "-t":
                parsed.terminalVisible = true
            case "--no-terminal", "-T":
                parsed.terminalVisible = false
            default:
                if parsed.initialDirectory == nil {
                    parsed.initialDirectory = directoryURL(for: argument, currentDirectoryPath: currentDirectoryPath)
                }
            }
        }

        return parsed
    }

    static func initialDirectory(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        currentDirectoryPath: String = FileManager.default.currentDirectoryPath
    ) -> URL? {
        parse(arguments: arguments, currentDirectoryPath: currentDirectoryPath).initialDirectory
    }

    static func versionString(bundle: Bundle = .main) -> String {
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        switch (version, build) {
        case let (version?, build?) where !version.isEmpty && !build.isEmpty:
            return "tfx \(version) (\(build))"
        case let (version?, _) where !version.isEmpty:
            return "tfx \(version)"
        default:
            return "tfx"
        }
    }

    static let helpText = """
    Usage: tfx [options] [folder]

    Options:
      -h, --help          Show this help and exit.
      -v, --version       Show the app version and exit.
      -1, --single        Start with a single file pane.
      -2, --split         Start with split file panes.
      -r, --restore       Restore the previous pane layout and tabs.
      -p, --preview       Show the preview pane.
      -P, --no-preview    Hide the preview pane.
      -t, --terminal      Show the built-in terminal pane.
      -T, --no-terminal   Hide the built-in terminal pane.

    folder may be an absolute path, a relative path, or a path beginning with ~.
    """

    private static func resolvedPath(for rawPath: String, currentDirectoryPath: String) -> String {
        let expandedPath = (rawPath as NSString).expandingTildeInPath
        if expandedPath.hasPrefix("/") {
            return expandedPath
        }

        return URL(fileURLWithPath: currentDirectoryPath, isDirectory: true)
            .appendingPathComponent(expandedPath)
            .path
    }

    private static func directoryURL(for rawPath: String, currentDirectoryPath: String) -> URL? {
        guard !rawPath.isEmpty, !rawPath.hasPrefix("-") else {
            return nil
        }

        let path = resolvedPath(for: rawPath, currentDirectoryPath: currentDirectoryPath)
        let url = URL(fileURLWithPath: path).standardizedFileURL
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return nil
        }

        return url
    }
}
#endif
