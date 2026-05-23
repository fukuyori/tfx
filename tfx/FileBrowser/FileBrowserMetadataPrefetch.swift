#if os(macOS)
import Foundation

enum FileBrowserMetadataPrefetch {
    static func scheduledWorkItem(
        items: [FileItem],
        columns: [FileListColumn],
        setCancellation: @escaping (MetadataPrefetchCancellation) -> Void
    ) -> DispatchWorkItem? {
        let needsIcon = columns.contains(.icon)
        let needsKind = columns.contains(.kind)
        let needsPermissions = columns.contains(.permissions)
        guard needsIcon || needsKind || needsPermissions, !items.isEmpty else {
            return nil
        }

        return DispatchWorkItem {
            let cancellation = MetadataPrefetchCancellation()
            setCancellation(cancellation)

            let prefetchLimit = 1_000
            let itemsToPrefetch = items.count > prefetchLimit
                ? Array(items.prefix(prefetchLimit))
                : items

            DispatchQueue.global(qos: .utility).async {
                let prefetchStart = PerformanceTrace.now()
                guard !cancellation.isCancelled else { return }

                if needsIcon {
                    // Warm the icon cache so `FileIcon.body` does not have
                    // to call `NSWorkspace.shared.icon(forFile:)` on the
                    // main thread during the first paint.
                    FileIconCache.shared.prefetch(for: itemsToPrefetch, cancellation: cancellation)
                }

                guard !cancellation.isCancelled else { return }

                if needsKind {
                    FileKindCache.shared.prefetch(for: itemsToPrefetch, cancellation: cancellation)
                }

                guard !cancellation.isCancelled else { return }

                if needsPermissions {
                    FilePermissionCache.shared.prefetch(for: itemsToPrefetch.map(\.url), cancellation: cancellation)
                }

                PerformanceTrace.log("metadata-prefetch", startedAt: prefetchStart, detail: "\(itemsToPrefetch.count) items")
            }
        }
    }
}

#endif
