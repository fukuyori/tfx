#if os(macOS)
import Foundation

extension FileBrowserModel {
    func open(_ item: FileItem) {
        if item.isDirectory {
            navigate(to: item.url)
        } else if ZipArchiveBrowser.isZipArchive(item.url) {
            navigate(to: item.url)
        } else if ZipArchiveBrowser.canCopyFromArchive(item.url) {
            do {
                FileBrowserExternalActions.open(try ZipArchiveBrowser.materializedURL(for: item.url))
            } catch {
                show(error)
            }
        } else {
            FileBrowserExternalActions.open(item.url)
        }
    }

    func openFromContextMenu(_ item: FileItem) {
        if item.isApplicationBundle {
            FileBrowserExternalActions.openApplication(item.url) { [weak self] error in
                self?.show(error)
            }
        } else {
            open(item)
        }
    }

    func pickFolder() {
        if let url = FileBrowserExternalActions.chooseDirectory(startingAt: currentDirectory) {
            navigate(to: url)
        }
    }

    func openTerminal() {
        openTerminal(at: currentDirectory)
    }

    func openTerminal(at directory: URL) {
        FileBrowserExternalActions.openTerminal(at: directory) { [weak self] error in
            self?.show(error)
        }
    }

    func revealSelectedItemsInFinder() {
        let urls = selectedItems.map(\.url)
        guard !urls.isEmpty else { return }
        FileBrowserExternalActions.revealInFinder(urls)
    }

    func revealInFinder(_ url: URL) {
        FileBrowserExternalActions.revealInFinder([url])
    }

    func copyPath(_ url: URL) {
        FileBrowserExternalActions.copyPath(url)
    }
}

#endif
