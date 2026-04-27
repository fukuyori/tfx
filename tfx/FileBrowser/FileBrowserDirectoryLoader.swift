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
