#if os(macOS)
import Foundation

extension FileBrowserFolderSupport {
    nonisolated static func loadChildren(for url: URL) -> [URL] {
        let loadStart = PerformanceTrace.now()
        do {
            let children = try FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            )

            var childFolders: [(url: URL, sortName: String)] = []
            childFolders.reserveCapacity(children.count)

            for child in children {
                guard (try? child.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else {
                    continue
                }

                childFolders.append((
                    url: child,
                    sortName: FolderDisplayNameCache.shared.displayName(for: child).localizedLowercase
                ))
            }

            let result = childFolders
                .sorted {
                    $0.sortName < $1.sortName
                }
                .map(\.url)
            PerformanceTrace.log("folder-children", startedAt: loadStart, detail: "\(result.count) folders \(url.path)")
            return result
        } catch {
            PerformanceTrace.log("folder-children", startedAt: loadStart, detail: "failed \(url.path)")
            return []
        }
    }
}
#endif
