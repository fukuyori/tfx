#if os(macOS)
import Foundation

extension FileBrowserFolderSupport {
    static func defaultTreeRoots() -> [URL] {
        [URL(fileURLWithPath: "/").standardizedFileURL]
    }

    static func displayName(for url: URL) -> String {
        if url.path == "/" {
            return "/"
        }

        return FileManager.default.displayName(atPath: url.path)
    }

    static func visibleFolders(
        roots: [URL],
        isExpanded: (URL) -> Bool,
        children: (URL) -> [URL]
    ) -> [URL] {
        var folders: [URL] = []
        var seen = Set<URL>()

        for root in roots {
            appendVisibleFolder(root, to: &folders, seen: &seen, isExpanded: isExpanded, children: children)
        }

        return folders
    }

    static func ancestors(of url: URL) -> [URL] {
        var ancestors: [URL] = []
        var ancestor = url.deletingLastPathComponent()
        var seen = Set<URL>()

        while ancestor != url, seen.insert(ancestor.standardizedFileURL).inserted {
            ancestors.append(ancestor)

            let parent = ancestor.deletingLastPathComponent()
            if parent == ancestor {
                break
            }
            ancestor = parent
        }

        return ancestors
    }

    private static func appendVisibleFolder(
        _ url: URL,
        to folders: inout [URL],
        seen: inout Set<URL>,
        isExpanded: (URL) -> Bool,
        children: (URL) -> [URL]
    ) {
        let key = url.standardizedFileURL
        guard seen.insert(key).inserted else { return }

        folders.append(key)

        if isExpanded(key) {
            for child in children(key) {
                appendVisibleFolder(child, to: &folders, seen: &seen, isExpanded: isExpanded, children: children)
            }
        }
    }
}
#endif
