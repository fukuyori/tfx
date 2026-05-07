#if os(macOS)
import Foundation

struct SubfolderSearchProgress {
    let depth: Int
    let processedFolderCount: Int
    let skippedFolderCount: Int
    let hitCount: Int
}

enum FileBrowserSubfolderSearch {
    nonisolated static func search(
        rootDirectory: URL,
        query: String,
        showsHiddenFiles: Bool,
        batchSize: Int,
        cancellation: SubfolderSearchCancellation,
        publishProgress: @escaping (SubfolderSearchProgress) -> Void,
        publishBatch: @escaping ([FileItem]) -> Void,
        publishCompletion: @escaping (Bool) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            let searchStart = PerformanceTrace.now()
            let fileManager = FileManager.default
            let resourceKeys: [URLResourceKey] = [
                .isDirectoryKey,
                .isHiddenKey,
                .fileSizeKey,
                .contentModificationDateKey,
                .creationDateKey
            ]
            var currentDepthDirectories = [rootDirectory.standardizedFileURL]
            var nextDepthDirectories: [URL] = []
            var pendingItems: [FileItem] = []
            pendingItems.reserveCapacity(batchSize)
            var depth = 0
            var processedFolderCount = 0
            var skippedFolderCount = 0
            var hitCount = 0
            var lastBatchPublishTime = CFAbsoluteTimeGetCurrent()
            var lastProgressPublishTime = lastBatchPublishTime

            while !currentDepthDirectories.isEmpty {
                guard !cancellation.isCancelled else {
                    publishCompletion(false)
                    return
                }

                for directory in currentDepthDirectories {
                    guard !cancellation.isCancelled else {
                        publishCompletion(false)
                        return
                    }

                    guard fileManager.isReadableFile(atPath: directory.path) else {
                        skippedFolderCount += 1
                        processedFolderCount += 1
                        publishProgress(SubfolderSearchProgress(
                            depth: depth,
                            processedFolderCount: processedFolderCount,
                            skippedFolderCount: skippedFolderCount,
                            hitCount: hitCount
                        ))
                        continue
                    }

                    do {
                        let urls = try fileManager.contentsOfDirectory(
                            at: directory,
                            includingPropertiesForKeys: resourceKeys,
                            options: [.skipsPackageDescendants]
                        )

                        for url in urls {
                            if cancellation.isCancelled {
                                publishCompletion(false)
                                return
                            }

                            let item = FileItem(url: url)
                            if item.isDirectory, showsHiddenFiles || !item.isHidden {
                                nextDepthDirectories.append(url.standardizedFileURL)
                            }

                            guard showsHiddenFiles || !item.isHidden else { continue }
                            guard item.searchName.contains(query) else { continue }

                            pendingItems.append(item)
                            hitCount += 1

                            let now = CFAbsoluteTimeGetCurrent()
                            if pendingItems.count >= batchSize || now - lastBatchPublishTime >= 0.15 {
                                publishBatch(pendingItems)
                                pendingItems.removeAll(keepingCapacity: true)
                                lastBatchPublishTime = now
                            }
                        }
                    } catch {
                        skippedFolderCount += 1
                    }

                    guard !cancellation.isCancelled else {
                        publishCompletion(false)
                        return
                    }

                    let now = CFAbsoluteTimeGetCurrent()
                    if !pendingItems.isEmpty, now - lastBatchPublishTime >= 0.15 {
                        publishBatch(pendingItems)
                        pendingItems.removeAll(keepingCapacity: true)
                        lastBatchPublishTime = now
                    }

                    processedFolderCount += 1
                    if now - lastProgressPublishTime >= 0.12 {
                        publishProgress(SubfolderSearchProgress(
                            depth: depth,
                            processedFolderCount: processedFolderCount,
                            skippedFolderCount: skippedFolderCount,
                            hitCount: hitCount
                        ))
                        lastProgressPublishTime = now
                    }
                }

                if !pendingItems.isEmpty {
                    publishBatch(pendingItems)
                    pendingItems.removeAll(keepingCapacity: true)
                    lastBatchPublishTime = CFAbsoluteTimeGetCurrent()
                }
                publishProgress(SubfolderSearchProgress(
                    depth: depth,
                    processedFolderCount: processedFolderCount,
                    skippedFolderCount: skippedFolderCount,
                    hitCount: hitCount
                ))
                lastProgressPublishTime = CFAbsoluteTimeGetCurrent()

                currentDepthDirectories = nextDepthDirectories
                nextDepthDirectories.removeAll(keepingCapacity: true)
                depth += 1
            }

            if !pendingItems.isEmpty {
                publishBatch(pendingItems)
            }

            PerformanceTrace.log("subfolder-search", startedAt: searchStart, detail: "\(hitCount) hits \(processedFolderCount) folders \(rootDirectory.path)")
            publishCompletion(true)
        }
    }
}

#endif
