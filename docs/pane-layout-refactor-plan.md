# Pane Layout Refactor Plan

This document defines the pane-layout behavior and the refactor phases used to implement it. It focuses on these related changes:

- Pane visibility toggles must not directly resize the window.
- The file-list split starts at equal width but can be adjusted temporarily while split view is visible.
- Folder tree width is user-resizable, does not grow automatically on window growth, and only shrinks as the last fallback during window narrowing.
- When preview is visible, window-width changes first resize the preview pane; only after preview reaches its minimum does narrowing propagate into the file area.
- When the built-in terminal is visible, window-height changes first resize the terminal pane; only after terminal reaches its minimum does narrowing propagate into the main file area.

## Goals

- Make pane behavior predictable: toggling a pane changes allocation inside the current window instead of moving or resizing the window.
- Keep every visible pane above its hard minimum width.
- Preserve user-visible continuity while the window width or visible side panes change.
- Avoid adding persistence for temporary file-list split allocation.
- Avoid persisting pane-size changes that are caused only by window resizing.
- Keep the layout calculation testable outside SwiftUI and AppKit.

## Non-Goals

- Do not add fully free pane docking or arbitrary pane placement.
- Do not persist the temporary left/right file-list split ratio.
- Do not let the folder tree grow automatically when the window grows.
- Do not keep a hidden "desired" file split ratio that differs from the latest valid visible ratio.
- Do not treat window-resize-driven preview width or terminal height changes as explicit user pane-resize choices.

## Target Behavior

### Window Size

Pane visibility changes must not call `NSWindow.setFrame(...)` or otherwise resize the window directly.

The window content minimum width should be calculated from hard minimums:

```text
minimum window width =
  visible folder tree minimum width
+ file area minimum width for the current file-list mode
+ visible preview minimum width
+ visible divider widths
+ header-driven minimum width, as a max() floor
```

Saved pane widths are preferences for normal allocation, not contributors to the window minimum. This keeps the minimum width tied to "what can render without breaking", not "what the user last preferred".

When the terminal pane is visible, the window content minimum height includes the normal window minimum plus the terminal pane minimum height and the horizontal divider. This keeps both the main file area and the terminal pane above their usable minimum heights.

### Folder Tree

The folder tree is width-stable.

- When the window grows, the folder tree must not grow beyond its stored width.
- When the window shrinks, the folder tree should keep its stored width while other shrinkable space remains.
- If the window is narrow enough that all other relevant panes have reached their minimum widths, the folder tree may shrink down to `minimumFolderTreeWidth`.
- That temporary shrink must not be saved to `folderTreeWidth`.
- When enough width returns, the folder tree should return toward its stored width, but never exceed it automatically.

This makes the folder tree the last horizontal fallback, not a normal elastic pane.

### Preview

The preview pane uses its stored width as a preference.

- When preview is visible, normal window-width changes first resize the preview pane.
- When the window grows, the additional width goes to preview before the file area grows.
- When the window shrinks, preview shrinks first.
- If preview reaches `minimumPreviewPaneWidth`, further narrowing propagates to the file area.
- Window-resize-driven preview widths are temporary and must not be saved to `previewWidth`.
- Direct preview-divider drag is still the explicit user action that persists `previewWidth`.

This means preview display width may temporarily become larger or smaller than the stored preview width. The stored width remains the restore preference for future sessions and direct pane toggles; the current rendered width is the continuity source while the window is being resized.

### File Area

The central file area receives the remaining width after side-pane allocation.

In single-file-pane mode, its hard minimum is `minimumFilePaneWidth`.

In split-file-pane mode, its hard minimum is:

```text
minimumFilePaneWidth * 2 + dividerWidth
```

The file area absorbs width changes only after the current higher-priority resize target has reached its limit.

- If preview is visible, preview is the first horizontal resize target.
- If preview is hidden, the file area is the normal horizontal resize target.
- Folder tree is not a growth target and is the last narrowing fallback.

### Built-In Terminal

The terminal pane uses its stored height as a preference.

- When terminal is visible, normal window-height changes first resize the terminal pane.
- When the window grows taller, the additional height goes to terminal before the main file area grows.
- When the window shrinks, terminal shrinks first.
- If terminal reaches `minimumTerminalPaneHeight`, further narrowing propagates to the main file area.
- Window-resize-driven terminal heights are temporary and must not be saved to `terminalPaneHeight`.
- Direct terminal-divider drag is still the explicit user action that persists `terminalPaneHeight`.

This keeps the main file area visually stable during normal vertical window resizing while the terminal is open, until the terminal can no longer absorb the height change.

### Left/Right File-List Split

When switching from single file list to split file list:

