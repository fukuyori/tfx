#if os(macOS)
import AppKit
import CoreGraphics

extension TerminalFileManagerView {
    /// Horizontal scroll step in points per left / right arrow press.
    private static let horizontalScrollStep: CGFloat = 60

    func handleKeyEvent(_ event: NSEvent) -> Bool {
        if handleConfiguredShortcut(event) {
            return true
        }

        let unsupportedModifiers = event.modifierFlags.intersection([.command, .option, .control])
        guard unsupportedModifiers.isEmpty else { return false }
        let isShiftHeld = event.modifierFlags.contains(.shift)
        let isRangeSelection = isShiftHeld

        switch event.keyCode {
        case 48:
            // Tab cycles focus across the keyboard targets:
            //   folder tree → left file pane → right file pane (if split) → folder tree
            // Shift+Tab cycles in reverse.
            cycleKeyboardFocus(reverse: isShiftHeld)
            return true
        case 53:
            guard activeArea == .files else { return false }
            activeModel.clearSelection()
            return true
        case 126:
            activeArea == .folderTree ? activeModel.moveFolderTreeSelection(delta: -1) : activeModel.moveFileSelection(delta: -1, extendingRange: isRangeSelection)
            return true
        case 125:
            activeArea == .folderTree ? activeModel.moveFolderTreeSelection(delta: 1) : activeModel.moveFileSelection(delta: 1, extendingRange: isRangeSelection)
            return true
        case 123:
            // Left arrow scrolls the active file list horizontally. In the
            // folder tree the key is unused; return false so the system
            // can handle it (e.g., move insertion point in a future text
            // input scenario).
            guard activeArea == .files else { return false }
            activeModel.scrollHorizontally(by: -Self.horizontalScrollStep)
            return true
        case 124:
            guard activeArea == .files else { return false }
            activeModel.scrollHorizontally(by: Self.horizontalScrollStep)
            return true
        case 51:
            activeModel.goUp()
            return true
        case 36, 76:
            activeArea == .folderTree ? activeModel.activateFolderTreeSelection() : activeModel.activateFileSelection()
            return true
        default:
            return false
        }
    }

    private func handleConfiguredShortcut(_ event: NSEvent) -> Bool {
        if shortcutStore.info(.openItem).matches(event) {
            activeModel.activateFileSelection()
            return true
        }

        if shortcutStore.info(.newFolder).matches(event) {
            activeModel.createFolder()
            return true
        }

        if shortcutStore.info(.newFile).matches(event) {
            activeModel.createFile()
            return true
        }

        if shortcutStore.info(.rename).matches(event) {
            activeModel.renameSelectedItem()
            return true
        }

        if shortcutStore.info(.moveToTrash).matches(event) {
            activeModel.moveSelectedItemsToTrash()
            return true
        }

        if shortcutStore.info(.compressToZip).matches(event) {
            activeModel.compressSelectedItemsToZip()
            return true
        }

        if shortcutStore.info(.extractZip).matches(event) {
            if let item = activeModel.primarySelectedItem, ZipArchiveBrowser.isZipArchive(item.url) {
                activeModel.extractZipArchive(item)
                return true
            }
            return false
        }

        if shortcutStore.info(.copyItems).matches(event) {
            activeModel.copySelectedItems()
            return true
        }

        if shortcutStore.info(.cutItems).matches(event) {
            activeModel.cutSelectedItems()
            return true
        }

        if shortcutStore.info(.pasteItems).matches(event) {
            activeModel.pasteItems()
            return true
        }

        if shortcutStore.info(.movePasteItems).matches(event) {
            activeModel.pasteItemsMoving()
            return true
        }

        if shortcutStore.info(.selectAll).matches(event) {
            activeModel.selectAllVisibleItems()
            return true
        }

        if shortcutStore.info(.revealInFinder).matches(event) {
            activeModel.revealSelectedItemsInFinder()
            return true
        }

        if shortcutStore.info(.copyPath).matches(event) {
            if let item = activeModel.primarySelectedItem {
                activeModel.copyPath(item.url)
            } else {
                activeModel.copyPath(activeModel.currentDirectory)
            }
            return true
        }

        if shortcutStore.info(.reload).matches(event) {
            model.reload()
            return true
        }

        if shortcutStore.info(.openTerminal).matches(event) {
            model.openTerminal()
            return true
        }

        if shortcutStore.info(.togglePreview).matches(event) {
            isPreviewVisible.toggle()
            return true
        }

        if shortcutStore.info(.toggleSplit).matches(event) {
            setSplitViewVisible(!isSplitViewVisible)
            return true
        }

        // Keep this path even though the View menu also has a binding:
        // the menu can miss dynamically configured shortcuts, especially
        // non-command combinations such as Control+T.
        if shortcutStore.info(.swapPanes).matches(event) {
            swapPanes()
            return true
        }

        if shortcutStore.info(.focusSearch).matches(event) {
            isSearchFocused = true
            return true
        }

        if shortcutStore.info(.toggleHidden).matches(event) {
            model.showHiddenFiles.toggle()
            return true
        }

        if shortcutStore.info(.goBack).matches(event) {
            model.goBack()
            return true
        }

        if shortcutStore.info(.goForward).matches(event) {
            model.goForward()
            return true
        }

        if shortcutStore.info(.goUp).matches(event) {
            model.goUp()
            return true
        }

        return false
    }

    /// Cycle keyboard focus across the visible targets.
    ///
    /// Forward order: folder tree → left file pane → right file pane (when
    /// split is on) → folder tree. Reverse runs the same cycle backwards.
    private func cycleKeyboardFocus(reverse: Bool) {
        let stops = focusStops()
        guard !stops.isEmpty else { return }

        let currentIndex = stops.firstIndex(of: currentFocusStop()) ?? 0
        let nextIndex: Int
        if reverse {
            nextIndex = (currentIndex - 1 + stops.count) % stops.count
        } else {
            nextIndex = (currentIndex + 1) % stops.count
        }
        applyFocusStop(stops[nextIndex])
    }

    private func focusStops() -> [FocusStop] {
        isSplitViewVisible ? [.folderTree, .fileLeft, .fileRight] : [.folderTree, .fileLeft]
    }

    private func currentFocusStop() -> FocusStop {
        if activeArea == .folderTree {
            return .folderTree
        }
        return activePane == .left ? .fileLeft : .fileRight
    }

    private func applyFocusStop(_ stop: FocusStop) {
        switch stop {
        case .folderTree:
            activeArea = .folderTree
            activeModel.ensureFolderTreeSelection()
        case .fileLeft:
            activePane = .left
            activeArea = .files
            leftModel.ensureFileSelection()
        case .fileRight:
            activePane = .right
            activeArea = .files
            rightModel.ensureFileSelection()
        }
    }
}

private enum FocusStop {
    case folderTree
    case fileLeft
    case fileRight
}
#endif
