#if os(macOS)
import Foundation

extension FileBrowserFolderSupport {
    static func movingPinnedFolder(_ sourceURL: URL, toInsertionIndex insertionIndex: Int, in pinnedFolders: [URL]) -> [URL]? {
        let source = sourceURL.standardizedFileURL
        guard let sourceIndex = pinnedFolders.firstIndex(where: { $0.standardizedFileURL == source }) else {
            return nil
        }

        var reorderedFolders = pinnedFolders
        let movedFolder = reorderedFolders.remove(at: sourceIndex)
        let adjustedInsertionIndex = sourceIndex < insertionIndex ? insertionIndex - 1 : insertionIndex
        let clampedInsertionIndex = min(max(adjustedInsertionIndex, 0), reorderedFolders.count)
        guard sourceIndex != clampedInsertionIndex else {
            return nil
        }

        reorderedFolders.insert(movedFolder, at: clampedInsertionIndex)
        return reorderedFolders
    }

    static func loadPinnedFolders(key: String) -> [URL] {
        let paths: [String]
        if let savedPaths = UserDefaults.standard.stringArray(forKey: key) {
            paths = savedPaths
        } else {
            paths = defaultPinnedFolders().map(\.path)
            UserDefaults.standard.set(paths, forKey: key)
        }
        var seen = Set<URL>()

        return paths
            .map { URL(fileURLWithPath: $0).standardizedFileURL }
            .filter { seen.insert($0).inserted }
    }

    static func savePinnedFolders(_ pinnedFolders: [URL], key: String) {
        UserDefaults.standard.set(pinnedFolders.map(\.path), forKey: key)
        NotificationCenter.default.post(name: .pinnedFoldersDidChange, object: nil)
    }

    private static func defaultPinnedFolders() -> [URL] {
        let home = URL(fileURLWithPath: NSHomeDirectory()).standardizedFileURL
        let candidates = [
            home,
            home.appendingPathComponent("Documents", isDirectory: true),
            home.appendingPathComponent("Downloads", isDirectory: true)
        ]

        return candidates
    }
}
#endif
