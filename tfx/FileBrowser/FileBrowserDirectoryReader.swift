#if os(macOS)
import Foundation

enum FileBrowserDirectoryReader {
    nonisolated static func loadHeader(for directory: URL) -> Result<DirectoryHeader, Error> {
        do {
            if let archiveLocation = ZipArchiveBrowser.location(for: directory) {
                let entries = try ZipArchiveBrowser.entries(in: directory)
                let urls = entries.map { ZipArchiveBrowser.virtualURL(archiveURL: archiveLocation.archiveURL, innerPath: $0.path) }
                return .success(DirectoryHeader(urls: urls, availableCapacityText: "-"))
            }

            // Pre-fetch every URL resource key that `FileItem.init` reads,
            // so the per-item `resourceValues(forKeys:)` call inside the
            // loader returns cached values with no extra syscall — critical
            // on network volumes where each missing key would be a round
            // trip. `.volumeAvailableCapacity` is intentionally not fetched
            // here; see the deferred fetch below.
            let urls = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [
                    .isDirectoryKey,
                    .fileSizeKey,
                    .contentModificationDateKey,
                    .creationDateKey,
                    .isHiddenKey,
                    .isAliasFileKey,
                    .tagNamesKey,
                ],
                options: [.skipsPackageDescendants]
            )
            // Volume capacity is fetched asynchronously through
            // `availableCapacityText(for:)` after the header lands, so a
            // slow `statvfs` on a network share does not block the initial
            // file-list paint.
            return .success(DirectoryHeader(urls: urls, availableCapacityText: "-"))
        } catch {
            return .failure(error)
        }
    }

    static func availableCapacityText(for directory: URL) -> String {
        if ZipArchiveBrowser.location(for: directory) != nil {
            return "-"
        }

        let values = try? directory.resourceValues(forKeys: [.volumeAvailableCapacityKey])

        if let availableCapacity = values?.volumeAvailableCapacity {
            return FileDisplayTextCache.shared.sizeText(byteCount: Int64(availableCapacity))
        } else {
            return "-"
        }
    }
}

#endif
