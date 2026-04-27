#if os(macOS)
import Foundation

extension FileBrowserModel {
    func prefetchVisibleMetadata(for columns: [FileListColumn]) {
        metadataPrefetchWorkItem?.cancel()
        metadataPrefetchCancellation?.cancel()
        metadataPrefetchWorkItem = nil
        metadataPrefetchCancellation = nil

        guard let workItem = FileBrowserMetadataPrefetch.scheduledWorkItem(
            items: items,
            columns: columns,
            setCancellation: { [weak self] cancellation in
                self?.metadataPrefetchCancellation = cancellation
            }
        ) else {
            return
        }

        metadataPrefetchWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: workItem)
    }
}

#endif
