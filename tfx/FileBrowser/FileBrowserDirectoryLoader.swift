#if os(macOS)
import Foundation

enum FileBrowserDirectoryLoader {
    nonisolated static func load(
        directory: URL,
        chunkSize: Int,
        cancellation: DirectoryLoadCancellation,
        publishHeader: @escaping (Result<DirectoryHeader, Error>) -> Void,
        publishBatch: @escaping ([FileItem], Bool) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            let headerStart = PerformanceTrace.now()
            if let archiveLocation = ZipArchiveBrowser.location(for: directory) {
                do {
                    let entries = try ZipArchiveBrowser.entries(in: directory)
                    let urls = entries.map { ZipArchiveBrowser.virtualURL(archiveURL: archiveLocation.archiveURL, innerPath: $0.path) }
                    PerformanceTrace.log("zip-directory-header", startedAt: headerStart, detail: directory.path)
                    publishHeader(.success(DirectoryHeader(urls: urls, availableCapacityText: "-")))

                    let itemsStart = PerformanceTrace.now()
                    var pendingItems: [FileItem] = []
                    pendingItems.reserveCapacity(min(entries.count, chunkSize))

                    for entry in entries {
                        guard !cancellation.isCancelled else { return }

                        pendingItems.append(FileItem(zipEntry: entry, archiveURL: archiveLocation.archiveURL))

                        if pendingItems.count >= chunkSize {
                            let batch = pendingItems
                            pendingItems.removeAll(keepingCapacity: true)
                            publishBatch(batch, false)
                        }
                    }

                    publishBatch(pendingItems, true)
                    PerformanceTrace.log("zip-directory-items", startedAt: itemsStart, detail: "\(entries.count) items \(directory.path)")
                } catch {
                    publishHeader(.failure(error))
                }
                return
            }

            let result = FileBrowserDirectoryReader.loadHeader(for: directory)
            PerformanceTrace.log("directory-header", startedAt: headerStart, detail: directory.path)
            publishHeader(result)

            guard case let .success(header) = result else { return }

            let itemsStart = PerformanceTrace.now()
            var pendingItems: [FileItem] = []
            pendingItems.reserveCapacity(min(header.urls.count, chunkSize))

            for url in header.urls {
                guard !cancellation.isCancelled else { return }

                pendingItems.append(FileItem(url: url))

                if pendingItems.count >= chunkSize {
                    let batch = pendingItems
                    pendingItems.removeAll(keepingCapacity: true)
                    publishBatch(batch, false)
                }
            }

            publishBatch(pendingItems, true)
            PerformanceTrace.log("directory-items", startedAt: itemsStart, detail: "\(header.urls.count) items \(directory.path)")
        }
    }
}

#endif
