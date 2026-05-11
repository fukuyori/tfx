#if os(macOS)
import Foundation

enum PrivacyProtectedDirectories {
    nonisolated static let directories: [URL] = {
        let home = URL(fileURLWithPath: NSHomeDirectory()).standardizedFileURL
        return [
            home.appendingPathComponent("Desktop", isDirectory: true).standardizedFileURL,
            home.appendingPathComponent("Documents", isDirectory: true).standardizedFileURL,
            home.appendingPathComponent("Downloads", isDirectory: true).standardizedFileURL
        ]
    }()

    nonisolated static func isProtectedDirectory(_ url: URL) -> Bool {
        directories.contains(url.standardizedFileURL)
    }

    nonisolated static func enclosingProtectedDirectory(for url: URL) -> URL? {
        let target = url.standardizedFileURL
        for directory in directories {
            if target == directory {
                return directory
            }
            if target.path.hasPrefix(directory.path + "/") {
                return directory
            }
        }
        return nil
    }
}
#endif
