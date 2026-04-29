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

            let urls = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .creationDateKey, .isHiddenKey],
                options: [.skipsPackageDescendants]
            )
            let values = try? directory.resourceValues(forKeys: [.volumeAvailableCapacityKey])
            let availableCapacityText: String
            if let availableCapacity = values?.volumeAvailableCapacity {
                availableCapacityText = FileDisplayTextCache.shared.sizeText(byteCount: Int64(availableCapacity))
            } else {
                availableCapacityText = "-"
            }
            return .success(DirectoryHeader(urls: urls, availableCapacityText: availableCapacityText))
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
