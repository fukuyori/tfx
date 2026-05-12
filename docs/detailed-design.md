# tfx Detailed Design

## 1. Overview

`tfx` is a SwiftUI macOS file manager with a terminal-inspired appearance and keyboard-first workflow. The main screen is composed of a folder tree on the left, one or two file panes in the center, and a preview pane on the right.

This document describes the current design for layout, state management, file operations, previews, persistence, error handling, and future extension points.

Project documentation is written in English by default. `README.ja.md` is maintained as the Japanese README.

## 2. Scope

### 2.1 In Scope

- Directory navigation from the folder tree.
- Directory navigation from the header breadcrumb path.
- File listing in left and right file panes.
- Single-pane and split-pane display modes.
- Single selection, multiple selection, and range selection.
- Back, forward, and parent-folder navigation.
- New folder, rename, and move to Trash.
- New file.
- Copy, cut, paste, and drag-and-drop move operations.
- Finder pasteboard interoperability for file copy, cut, and paste.
- Finder alias and directory symlink resolution for navigation.
- Same-name conflict resolution.
- Zip archive browsing without full extraction.
- Zip archive compression and extraction.
- Reveal in Finder, copy path, and Terminal.app integration.
- Search, hidden-file display, and sorting.
- PDF, video, Markdown, and Quick Look previews.
- Pinned folders and pinned-folder drag reordering.
- Persistent layout, column settings, window state, and folder state.

### 2.2 Out of Scope

- iOS and iPadOS file management.
- Developer ID signing, notarization, and installer packaging.
- Finder extensions and Spotlight indexing.
- Special network-file operation handling.
- Administrative operations that require privilege escalation.

## 3. Source Layout

The Swift sources are organized by feature responsibility:

| Directory | Responsibility |
| --- | --- |
| `tfx/App` | App entry points and root view wiring. |
| `tfx/TerminalFileManager` | Main screen composition, header controls, keyboard routing, and top-level layout state. |
| `tfx/FileBrowser` | File browser model, directory loading, selection, file operations, zip archive browsing, folder-tree data, pinned folders, metadata, icon caching, and drag/drop model behavior. |
| `tfx/FilePane` | File list UI, rows, headers, menus, status line, and file-list display settings. |
| `tfx/FolderTree` | Folder tree UI and pinned-folder UI. |
| `tfx/Preview` | Preview pane, preview type selection, Markdown/PDF/video/Quick Look previews, and multi-preview UI. |
| `tfx/Infrastructure` | Small reusable SwiftUI and AppKit helpers. |

See `docs/code-organization.md` for file naming and placement rules.

## 4. Technology Stack

| Area | Technology |
| --- | --- |
| UI | SwiftUI |
| macOS integration | AppKit, NSWorkspace, NSOpenPanel, NSAlert, NSPasteboard |
| PDF preview | PDFKit |
| Video preview | AVKit |
| Markdown preview | WebKit |
| Generic preview | QuickLookUI |
| File type detection | UniformTypeIdentifiers |
| Code signature status | Security |
| Zip archive listing and extraction | `/usr/bin/unzip` |
| Zip archive creation | `/usr/bin/ditto` |
| Persistence | `UserDefaults` / `@AppStorage` |

## 5. Screen Design

### 5.1 Overall Layout

`TerminalFileManagerView` composes the screen from:

1. Header
2. Folder tree pane
3. File display area
4. Preview pane

The header contains navigation, breadcrumb path navigation, search, sorting, file operations, pane visibility toggles, Terminal.app launch, and path copy actions. Folder tree width, preview width, and split-pane ratio can be changed by dragging.

The current directory path is displayed as a horizontally scrollable breadcrumb bar. Each path segment is clickable and calls the same directory navigation path as file-pane and folder-tree navigation. The bar scrolls to the trailing end when the current directory changes so the deepest folder remains visible.

### 5.2 Folder Tree Pane

`FolderTreePane` displays a single tree rooted at `/`. If pinned folders exist, a `PINNED` section is shown before the normal `FOLDERS` tree. On first launch, Home, Documents, and Downloads are seeded as default pinned folders.

