#if os(macOS)
import Foundation

extension FileBrowserModel {
    var selectedVisibleItems: [FileItem] {
        FileBrowserDirectoryState.selectedVisibleItems(
            selectedItemIDs: selectedItemIDs,
            allItemLookup: allItemLookup,
            visibleItemIndexLookup: visibleItemIndexLookup
        )
    }

    var selectedFileListRowID: FileListRowID? {
        FileBrowserSelectionSupport.selectedFileListRowID(
            isParentDirectorySelected: isParentDirectorySelected,
            primarySelectedItemID: primarySelectedItemID
        )
    }

    func isSelected(_ item: FileItem) -> Bool {
        selectedItemIDs.contains(item.id)
    }

    func select(_ item: FileItem, extending: Bool = false) {
        applySelection(
            FileBrowserSelectionSupport.itemSelection(
                itemID: item.id,
                extending: extending,
                selectedItemIDs: selectedItemIDs,
                primarySelectedItemID: primarySelectedItemID,
                selectionAnchorItemID: selectionAnchorItemID
            )
        )
    }

    func selectParentDirectory() {
        guard canGoUp else { return }
        applySelection(FileBrowserSelectionSupport.parentDirectorySelection())
    }

    func ensureFileSelection() {
        if isParentDirectorySelected || primarySelectedItem != nil {
            return
        }

        if canGoUp {
            selectParentDirectory()
        } else if let firstItem = items.first {
            select(firstItem)
        }
    }

    /// Keystrokes typed within this window extend the type-ahead
    /// prefix; a longer pause starts a fresh prefix. Matches the
    /// Finder/Explorer feel.
    static let typeSelectResetInterval: TimeInterval = 1.0

    /// Finder/Explorer-style type-to-select: each printable keystroke
    /// extends a prefix (until `typeSelectResetInterval` of silence)
    /// and selection jumps to the first visible item whose name starts
    /// with it, case-insensitively. When the extended prefix matches
    /// nothing, both the prefix and the selection stay at the last
    /// hit.
    ///
    /// Pressing the same single character again cycles through the
    /// successive entries with that initial (Explorer behavior). This
    /// matters because the listing sorts folders before files: without
    /// cycling, a lone "c" always lands on the first "c…" folder and
    /// the "c…" files behind the folder block are unreachable.
    func selectByTypeAhead(_ input: String) {
        let now = Date()
        if let last = typeSelectLastKeystrokeAt,
           now.timeIntervalSince(last) > Self.typeSelectResetInterval {
            typeSelectBuffer = ""
        }
        typeSelectLastKeystrokeAt = now

        let normalized = input.localizedLowercase
        if !typeSelectBuffer.isEmpty, typeSelectBuffer == normalized {
            selectNextTypeAheadMatch(prefix: normalized)
        } else {
            let candidate = typeSelectBuffer + normalized
            if let match = items.first(where: { $0.searchName.hasPrefix(candidate) }) {
                typeSelectBuffer = candidate
                select(match)
            }
            // No match: prefix and selection stay at the last hit.
        }

        publishTypeAheadDisplay()
    }

