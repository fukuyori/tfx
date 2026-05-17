# File Manager Implementation Plan

This document tracks the implementation plan for turning `tfx` into a practical macOS file manager with a terminal-like interface, drag and drop, previews, and terminal integration.

## Goals

- Keep the main experience fast, keyboard-friendly, and terminal-inspired.
- Provide file manager basics: navigation, selection, create, rename, copy, move, delete, preview, and search.
- Use macOS-native behavior where it is stronger than custom code, especially Quick Look, Finder integration, Terminal.app, and Trash.
- Prefer safe operations: move to Trash instead of permanent delete, confirm destructive or overwriting operations, and surface permission errors clearly.

## Current State

- macOS SwiftUI app.
- Three-pane layout:
  - Left folder tree.
  - Center terminal-style split file lists.
  - Right preview pane.
- Split file view supports two independent folders.
- The active file pane is highlighted in green.
- The folder tree can also become the active keyboard target and highlights the selected folder.
- Toolbar actions, search, sorting, preview, Terminal.app opening, and the folder tree follow the active file pane.
- The header path is a clickable breadcrumb bar; clicking a segment navigates directly to that folder.
- The folder tree highlights the active pane's current folder and expands its ancestor path.
- On startup, the folder tree expands only the ancestor path for the current folder and leaves subfolders collapsed.
- Folders can be pinned and are shown in a persistent `PINNED` section at the top of the folder tree.
- Home, Documents, and Downloads are pinned by default on first launch.
- Pinned folders can be reordered by dragging within the `PINNED` section.
- Pinned folder rows act as shortcuts and do not expand child folders in the `PINNED` section.
- Selecting a pinned folder keeps the active tree selection on the pinned row while expanding the matching physical ancestor path in the regular tree.
- The folder tree is display/navigation/drop-target UI. Dropping files from a file pane onto a regular folder-tree row is supported, but moving folders within the tree is not supported.
- The regular folder tree is a single hierarchy starting at `/`; Home, Documents, Downloads, and similar folders are not duplicated as separate tree roots.
- Hidden folders appear in the folder tree when hidden-file display is enabled.
- The app restores the previous window frame, visible panes, active pane, opened folders, and pane widths on launch.
- Preview pane supports:
  - PDF through PDFKit.
  - Video through AVKit.
  - Markdown through a rendered WebKit preview.
  - Other file types through Quick Look fallback.
  - Compact metadata for selected files and folders, including kind, size, location, dates, permissions, and code-signature status.
- Drag and drop file moving is available.
- Drag and drop works between the left and right file panes, and both panes reload after a completed drop.
- Terminal toolbar button opens Terminal.app at the current directory.
- File modified date uses `yyyy-MM-dd HH:mm:ss`.
- Back and forward navigation are available.
- Single-selection file operations are available:
  - New file.
  - New folder.
  - Rename.
  - Move to Trash.
  - Reveal in Finder.
  - Copy path.
- Context menus are available for file rows and folder tree rows.
- The file row context menu includes an "Open With" submenu listing applications that can open the file, plus an "Other…" picker for choosing an arbitrary application.
- File row and empty-area context menus follow Finder's grouping with dividers between Open / destructive / manipulation / location / folder-specific groups.
- Each file pane watches its current directory through a `DispatchSource`-based watcher and auto-refreshes when the contents change externally.
- Same-directory reloads keep the existing items on screen and atomically swap in the new listing, instead of blanking the pane during the load.
- Markdown, HTML, CSV / TSV, and JSON previews offer a rendered/source toggle (eye-icon button); the per-file info strip is hidden while these previews are rendered.
- CSV / TSV previews render as a monospaced scrollable table with a header row; JSON previews render as pretty-printed text.
- `.toml`, `.yaml`, `.yml`, `.ini`, `.cfg`, `.conf`, `.log`, `.txt`, and `.env` use the built-in plain-text preview rather than Quick Look.
- Pane-boundary drag handles and the NAME-column resize handle show the `resizeLeftRight` cursor while the pointer is over their hit area.
- Right-clicking a file row activates the pane and updates the selection before the context menu opens.
- File rows, the file-pane background, and folder-tree rows each have a single context menu (`FileItemContextMenu`, `EmptyFileAreaContextMenu`, and `FolderTreeRowContextMenu`), all using the same Finder grouping with dividers.
- Current-folder search, hidden file toggle, and sorting are available.
- Subfolder search is available with progress reporting, incremental results, and cancellation.
- Multiple selection is available with Command-click.
- Range selection is available with Shift-click, Shift + Up/Down, and mouse drag.
- Multi-item operations are available for:
  - Move to Trash.
  - Reveal in Finder.