Pinned folders are shortcuts. They can be reordered inside the `PINNED` section, but that only changes the app's display order and never moves real folders. Pinned-folder rows do not expand child folders.

Hidden folders are included in the folder tree when hidden-file display is enabled, and excluded when hidden-file display is disabled.

The regular folder tree is used for display, navigation, expansion/collapse, context menus, and file drop targets. Moving real folders within the folder tree is not allowed. Dropping files from the file view onto a folder tree row is allowed and moves those files into the target folder.

### 5.3 File Pane

`FilePane` renders a terminal-style file table. In split mode, the left and right panes each own an independent `FileBrowserModel`. In single-pane mode, only the active pane is visible.

The file list begins with a `..` parent-directory row. `FileRow` renders file type icon, mode, name, size, kind, modified date, created date, and permissions. The name column is always visible; other columns can be shown, hidden, and reordered.

### 5.4 Preview Pane

`PreviewPane` displays the active pane's selected item. When multiple files are selected, the preview pane can show multiple preview cards with a limit on active preview loading.

Selected files and folders also show compact metadata in the preview pane. The metadata includes display name, kind, size, containing folder, creation date, modification date, access date, POSIX permissions, and code-signature status. Signature status is reported as `Valid`, `Unsigned`, `Invalid`, or `-` when the item is not code-signable.

Preview type is selected by `PreviewKind` from the URL extension and content type:

| Type | View | Detection |
| --- | --- | --- |
| PDF | `PDFPreview` | UTType conforms to `.pdf` |
| Video | `VideoPreview` | UTType conforms to `.movie` |
| Markdown | `MarkdownPreview` | Extension is `md`, `markdown`, `mdown`, or `mkd` |
| Other | `QuickLookPreview` | Fallback |

## 6. State Management

### 6.1 Root State

`TerminalFileManagerView` owns the two file browser models and top-level UI state:

| State | Storage | Meaning |
| --- | --- | --- |
| `leftModel` | `@StateObject` | Left file pane model. |
| `rightModel` | `@StateObject` | Right file pane model. |
| `isPreviewVisible` | `@AppStorage` | Preview pane visibility. |
| `isSplitViewVisible` | `@AppStorage` | Split-pane visibility. |
| `activePaneRawValue` | `@AppStorage` | Active file pane. |
| `activeAreaRawValue` | `@AppStorage` | Active keyboard target. |
| `folderTreeWidth` | `@AppStorage` | Folder tree width. |
| `previewWidth` | `@AppStorage` | Preview pane width. |
| `fileSplitRatio` | `@AppStorage` | Left/right file pane ratio. |
| `fileNameColumnWidth` | `@AppStorage` | File name column width. |
| `fileColumnConfigurationRaw` | `@AppStorage` | File list column configuration. |

The active model is selected from `leftModel` or `rightModel` through `activePane`. The folder tree and preview pane follow the active model.

### 6.2 File Browser State

`FileBrowserModel` owns directory-level state and operations:

| State | Meaning |
| --- | --- |
| `currentDirectory` | Directory currently displayed by the pane. |
| `items` | Visible items after filtering and sorting. |
| `allItems` | All loaded items in the current directory. |
| `selectedItemIDs` | Selected file URLs. |
| `primarySelectedItemID` | Main target for preview and primary operations. |
| `isParentDirectorySelected` | Whether the `..` row is selected. |
| `folderTreeSelection` | Selected folder tree URL. |
| `expandedFolders` | Expanded folder tree URLs. |
| `folderChildrenCache` | Cached child folders for the folder tree. |
| `backStack` / `forwardStack` | Navigation history. |
| `clipboard` | App-local copy/move clipboard. |
| `pinnedFolders` | Pinned folder URLs in display order. |
| `availableCapacityText` | Free-space text for the current volume. |

## 7. Data Model

`FileItem` represents one file-list row. Its identity is the file URL.

| Property | Meaning |
| --- | --- |
| `url` | File or folder URL. |
| `isDirectory` | Directory flag. |
| `isHidden` | Hidden-file flag. |
| `size` | File size. |
| `modified` | Modified date. |
| `created` | Created date. |
| `kind` | Localized kind description. |
| `permissions` | POSIX permissions. |

