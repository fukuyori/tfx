#if os(macOS)
import Foundation
import UniformTypeIdentifiers

extension FileBrowserModel {
    func moveDroppedFiles(
        _ providers: [NSItemProvider],
        to targetDirectory: URL,
        completion: (() -> Void)? = nil
    ) -> Bool {
        FileBrowserDropProviderLoader.loadFileURLs(
            from: providers,
            onError: { [weak self] error in self?.show(error) },
            onURL: { [weak self] sourceURL in
                self?.move(sourceURL, to: targetDirectory, completion: completion)
            }
        )
    }

    func move(_ sourceURL: URL, to targetDirectory: URL, completion: (() -> Void)? = nil) {
        do {
            guard let result = try FileBrowserFileOperations.move(sourceURL, to: targetDirectory) else { return }
            refreshFolderChildren(sourceURL.deletingLastPathComponent())
            refreshFolderChildren(targetDirectory)
            updateCurrentDirectoryItems(
                adding: [result.destinationURL],
                removing: [sourceURL],
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