- App-local copy, cut, and paste are available.
- Finder pasteboard compatibility is available for copying, cutting, and pasting file URLs.
- `Command + Option + V` is available as move-paste for file URLs.
- Option-drag copies files while normal drag moves files.
- Finder aliases and directory symlinks are resolved for folder navigation.
- Zip archives can be browsed without extracting the whole archive.
- Zip archive entries can be copied out to real folders.
- Context menus can compress selected items to zip and extract zip archives.
- Zip archive virtual directories are read-only.
- Paste and drag/drop same-name conflicts show a dialog:
  - Replace.
  - Keep Both.
  - Skip.
  - Cancel.
- Keyboard shortcuts are available for common actions:
  - Back / forward.
  - Parent folder.
  - Backspace parent-folder navigation.
  - Search focus.
  - Toggle hidden files.
  - New folder.
  - Rename.
  - Move to Trash.
  - Command-Backspace move to Trash.
  - Copy / cut / paste.
  - Select all.
  - Reload.
  - Open Terminal here.
- Keyboard navigation is available for the active target:
  - Up / Down move the selection in the active file pane, including the `..` parent folder row, or in the folder tree.
  - Shift + Up / Down extends the file pane selection range.
  - Left / Right move keyboard focus between the folder tree and file panes.
  - Right from the folder tree moves focus to the active file pane.
  - Enter opens the selected file or navigates into the selected folder.
- Folder tree expansion state is stored in the model.
- Folder tree children are cached and refreshed after file operations.
- Navigating to a folder expands its ancestor folders in the tree.
- File list metadata columns include:
  - Kind.
  - Modified date.
  - Created date.
  - POSIX permissions.
- File list display settings are available:
  - File name column width by dragging the `NAME` header.
  - Column visibility for icon, mode, size, kind, modified date, created date, and permissions.
  - Column order, with the file name column always visible.
- File list supports horizontal scrolling for wider metadata columns.
- Status line shows visible item count, total item count, selected count, selected path, and disk free space.

## Phase 1: Navigation Basics

Add navigation history and stronger location controls.

- Add back and forward history stacks to `FileBrowserModel`.
- Update `navigate(to:)` to push history.
- Add `goBack()` and `goForward()`.
- Add toolbar buttons for back and forward.
- Keep existing parent-folder navigation.
- Add path copy for the current directory.

Acceptance criteria:

- Back and forward work across folder tree clicks, breadcrumb path clicks, double-click navigation, parent navigation, and folder picker navigation.
- Current directory remains the single source of truth for file list, preview, Terminal.app opening, and drag destination.

## Phase 2: File Operations

Implement single-selection file operations first.

- New folder.
- New file.
- Rename selected item.
- Move selected item to Trash.
- Reveal selected item in Finder.
- Open selected item with default app.
- Copy selected item path.
- Copy current directory path.

Acceptance criteria:

- Operations are available from toolbar or context menu where appropriate.
- Trash operation uses Finder-compatible Trash behavior, not permanent deletion.
- Errors are shown through the existing alert mechanism.
- File list reloads after any mutating operation.

## Phase 3: Context Menus

Add right-click actions to file rows and folder tree rows.

File row menu:

- Open.
- Compress to Zip.
- Extract Zip when the row is a zip archive.
- Rename.
- Move to Trash.
- Reveal in Finder.
- Copy Path.
- Open Terminal Here for folders.

Folder tree row menu:

- Open.
- Reveal in Finder.
- Copy Path.
- Open Terminal Here.

Acceptance criteria:

- Context menu actions operate on the row under the pointer.
- Primary selection updates predictably when opening the context menu.
- Blank file-view context menus can create a new file or folder.

## Phase 4: Multiple Selection

Replace single selection with a selection model that can support multiple files.

- Replace `selectedItem: FileItem?` with:
  - `selectedItemIDs: Set<FileItem.ID>`.
  - `primarySelectedItem: FileItem?`.
- Keep preview bound to the primary selected item.
- Update file operations to operate on all selected items.
- Support shift-click and command-click if practical in SwiftUI.

Acceptance criteria:

- Multiple selected files can be moved to Trash.
- Preview remains stable and shows one primary item.
- Status line shows selected count.

