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
            notifyDirectoriesChanged(Array(result.affectedDirectories))
            completion?()
        } catch {
            show(error)
        }
    }
}

#endif
