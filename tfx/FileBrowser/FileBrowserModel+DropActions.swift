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
        // Collect every dropped URL into a single batch, then run
        // the copy / move through the chunk-copying progress
        // runner. The pre-batch approach gives one progress card
        // covering the whole drop instead of one per item, and
        // lets Cancel actually stop the operation between files.
        let fileProviders = providers.filter {
            $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
        }
        guard !fileProviders.isEmpty else { return false }

        let total = fileProviders.count
        var collected: [URL] = []
        var completed = 0

        for provider in fileProviders {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { [weak self] item, error in
                DispatchQueue.main.async {
                    guard let self else { return }
                    completed += 1
                    if let error {
                        self.show(error)
                    } else if let url = FileBrowserDropItemDecoder.url(from: item) {
                        collected.append(url)
                    }
                    if completed == total, !collected.isEmpty {
                        self.runBatchDrop(
                            collected,
                            to: targetDirectory,
                            operation: operation,
                            completion: completion
                        )
                    }
                }
            }
        }
        return true
    }

    /// Dispatches the batched drop through `runFileOperation`,
    /// then mirrors the bookkeeping the old per-item path used
    /// to do (item-list update, folder-children refresh,
    /// directories-changed notification with the source-side
    /// removals).
    private func runBatchDrop(
        _ sources: [URL],
        to targetDirectory: URL,
        operation: FileClipboard.Operation,
        completion: (() -> Void)?
    ) {
        let kind: FileOperationProgressViewModel.Kind = (operation == .copy) ? .copying : .moving
        runFileOperation(
            kind: kind,
            items: sources,
            destination: targetDirectory
        ) { [weak self] added, removed in
            guard let self else { return }
            let sourceDirectories = Set(sources.map { $0.deletingLastPathComponent().standardizedFileURL })
            for dir in sourceDirectories {
                self.refreshFolderChildren(dir)
            }
            self.refreshFolderChildren(targetDirectory)
            self.updateCurrentDirectoryItems(
                adding: added,
                removing: removed,
                selecting: added
            )
            let affectedDirectories = sourceDirectories.union([targetDirectory.standardizedFileURL])
            self.notifyDirectoriesChanged(
                Array(affectedDirectories),
                removedURLs: removed
            )
            completion?()
        }
    }

    /// Launch / spawn `executableURL`, passing every dropped
    /// file URL as an argument. `.app` bundles go through
    /// `NSWorkspace` (they get the dropped files as documents
    /// via the standard "open with" channel). Regular
    /// executables run via `Process` with `arguments` set to
    /// each dropped URL's path. Returns true when the providers
    /// included file URLs; the actual execution is asynchronous.
    @discardableResult
    func executeDroppedFiles(
        _ providers: [NSItemProvider],
        on executableURL: URL,
        isApplicationBundle: Bool
    ) -> Bool {
        let fileProviders = providers.filter {
            $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
        }
        guard !fileProviders.isEmpty else { return false }

        // Collect every dropped URL into a single batch and then
        // run the target once with all of them as arguments —
        // matching `program file1 file2 file3` semantics rather
        // than spawning N independent runs. `NSItemProvider`'s
        // loader is async so we wait for all per-provider
        // callbacks to land before dispatching the single run.
        let total = fileProviders.count
        var collected: [URL] = []
        var completed = 0

        for provider in fileProviders {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { [weak self] item, error in
                DispatchQueue.main.async {
                    guard let self else { return }
                    completed += 1
                    if let error {
                        self.show(error)
                    } else if let url = FileBrowserDropItemDecoder.url(from: item) {
                        collected.append(url)
                    }
                    if completed == total {
                        guard !collected.isEmpty else { return }
                        self.runExecutable(
                            executableURL,
                            isApplicationBundle: isApplicationBundle,
                            with: collected
                        )
                    }
                }
            }
        }
        return true
    }

    private func runExecutable(_ executableURL: URL, isApplicationBundle: Bool, with arguments: [URL]) {
        if isApplicationBundle {
            FileBrowserExternalActions.open(arguments, withApplicationAt: executableURL) { [weak self] error in
                self?.show(error)
            }
            return
        }

        // Prefer the built-in terminal when available: TUI
        // programs (`tbla`, `vim`, `htop`, …) need a real PTY,
        // and we already own one. The handler is responsible
        // for un-hiding the terminal pane and writing the
        // command line + return into the live session.
        if let handler = runInTerminalHandler {
            handler(shellCommand(for: executableURL, arguments: arguments))
            return
        }

        // Fallback for windows that have not registered a
        // terminal handler: spawn the executable detached from
        // any PTY. Works for GUI helpers but produces unusable
        // output for TUI programs (escape codes go to stdout
        // and nothing reads them). We keep this branch so the
        // feature is still useful in setups that disable the
        // built-in terminal entirely.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let process = Process()
            process.executableURL = executableURL
            process.arguments = arguments.map(\.path)
            do {
                try process.run()
            } catch {
                DispatchQueue.main.async { [weak self] in
                    self?.show(error)
                }
            }
        }
    }

    /// Quote a path for safe interpolation into a single shell
    /// command line. Wraps in single quotes and escapes any
    /// embedded single quotes via the standard `'\''` sequence.
    private func shellQuote(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private func shellCommand(for executableURL: URL, arguments: [URL]) -> String {
        let parts = [executableURL.path] + arguments.map(\.path)
        return parts.map(shellQuote).joined(separator: " ")
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