Display properties include `name`, `mode`, `sizeText`, `kindText`, `modifiedText`, `createdText`, and `permissionsText`. Dates are displayed as `yyyy-MM-dd HH:mm:ss`.

Zip archive entries are represented as `FileItem` values with virtual URLs. These rows support listing, preview, open-by-materialization, and copy-out behavior, but do not represent directly mutable file-system locations.

`FileListColumnConfiguration` serializes column visibility and order to a `UserDefaults`-safe raw value. Invalid or incomplete values are repaired by filling in defaults.

## 8. Processing Design

### 8.1 Launch

1. `tfxApp` presents `ContentView`.
2. On macOS, `ContentView` creates `TerminalFileManagerView`.
3. `TerminalFileManagerView.init()` restores the last left and right directories from `UserDefaults`.
4. If the restored directories no longer exist, both panes start at Home. Saved Desktop, Documents, and Downloads paths are not auto-restored at launch to avoid macOS privacy prompts before the user explicitly opens those folders.
5. Each `FileBrowserModel` runs `reload()` and expands the current folder's ancestor chain in the folder tree. Subfolders start collapsed unless they are on that ancestor path.

### 8.2 Directory Loading

`FileBrowserModel.reload()` reads the current directory, builds `FileItem` values, updates free-space text, and applies filtering and sorting. Expensive work is kept away from the UI path and guarded by cancellation tokens so stale results are ignored.

Directory read failures are reported through `show(_:)`, which updates model error state for display by the screen alert.

### 8.3 Filtering and Sorting

Filtering and sorting run when `searchText`, `showHiddenFiles`, `sortKey`, or `sortAscending` changes.

Rules:

- Hidden files are excluded when hidden-file display is off.
- Non-empty search text filters by case-insensitive file name containment.
- Directories are sorted before files.
- Ties fall back to name comparison.

### 8.4 Navigation

`navigate(to:recordsHistory:updatesFolderTreeSelection:)` is the central directory navigation operation. Folder-tree clicks, file-pane activation, parent navigation, and breadcrumb path clicks all use this path. Finder aliases and directory symlinks are resolved before navigation when they point to directories. When history recording is enabled, the current directory is pushed to `backStack` and `forwardStack` is cleared. Navigation stops subfolder search, clears search text, clears selection, expands ancestors in the folder tree, and reloads the target directory.

Pinned-folder navigation uses the same directory navigation path, but keeps the active folder-tree selection on the pinned row. The regular folder tree still expands the matching ancestor path so the physical location is visible.

Back and forward are handled by `goBack()` and `goForward()`. Parent-folder navigation is handled by `goUp()` and does nothing at the root directory.

### 8.5 Selection

Single selection, Command-click extension, Shift-click range selection, Shift-arrow range selection, and mouse drag range selection are handled by `FileBrowserSelectionSupport` and `FileBrowserModel` selection methods.

The `..` row is tracked separately through `isParentDirectorySelected`. Pressing Enter while `..` is selected runs `goUp()`.

### 8.6 File Operations

| Operation | Behavior |
| --- | --- |
| New File | Prompts for a name and creates an empty file with a unique destination if needed. |
| New Folder | Prompts for a name and creates a unique destination if needed. |
| Rename | Prompts for a new name and creates a unique destination if needed. |
| Move to Trash | Uses `FileManager.default.trashItem`; it does not permanently delete files. |
| Reveal in Finder | Uses `NSWorkspace.shared.activateFileViewerSelecting`. |
| Copy Path | Writes a path string to `NSPasteboard.general`. |
| Open With | Lists candidate applications from `NSWorkspace.shared.urlsForApplications(toOpen:)` and opens the file via `NSWorkspace.shared.open(_:withApplicationAt:configuration:)`. The submenu also exposes an "Other…" picker (`NSOpenPanel` restricted to `UTType.application`). Hidden for plain folders and for `.app` bundles. |
| Open Terminal Here | Opens Terminal.app at the target directory. |
| Compress to Zip | Creates a unique zip archive from the selected items. |
| Extract Zip | Extracts a zip archive into a unique destination folder named from the archive. |