## Phase 5: Search and Filtering

Add simple filtering before deep search.

- Add search text state.
- Filter the current directory by file name.
- Add hidden file display toggle.
- Add sort key:
  - Name.
  - Size.
  - Kind.
  - Modified.
- Add ascending/descending sort order.

Acceptance criteria:

- Filtering is instant for normal folders.
- Hidden files can be toggled without restarting the app.
- Sorting applies consistently to files and folders.

## Phase 6: Folder Tree Improvements

Move folder tree expansion state into the model.

- Add `expandedFolders: Set<URL>`.
- Add `folderChildrenCache: [URL: [URL]]`.
- Load child folders lazily.
- Refresh expanded folder cache after file operations.
- Auto-expand parent folders when navigating to a directory from outside the tree.

Acceptance criteria:

- Folder expansion state survives row recreation.
- Navigating via path, picker, or file list expands the relevant tree path.
- Large folder trees do not trigger full recursive scans.

## Phase 7: Copy and Move Semantics

Make copy/move behavior safer and more complete.

- Add copy operation.
- Add cut/move operation.
- Add paste into current directory.
- Support drag copy with modifier key if practical.
- Handle same-name conflicts.

Initial conflict behavior:

- Keep Both using generated names.

Later conflict dialog:

- Replace.
- Keep Both.
- Skip.
- Cancel.

Acceptance criteria:

- Copy, move, and paste work within the app.
- Same-name conflicts never overwrite silently.
- Cross-volume moves behave correctly.

## Phase 8: Keyboard Shortcuts

Add expected file-manager shortcuts.

- Up / Down: Move selection in the active file pane or folder tree.
- Shift + Up / Down: Extend the file pane selection range.
- Left / Right: Move keyboard focus between folder tree and file panes.
- Enter: Open selected file or enter selected folder.
- `Command-R`: Reload.
- `Command-N`: New Folder.
- `Delete`: Move to Trash.
- `Backspace`: Parent folder.
- `Command-Backspace`: Move to Trash.
- `Command-C`: Copy selected path or selected files.
- `Command-V`: Paste files.
- `Command-F`: Focus search.
- `Command-L`: Focus path/location control.
- `Space`: Preview selected item.
- `Command-Shift-.`: Toggle hidden files.

Acceptance criteria:

- Shortcuts are discoverable through menus where possible.
- Shortcuts operate on the same model actions as toolbar and context menu actions.

## Phase 9: Metadata and Columns

Improve file list details.

- Add created date.
- Add kind or extension.
- Add permissions.
- Add owner and group if useful.
- Add symlink target.
- Add disk free space in status area.

Acceptance criteria:

- Dates use `yyyy-MM-dd HH:mm:ss`.
- Columns align and remain readable.
- Missing metadata displays as `-`.

## Phase 10: Polish and Validation

Finish behavior and visual consistency.

- Ensure text does not overflow toolbar buttons or rows.
- Validate drag and drop into file rows and tree folders.
- Validate Terminal.app opens at the current directory.
- Validate preview for images, PDFs, videos, Markdown, text files, and folders.
- Validate permission-denied errors.
- Validate behavior with large directories.

## Future Plan: Customization and Extensibility

Track larger customization and extension work as separate follow-up phases.

### Future Phase A: Configuration Foundation

- User-editable configuration files are stored under `~/Library/Application Support/tfx/`.
- Declarative configuration, themes, filetype rules, and shortcut definitions use TOML.
- Dynamic extension behavior uses Lua.
- Transient UI state remains in `UserDefaults`.

Initial file layout:

- `config.toml`: Main user configuration.
- `themes/*.toml`: User-defined color schemes.
- `filetypes.toml`: Extension-based behavior rules.
- `shortcuts.toml`: Shortcut definitions.
- `scripts/*.lua`: Lua extension scripts.
- `markdown/preview.css`: Markdown preview CSS.

Acceptance criteria:

- The app creates the configuration directory when needed.
- Missing configuration files fall back to built-in defaults.
- Invalid TOML shows a readable error without preventing the app from launching.
- UI state such as window frame, pane widths, and last folders remains in `UserDefaults`.

### Future Phase B: Color Schemes

- Color scheme selection.
- User-defined color scheme files.

Planned scope:

- Built-in color schemes.
- User-created TOML theme files.
- Theme selection from app settings.
- Theme reload without rebuilding the app.

