#if os(macOS)
import Foundation
import UniformTypeIdentifiers

extension FileBrowserModel {
    func moveDroppedFiles(
        _ providers: [NSItemProvider],
        to targetDirectory: URL,
        operation: FileClipboard.Operation,
        completion: (() -> Void)? = nil
    ) -> Bool {
        FileBrowserDropProviderLoader.loadFileURLs(
            from: providers,
            onError: { [weak self] error in self?.show(error) },
            onURL: { [weak self] sourceURL in
                self?.drop(sourceURL, to: targetDirectory, operation: operation, completion: completion)
            }
        )
    }

    func drop(_ sourceURL: URL, to targetDirectory: URL, operation: FileClipboard.Operation, completion: (() -> Void)? = nil) {
        do {
            guard let result = try FileBrowserFileOperations.drop(sourceURL, to: targetDirectory, operation: operation) else { return }
            refreshFolderChildren(sourceURL.deletingLastPathComponent())
            refreshFolderChildren(targetDirectory)
            updateCurrentDirectoryItems(
                adding: [result.destinationURL],
                removing: result.removedSourceURL.map { [$0] } ?? [],
                selecting: [result.destinationURL]
            )
            // Pass `removedSourceURL` along so another pane
            // pointed at the source directory can drop the row
            // immediately on receiving the notification instead
            // of waiting for its directory-watcher reload —
            // gives the cross-pane drag the instant
            // disappear-from-source feel.
            notifyDirectoriesChanged(
                Array(result.affectedDirectories),
                removedURLs: result.removedSourceURL.map { [$0] } ?? []
            )
            completion?()
        } catch {
            show(error)
        }
    }
}

#endif