After mutating operations, affected directories and folder-tree caches are refreshed where practical.

Context menus for both file rows and the empty file-pane area follow Finder's grouping with dividers between groups: open actions (Open, Open With), destructive action (Move to Trash), manipulation (Rename, Compress, Extract, Copy/Cut/Paste), location (Reveal in Finder, Copy Path), and folder-only actions (Pin Folder, Open Terminal Here).

### 8.7 Zip Archive Browsing

Zip archives are exposed as virtual directories. Opening a real `.zip` file navigates into the archive without extracting the whole archive into the current folder.

`ZipArchiveBrowser` uses `/usr/bin/unzip` to list archive entries and materialize individual entries when needed for preview, open, or copy-out operations. Virtual archive paths are read-only. File creation, rename, move-to-trash, paste-into-archive, and archive mutation are not supported inside a zip archive.

Copying from a zip archive extracts the selected virtual entries into the paste target. Cutting from a zip archive behaves as copy because the archive is not modified.

### 8.8 Copy, Cut, and Paste

Copy and cut store URLs and operation type in `FileClipboard`, and also write URLs and the preferred operation to `NSPasteboard`. Paste first uses the app-local clipboard when available, and otherwise reads file URLs from the macOS pasteboard so files copied in Finder can be pasted into tfx. `Command + Option + V` performs move-paste for file URLs when available.

Same-name conflicts are resolved through a user prompt:

| Choice | Behavior |
| --- | --- |
| Replace | Remove the existing item and use the requested destination. |
| Keep Both | Generate a unique numbered destination. |
| Skip | Skip the current item. |
| Cancel | Stop the remaining operation. |

The app-local clipboard is cleared after a successful move operation.

### 8.9 Drag and Drop

File rows, file-pane blank space, and folder-tree rows accept `UTType.fileURL` drops. `FileBrowserDropDelegate` calls `FileBrowserModel.moveDroppedFiles(_:to:completion:)`.

File drops move files into the target directory by default. Holding Option requests copy behavior, matching Finder's copy modifier. Folder-tree internal folder movement is intentionally not supported. Pinned-folder reordering uses app-local gesture state and only updates pinned display order.

If a dropped URL requires security-scoped access, access is started only for the duration of the move.

### 8.10 Preview

Preview views are selected from the primary selected URL or from visible multi-preview items. PDF, video, and Markdown use dedicated views; other files use Quick Look. `PreviewFileInfoView` loads metadata asynchronously so metadata display does not block preview layout.

Markdown is converted to HTML with the built-in renderer and displayed in a `WKWebView`. The supported baseline syntax includes headings, paragraphs, lists, code blocks, block quotes, inline code, emphasis, and links.

Future Markdown extensions will cover ruby text, math rendering, Mermaid diagrams, custom syntax, and CSS customization through TOML configuration.

## 9. Persistence

### 9.1 UserDefaults Keys

| Key | Meaning |
| --- | --- |
| `TerminalFileManager.leftDirectory` | Last left pane directory. |
| `TerminalFileManager.rightDirectory` | Last right pane directory. |
| `TerminalFileManager.isPreviewVisible` | Preview pane visibility. |
| `TerminalFileManager.isSplitViewVisible` | Split-pane visibility. |
| `TerminalFileManager.activePane` | Active pane. |
| `TerminalFileManager.activeArea` | Active keyboard target. |
| `TerminalFileManager.folderTreeWidth` | Folder tree width. |
| `TerminalFileManager.previewWidth` | Preview width. |
| `TerminalFileManager.fileSplitRatio` | File pane split ratio. |
| `TerminalFileManager.fileNameColumnWidth` | File name column width. |
| `TerminalFileManager.fileColumnConfiguration` | Column visibility and order. |
| `TerminalFileManager.pinnedFolders` | Pinned folder list. |

Pinned folders are displayed in the saved array order. New pinned folders are appended. Drag reordering saves the reordered array.

### 9.2 Window State