Acceptance criteria:

- File panes, folder tree, selection colors, active borders, status text, and preview backgrounds can be themed.
- Invalid theme keys fall back to defaults.
- Theme changes are applied consistently across split panes and preview state.

### Future Phase C: Markdown Preview Extensions

- Extensible Markdown preview rendering.
- Markdown preview settings include KaTeX, MathJax, Mermaid, and custom CSS configuration.

Planned scope:

- Ruby text rendering.
- Math rendering through KaTeX or MathJax settings.
- Mermaid diagram rendering.
- Custom Markdown preview CSS.
- Custom inline or block syntax through a constrained extension pipeline.

Example TOML shape:

```toml
[markdown.katex]
macros = {}

[markdown.mathjax.tex]

[markdown.mathjax.options]

[markdown.mathjax.loader]

[markdown.mermaid]
startOnLoad = false

[markdown.css]
files = ["markdown/preview.css"]
inline = ""
```

Acceptance criteria:

- Markdown preview can load configured CSS.
- Ruby notation can render as `<ruby>` without breaking normal Markdown.
- Math and Mermaid settings are loaded from TOML.
- Unsafe HTML/script behavior is explicitly controlled.

### Future Phase D: Extension-Based Behavior

- Extension-based behavior customization.

Planned scope:

- Extension-based open behavior.
- Extension-based preview behavior.
- Extension-based context menu additions.
- Rule priority between built-in behavior, TOML rules, and Lua hooks.

Acceptance criteria:

- A file extension can map to a built-in preview mode or default app behavior.
- Built-in behavior remains available when no rule matches.
- Conflicting rules resolve predictably.

### Future Phase E: Shortcuts

- Shortcut feature cleanup and expansion.

Planned scope:

- Central shortcut registry.
- TOML-defined shortcut overrides.
- Conflict detection.
- Menu item synchronization where practical.

Acceptance criteria:

- Existing shortcuts are represented in one registry.
- User-defined shortcuts can override supported actions.
- Conflicts are reported clearly.

### Future Phase F: Lua Extension API

- Lua scripting for extension-based actions and shortcut actions.

Initial policy:

- Lua runs in a restricted sandbox.
- Initial APIs are read-oriented and tfx-controlled.
- File mutation is not allowed in the first implementation.
- External command execution is not allowed in the first implementation.
- Markdown filters may transform Markdown text or produce sanitized HTML fragments.

Planned scope:

- Lua hooks for extension-based behavior.
- Lua hooks for shortcut actions.
- Lua filters for Markdown preview extensions.
- tfx-provided APIs for selected files, current folder, preview selection, and status messages.

Acceptance criteria:

- Lua scripts cannot mutate files unless a future explicit API is added.
- Script errors are shown without crashing the app.
- Long-running scripts cannot block the UI indefinitely.

### Future Phase G: Responsiveness

- Responsiveness and latency improvements.

Planned scope:

- Faster large-directory loading.
- Background metadata loading.
- Preview loading cancellation.
- Folder tree refresh throttling.
- Search and filter responsiveness.

Acceptance criteria:

- Large folders remain scrollable while metadata is loading.
- Preview requests cancel when selection changes.
- Search input remains responsive during filtering.

## Recommended Implementation Order

1. Navigation history.
2. New file, new folder, rename, and move to Trash.
3. Context menus.
4. Multiple selection.
5. Search, hidden files, and sorting.
6. Folder tree model state.
7. Copy, cut, paste, and conflict handling.
8. Keyboard shortcuts.
9. Metadata columns.
10. Polish and validation.

## Implementation Status

- Phases 1 through 9 are implemented in the app.
- Phase 10 validation is partially complete:
  - Build validation passes with `xcodebuild -project tfx.xcodeproj -scheme tfx -destination 'platform=macOS' -derivedDataPath /tmp/tfx-derived CODE_SIGNING_ALLOWED=NO build`.
  - Runtime validation should still be done manually for drag/drop, Terminal.app opening, preview coverage, and permission-denied paths.

## Notes

- Keep mutating operations in `FileBrowserModel` so toolbar actions, context menus, shortcuts, and drag-and-drop share the same behavior.
- Prefer `FileManager.trashItem(at:resultingItemURL:)` for delete-like behavior.
- Prefer `NSWorkspace` for Finder, Terminal.app, and default-app integration.
- Avoid recursive directory scanning unless the user explicitly runs a deep search.