- Left and right file lists start at 50:50.
- The user can drag the divider between the two file lists while split view is visible.
- The temporary allocation is kept only while split view remains visible.
- Switching split view off discards the temporary allocation.
- The next time split view is shown, the allocation starts at 50:50 again.
- Relaunching the app does not restore the temporary allocation.

When the central file-area width changes, apply the allocation that was visible immediately before the change to the new width.

Example:

```text
Before:
file area width = 600
left = 400
right = 200
ratio = 4:2

After file area grows to 1000:
left ~= 667
right ~= 333
```

If the allocation would put either file list below `minimumFilePaneWidth`, clamp to the nearest valid allocation. The clamped visible allocation becomes the current allocation for future changes.

## State Model

### Persisted State

Keep existing persisted state for:

- Folder tree visibility.
- Preview visibility.
- Split view visibility.
- Folder tree stored width.
- Preview stored width.
- Terminal pane visibility and height.

Do not add persisted state for the left/right file-list split.

Do not persist preview width or terminal height updates that come from window resizing. Persist them only when their own divider is dragged.

### Temporary State

Add a non-persisted state value for the current file split ratio:

```swift
@State private var fileSplitRatio: CGFloat = 0.5
```

Rules:

- Reset to `0.5` whenever split view changes from hidden to visible.
- Update while the user drags the file-list divider.
- Update to the clamped effective ratio after central file-area width changes, but do not update SwiftUI state directly inside `body` layout calculation.
- Do not store this ratio in `UserDefaults`.

Track the current rendered preview width and terminal height as transient layout facts when needed. These values are continuity inputs for window resizing, not user preferences.

Rules:

- On direct preview-divider drag, write the resulting width to `previewWidth`.
- On window-width resize, update only the rendered preview width; do not write `previewWidth`.
- On direct terminal-divider drag, write the resulting height to `terminalPaneHeight`.
- On window-height resize, update only the rendered terminal height; do not write `terminalPaneHeight`.

## Layout Calculation

Introduce a pure helper for horizontal pane allocation before wiring it into views.

Inputs should include:

- Total available width.
- Divider width.
- Visibility of folder tree and preview.
- Whether file split is visible.
- Folder tree stored width.
- Preview stored width.
- Current rendered preview width, when available.
- Current file split ratio.
- Hard minimum widths.
- The cause of the change: window resize or explicit divider drag.

Outputs should include:

- Folder tree display width.
- File area display width.
- Preview display width.
- Left file-list display width.
- Right file-list display width.
- Effective file split ratio after clamping.
- Whether the file-list divider is movable.

The helper should guarantee:

- Every returned width is non-negative.
- Visible panes are never below their hard minimums when the input width is at or above the computed content minimum.
- The returned widths plus visible dividers exactly equal the input width, allowing for intentional point rounding.
- Folder tree display width never exceeds the stored folder tree width.
- Preview display width may temporarily exceed the stored preview width during window growth, but that temporary width is not persisted.
- Window-width changes resize preview first while preview is visible.
- Further narrowing propagates to the file area only after preview reaches `minimumPreviewPaneWidth`.

Add a pure helper for vertical main/terminal allocation.

Inputs should include:

- Total available height.
- Divider height.
- Terminal visibility.
- Terminal stored height.
- Current rendered terminal height, when available.
- Hard minimum heights for the main file area and terminal.
- The cause of the change: window resize or explicit terminal-divider drag.

Outputs should include:

- Main file-area display height.
- Terminal display height.
- Whether the terminal divider is movable.

The helper should guarantee:

- Every returned height is non-negative.
- Visible vertical panes are never below their hard minimums when the input height is at or above the computed content minimum.
- Returned heights plus visible divider exactly equal the input height, allowing for intentional point rounding.
- Window-height changes resize terminal first while terminal is visible.
- Further narrowing propagates to the main file area only after terminal reaches `minimumTerminalPaneHeight`.
- Terminal display height may temporarily exceed or fall below the stored terminal height during window resize, but that temporary height is not persisted.

## File Divider UI

The divider between the two file lists should be a drag handle with stable geometry.

- Drawn width stays at 1pt.
- Hit target is wider than 1pt.
- Cursor uses horizontal resize.
- Drag feedback should use color or opacity, not a layout-width change.
- If the movable range is zero, dragging should not change the layout.

Avoid using a handle whose actual frame width changes during drag, because that can make file-list widths jitter.

## Implementation Phases

### Phase 1: Specification and Documentation

- Add this plan.
- Use this document as the source of truth for the layout work.

### Phase 2: Pure Layout Helper

- Add a focused helper for horizontal pane and file-list split calculation.
- Keep it independent of SwiftUI and AppKit.
- Include explicit rounding rules so divider positions land on stable point boundaries.

