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
            // Only the keys the walk itself needs. Everything a
            // matched row's `FileItem` requires is fetched lazily
            // in its init — and matches are rare relative to the
            // number of files visited, so prefetching the full
            // metadata set for every file just slowed the walk.
            let resourceKeys: [URLResourceKey] = [
                .isDirectoryKey,
                .isHiddenKey,
                .isSymbolicLinkKey
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

            // Hard depth bound as a second line of defense
            // against traversal loops the symlink check can't
            // see (e.g. mount-point oddities). Real directory
            // trees stay well under this.
            let maxSearchDepth = 128
            while !currentDepthDirectories.isEmpty, depth < maxSearchDepth {
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

                            // Classify from the prefetched resource
                            // values — building a full `FileItem`
                            // (size/date text formatting, cache
                            // lookups, localized names) for every
                            // visited file made the walk several
                            // times slower than the disk I/O.
                            let values = try? url.resourceValues(
                                forKeys: [.isDirectoryKey, .isHiddenKey, .isSymbolicLinkKey]
                            )
                            let isHidden = values?.isHidden == true
                                || url.lastPathComponent.hasPrefix(".")
                            guard showsHiddenFiles || !isHidden else { continue }

                            let isDirectory = values?.isDirectory == true
                            // Never descend through symlinks: a
                            // `ln -s .. loop` (or the circular
                            // links under `/`) would otherwise
                            // make this BFS grow the queue
                            // exponentially until the app runs
                            // out of memory. Symlinks still match
                            // as search *results*; Finder skips
                            // descending them too.
                            if isDirectory, values?.isSymbolicLink != true {
                                nextDepthDirectories.append(url.standardizedFileURL)
                            }

                            // Cheap name gate first; the full
                            // `FileItem` is built only for hits.
                            // Directories match on their localized
                            // display name (Documents → 書類), the
                            // same name `FileItem` would surface.
                            let matchName = isDirectory
                                ? FolderDisplayNameCache.shared.displayName(for: url).localizedLowercase
                                : url.lastPathComponent.localizedLowercase
                            guard matchName.contains(query) else { continue }

                            pendingItems.append(FileItem(url: url))
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