    /// Mirror the active prefix into the status line and schedule its
    /// removal for when the type-ahead window closes, so the user can
    /// always see what has been typed and when a new search starts.
    private func publishTypeAheadDisplay() {
        if typeSelectDisplay != typeSelectBuffer {
            typeSelectDisplay = typeSelectBuffer
        }

        typeSelectDisplayClearWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.typeSelectDisplayClearWork = nil
            if !self.typeSelectDisplay.isEmpty {
                self.typeSelectDisplay = ""
            }
        }
        typeSelectDisplayClearWork = work
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Self.typeSelectResetInterval,
            execute: work
        )
    }

    /// Advance to the next visible item matching `prefix`, wrapping
    /// past the end back to the first match. The type-ahead buffer
    /// stays at the single character so every further press keeps
    /// cycling.
    private func selectNextTypeAheadMatch(prefix: String) {
        let matchIndices = items.indices.filter { items[$0].searchName.hasPrefix(prefix) }
        guard !matchIndices.isEmpty else { return }

        let currentIndex = primarySelectedItemID.flatMap { id in
            items.firstIndex { $0.id == id }
        }
        if let currentIndex,
           let nextIndex = matchIndices.first(where: { $0 > currentIndex }) {
            select(items[nextIndex])
        } else {
            select(items[matchIndices[0]])
        }
    }

    func selectForContextMenu(_ item: FileItem) {
        applySelection(
            FileBrowserSelectionSupport.contextMenuSelection(
                itemID: item.id,
                selectedItemIDs: selectedItemIDs
            )
        )
    }

    func selectAllVisibleItems() {
        applySelection(FileBrowserSelectionSupport.allItemsSelection(items: items))
    }

    func clearSelection() {
        inlineNameEdit = nil
        setSelectionState(
            selectedItemIDs: [],
            primarySelectedItemID: nil,
            selectionAnchorItemID: nil,
            isParentDirectorySelected: false
        )
    }

    func applyPendingFileSelectionIfVisible() {
        guard let pendingFileSelectionURL else { return }
        let key = pendingFileSelectionURL.standardizedFileURL
        guard visibleItemIndexLookup[key] != nil else { return }

        setSelectionState(
            selectedItemIDs: [key],
            primarySelectedItemID: key,
            selectionAnchorItemID: key,
            isParentDirectorySelected: false
        )
        self.pendingFileSelectionURL = nil
    }

    func pruneSelection() {
        let result = FileBrowserSelectionSupport.prunedSelection(
            selectedItemIDs: selectedItemIDs,
            primarySelectedItemID: primarySelectedItemID,
            selectionAnchorItemID: selectionAnchorItemID,
            isParentDirectorySelected: isParentDirectorySelected,
            canGoUp: canGoUp,
            visibleItemIndexLookup: visibleItemIndexLookup
        )
        setSelectionState(
            selectedItemIDs: result.selectedItemIDs,
            primarySelectedItemID: result.primarySelectedItemID,
            selectionAnchorItemID: result.selectionAnchorItemID,
            isParentDirectorySelected: result.isParentDirectorySelected
        )
    }

    func applySelection(_ selection: FileSelectionStateResult) {
        if let edit = inlineNameEdit, !selection.selectedItemIDs.contains(edit.url) {
            // Selection moved off the inline-edit row (the user
            // clicked another row, right-clicked elsewhere,
            // etc.). Treat that as a focus-loss commit so any
            // typed text is applied — matching the Finder
            // behavior the user requested. For `.newItem` with
            // no typed change `commitInlineNameEdit` falls
            // through to a no-op dismiss; either way the file
            // stays on disk.
            commitInlineNameEdit(text: edit.text)
        }

        setSelectionState(
            selectedItemIDs: selection.selectedItemIDs,
            primarySelectedItemID: selection.primarySelectedItemID,
            selectionAnchorItemID: selection.selectionAnchorItemID,
            isParentDirectorySelected: selection.isParentDirectorySelected
        )
    }

    /// Centralized selection-state mutator. Each setter is
    /// guarded so identical writes don't republish; this
    /// matters because `selectedItemIDs.didSet` used to chain
    /// into `refreshPreviewURLs` and the duplicate work was
    /// triggering "Publishing changes from within view updates"
    /// runtime warnings on rapid selection updates (drop,
    /// new-folder, etc.).
    func setSelectionState(
        selectedItemIDs nextSelectedItemIDs: Set<FileItem.ID>,
        primarySelectedItemID nextPrimarySelectedItemID: FileItem.ID?,
        selectionAnchorItemID nextSelectionAnchorItemID: FileItem.ID?,
        isParentDirectorySelected nextIsParentDirectorySelected: Bool
    ) {
        if isParentDirectorySelected != nextIsParentDirectorySelected {
            isParentDirectorySelected = nextIsParentDirectorySelected
        }
        if selectedItemIDs != nextSelectedItemIDs {
            selectedItemIDs = nextSelectedItemIDs
        }
        if primarySelectedItemID != nextPrimarySelectedItemID {
            primarySelectedItemID = nextPrimarySelectedItemID
        }
        if selectionAnchorItemID != nextSelectionAnchorItemID {
            selectionAnchorItemID = nextSelectionAnchorItemID
        }
        refreshPreviewURLs()
    }
}

#endif
