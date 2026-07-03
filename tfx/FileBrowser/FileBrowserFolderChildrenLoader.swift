#if os(macOS)
import Foundation

extension FileBrowserFolderSupport {
    nonisolated static func loadChildren(for url: URL, showsHiddenFiles: Bool) -> [URL] {
        let loadStart = PerformanceTrace.now()
        do {
            let options: FileManager.DirectoryEnumerationOptions = showsHiddenFiles ? [.skipsPackageDescendants] : [.skipsHiddenFiles, .skipsPackageDescendants]
            let children = try FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey, .isAliasFileKey, .isHiddenKey],
                options: options
            )

            var childFolders: [(url: URL, sortName: String)] = []
            childFolders.reserveCapacity(children.count)

            for child in children {
                let values = try? child.resourceValues(forKeys: [.isDirectoryKey, .isAliasFileKey])
                // Only aliases need the `directoryURLForNavigation`
                // rescue (it resolves the alias and stats the
                // target). Running it for every plain file adds one
                // wasted stat per child — thousands of extra
                // syscalls per expansion in large folders, painful
                // on network volumes.
                let isDirectory = values?.isDirectory == true
                    || (values?.isAliasFile == true
                        && FileBrowserExternalActions.directoryURLForNavigation(child) != nil)
                guard isDirectory else {
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