`WindowFrameAutosaver` uses AppKit's `setFrameAutosaveName(_:)` with the `TerminalFileManagerWindow` name.

## 10. Keyboard Design

`KeyboardEventHandler` bridges AppKit `keyDown(with:)` into SwiftUI. Custom key handling is disabled while the search field is focused.

| Key | Behavior |
| --- | --- |
| Up / Down | Move selection in the active file pane or folder tree. |
| Shift + Up / Down | Extend file-pane selection range. |
| Left / Right | Move focus between folder tree and file panes, or between left and right panes. |
| Enter | Open selected file or navigate into selected folder. |
| Command + [ / ] | Back / Forward. |
| Command + Up | Parent folder. |
| Backspace | Parent folder. |
| Command + F | Focus search. |
| Command + N | New folder. |
| Delete | Move to Trash. |
| Command + Backspace | Move to Trash. |
| Command + C / X / V | Copy / Cut / Paste. |
| Command + Option + V | Move-paste when pasteboard file URLs are available. |
| Command + A | Select all visible items. |
| Command + R | Reload. |
| Command + Shift + T | Open Terminal.app. |
| Command + Shift + . | Toggle hidden files. |

## 11. Error Handling

Errors from file operations, directory loading, and Terminal.app launch are routed through `FileBrowserModel.show(_:)`. The model updates `errorMessage` and `isShowingError`, and `TerminalFileManagerView` displays them through an alert.

Same-name conflicts are not treated as errors. They are handled through a dedicated conflict-resolution prompt.

## 12. Safety

- Delete-like operations move files to Trash instead of permanently deleting them.
- Same-name files are never silently overwritten.
- Security-scoped resources are accessed only during the operation that needs them.
- Permission failures are shown to the user.
- No operation requests administrator privileges.

## 13. Performance Design

- Folder tree loading is lazy and does not recursively scan the whole file system.
- Folder-tree child folders are cached in `folderChildrenCache`.
- File lists use lazy rendering.
- Filtering and sorting run against loaded `allItems`.
- Slow or stale work is guarded with cancellation state.
- File operations refresh affected directories instead of forcing broad reloads where practical.
- `TFX_PERFORMANCE_LOGS=1` records timing for key operations.

## 14. Known Limitations

- Zip archive virtual directories are read-only.
- Markdown preview is a built-in renderer and is not full CommonMark.
- Large copy/move operations may still affect UI responsiveness.
- File watching is not implemented; external changes rely on reload or operation-triggered refresh.

## 15. Test Focus

### 15.1 Manual Checks

- First launch shows Home in the left and right panes.
- First launch seeds Home, Documents, and Downloads in the pinned folders section.
- Back, forward, and parent navigation keep history and file lists consistent.
- Navigating to another folder clears search text and search-field focus.
- Startup folder-tree expansion keeps subfolders collapsed except for the active ancestor path.
- Pinned-folder selection remains on the pinned row while the regular tree expands the physical ancestor path.
- Folder tree clicks, file double-clicks, and keyboard navigation produce consistent directory changes.
- Multiple selection and range selection keep preview state valid.
- Mouse drag range selection works across file-list rows.
- Copy, cut, Finder paste, app paste, and move-paste show conflict prompts for same-name items.
- Option-drag copies files while normal drag moves files.
- Finder aliases and directory symlinks navigate to their resolved directory targets.
- Trash operations update the file list and folder-tree cache.
- PDF, video, Markdown, fallback previews, and compact preview metadata switch correctly.
- Layout widths, visible panes, column settings, and pinned folders survive restart.
- File-view to folder-tree drag-and-drop highlights the target and moves files.
- Pinned-folder drag reorder changes display order only.
- Zip archives can be browsed, previewed, copied out, compressed, and extracted.

### 15.2 Automated Test Candidates

- `FileListColumnConfiguration` raw-value restoration, repair, visibility changes, and ordering.
- `FileBrowserModel` filtering, sorting, selection, and navigation history.
- Unique destination generation for same-name conflicts.
- `PreviewKind` extension and UTType detection.
- Markdown HTML escaping.