### Phase 3: Layout Helper Tests

Add tests for:

- Single file pane minimum width.
- Split file pane minimum width.
- 50:50 split start.
- Custom split ratio.
- Left minimum clamp.
- Right minimum clamp.
- File area width changes preserving the immediately previous visible ratio.
- Folder tree not growing when window width grows.
- Folder tree shrinking only after other eligible panes reach minimum width.
- Preview temporary shrink not becoming stored width.
- Returned widths summing to total width.

### Phase 4: Remove Toggle-Driven Window Resizing

- Stop calling the current toggle-driven window resize path.
- Update content minimum calculation to use hard minimum widths instead of stored pane widths.
- Keep the header-driven minimum width as a floor.
- Confirm that pane toggles no longer move or resize the window.

### Phase 5: Wire Main Pane Allocation

- Replace hard-coded folder width allocation with the helper result.
- Let folder tree render at a temporary width between its minimum and stored width.
- Let preview render at a temporary width between its minimum and stored width.
- Ensure temporary side-pane widths are not persisted during window resize or pane toggle layout.

### Phase 6: Add Temporary File-List Split Resizing

- Add non-persisted `fileSplitRatio`.
- Reset it to `0.5` when split view becomes visible.
- Replace the static middle divider with the stable drag handle.
- Update `fileSplitRatio` from user drag within the valid range.
- Apply helper-produced left/right widths.

### Phase 7: Polish and Manual Verification

Verify manually:

- Toggle folder tree on/off without window resize.
- Toggle preview on/off without window resize.
- Toggle split view on/off without window resize.
- Split view starts at 50:50 every time it is shown.
- Dragged split ratio survives window resizing while split view remains visible.
- Split ratio is discarded after split view is hidden.
- Folder tree does not grow when the window grows.
- Folder tree shrinks only as the last fallback when narrowing the window.

### Phase 8: Window-Resize Priority for Preview and Terminal

- Extend the horizontal pane allocation so preview is the first resize target while visible.
- Preserve folder-tree behavior: no automatic growth, user-resizable by divider, last fallback during narrowing.
- Allow preview display width to exceed stored width during window growth, without persisting that temporary value.
- Ensure further horizontal narrowing reaches the file area only after preview is at `minimumPreviewPaneWidth`.
- Add a vertical layout helper for main file area + terminal pane.
- Make terminal the first vertical resize target while visible.
- Ensure further vertical narrowing reaches the main file area only after terminal is at `minimumTerminalPaneHeight`.
- Persist preview width and terminal height only on direct divider drag.
- Add tests for both horizontal and vertical window-resize priority.

Tests to add:

- Preview visible + window grows: preview grows, folder tree and file area remain stable where possible.
- Preview visible + window shrinks above preview minimum: preview shrinks first.
- Preview visible + window shrinks past preview minimum: file area shrinks after preview reaches minimum.
- Preview hidden + window width changes: file area absorbs width changes.
- Terminal visible + window grows taller: terminal grows, main file area remains stable where possible.
- Terminal visible + window shrinks above terminal minimum: terminal shrinks first.
- Terminal visible + window shrinks past terminal minimum: main file area shrinks after terminal reaches minimum.
- Terminal hidden + window height changes: main file area absorbs height changes.
- Window-resize-driven preview and terminal changes are not persisted.

Manual verification:

- Drag preview divider and confirm `previewWidth` persists.
- Resize the window while preview is visible and confirm the temporary preview width is not persisted after relaunch.
- Drag terminal divider and confirm `terminalPaneHeight` persists.
- Resize the window while terminal is visible and confirm the temporary terminal height is not persisted after relaunch.

### Phase 9: Update Current Architecture Docs

After implementation, update:

- `docs/detailed-design.md`
- `README.md`
- `README.ja.md`
- Any comments that still say split file panes are always equal width.

## Risk Notes

- Do not update `@State` directly from a SwiftUI `body` calculation. If the helper returns a new effective ratio after clamping, apply it through an event boundary such as a geometry-size change handler or a deferred main-queue update.
- Be careful to distinguish stored side-pane widths from temporary display widths. Only explicit user side-pane resize should persist a new side-pane width.
- The content minimum must be updated before relying on the layout helper to satisfy hard minimums.
- Existing comments and tests may still assume that the file-list split is always equal width. Update them with the implementation.
- Avoid deriving window-resize intent from SwiftUI `body` alone. Use AppKit live-resize state, split-view delegate callbacks, or explicit geometry-change reconciliation so divider drags and window resizes can be separated.
- Preview and terminal now have temporary display sizes that can differ from stored preferences. Keep naming clear (`stored`, `displayed`, `transient`, `effective`) so persistence guards remain obvious.
