#if os(macOS)
import AppKit
import CoreGraphics

extension TerminalFileManagerView {
    /// Horizontal scroll step in points per left / right arrow press.
    private static let horizontalScrollStep: CGFloat = 60

    func handleKeyEvent(_ event: NSEvent) -> Bool {
        if event.modifierFlags.contains([.command, .option]),
           event.modifierFlags.intersection([.control]).isEmpty,
           event.charactersIgnoringModifiers?.lowercased() == "v" {
            activeModel.pasteItemsMoving()
            return true
        }

        // ⌘⇧X — swap the left and right panes. Handled here in addition to
        // the `ViewMenuCommands` keyboard-shortcut binding because the menu
        // path does not fire reliably when the menu button is
        // `.disabled(!isSplitViewVisible)` and the @AppStorage value is read
        // before the view body settles. `swapPanes()` itself guards on the
        // split-visible flag, so calling it from a path that bypasses the
        // menu's `.disabled` modifier is still safe.
        if event.modifierFlags.contains([.command, .shift]),
           event.modifierFlags.intersection([.option, .control]).isEmpty,
           event.charactersIgnoringModifiers?.lowercased() == "x" {
            swapPanes()
            return true
        }

        if event.modifierFlags.contains(.command),
           event.modifierFlags.intersection([.option, .control]).isEmpty,
           event.keyCode == 51 {
            activeModel.moveSelectedItemsToTrash()
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
