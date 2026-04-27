#if os(macOS)
import Foundation

enum AppLaunchArguments {
    static func initialDirectory(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        currentDirectoryPath: String = FileManager.default.currentDirectoryPath
    ) -> URL? {
        arguments.dropFirst()
            .lazy
            .compactMap { directoryURL(for: $0, currentDirectoryPath: currentDirectoryPath) }
            .first
    }

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
