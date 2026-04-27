#if os(macOS)
import Foundation

enum FileBrowserDirectoryReader {
    nonisolated static func loadHeader(for directory: URL) -> Result<DirectoryHeader, Error> {
        do {
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
        let values = try? directory.resourceValues(forKeys: [.volumeAvailableCapacityKey])

        if let availableCapacity = values?.volumeAvailableCapacity {
            return FileDisplayTextCache.shared.sizeText(byteCount: Int64(availableCapacity))
        } else {
            return "-"
        }
    }
}

#endif
