# Changelog

This file records notable changes to `tfx`.

Documentation is written in English by default. `README.ja.md` is maintained as the Japanese README.

## [0.5.1] - 2026-05-18

Closes roadmap §2.1 (Test Foundation and CI) and §2.2 (Performance Measurement Infrastructure). Both move into Completed Work as §1.13 and §1.14 in the next roadmap revision.

### Added

- New `tfxTests` target (Swift Testing) backed by a `PBXFileSystemSynchronizedRootGroup`. 50 unit tests cover the pure-logic types (`CSVParser`, `FileBrowserFilterSort`, `FileBrowserNavigationHistory`, `FileBrowserSelectionSupport`, `FileBrowserDirectoryState`) and `FileBrowserModel` mutators (selection, navigation history, context-menu selection, parent-directory selection, pruning).
- `.github/workflows/build.yml` runs `xcodebuild build` and `xcodebuild test` on `macos-latest` for every push to `main`, every pull request, and on manual dispatch. Concurrency cancels superseded runs. On failure the workflow uploads `test-results.xcresult` and the raw build / test logs as 7-day artifacts.
- `PerformanceTrace` honors a `UserDefaults`-backed flag (`Developer.showsPerformanceLogs`) in addition to the existing `TFX_PERFORMANCE_LOGS=1` environment variable. The env var still wins so CI / scripted runs do not have to flip the in-app toggle.
- `Developer` menu in the macOS menu bar exposes a `Show Performance Logs` toggle (Japanese: 「パフォーマンスログを表示」) backed by the new `DeveloperMenuCommands`.
- `tfxTests/PerformanceBenchmarks.swift` adds five informational benchmarks for §3.1 scenarios: `FileItem` creation ×1k / ×5k, `loadHeader` 1k items, `filterAndSort` 1k items, `filterAndSort` 1k items + query. Timings are printed via `print` and not asserted; comparison is manual against rolling baselines.
- New `docs/contributing.md` documents local build and test commands, the `tfxTests/` layout convention, performance benchmark instructions, CI expectations, code-style rules, and a placeholder release-process section.

### Fixed

- `CSVParser` now correctly handles Windows-style CRLF line endings. Swift collapses `\r\n` into a single grapheme cluster during `Character` iteration, so the original `case "\n", "\r":` did not match CRLF input. Surfaced by the new test suite.

### Changed

- `docs/development-roadmap.md` was restructured: item numbers now reflect recommended execution order, with §1.13 / §1.14 added for the work above and the remaining §2.x items renumbered into priority order.
- Updated the version to `0.5.1` and the build number to `23`.

## [0.5.0] - 2026-05-16

This release closes out the short-term drag-and-drop / context-menu cleanup tracked in roadmap section 2.2. File movement, pinned-folder ordering, and folder-tree navigation now have a single clear path each, and the per-area context menus follow consistent Finder-grouped layouts.

### Added

- Right-clicking a file row now activates the pane and updates the selection before the context menu opens (`FileRowInteractionView.rightMouseDown` calls `activate()` and `selectForContextMenu(item)`). This matches Finder: the right-clicked row is reflected in the visual selection, the menu actions act on it, and an existing multi-selection that includes the row is preserved.

### Changed

- File-row context menus now always show `FileItemContextMenu`. The earlier conditional that swapped in `EmptyFileAreaContextMenu` when nothing was selected has been removed. Empty file-pane space is still served by the pane-level `EmptyFileAreaContextMenu`, so the two menus no longer overlap.
- `FileItemContextMenu` button bodies are simpler: the redundant `activate()` and `selectForContextMenu(item)` calls have been removed now that `rightMouseDown` sets up the same state. Only `Paste Here` still calls `activate()` because it does not depend on selection.
- Folder-tree row context menu (`FolderTreeRowContextMenu`) now uses the same Finder grouping introduced for file rows in 0.4.3: Open → Reveal in Finder / Copy Path → Pin Folder / Open Terminal Here, with explicit dividers between groups.
- Updated the version to `0.5.0` and the build number to `22`.

## [0.4.6] - 2026-05-16

### Added

- CSV / TSV preview (`CSVPreview`): the file is parsed with a built-in RFC 4180-ish `CSVParser` (handles quoted fields, escaped `""`, embedded newlines, and CRLF / LF line endings) and rendered as a scrollable monospaced table with the first row styled as a header. Falls back to status text on empty or unreadable files.
- JSON preview (`JSONPreview`): the file is pretty-printed with `JSONSerialization` (`.prettyPrinted`, `.sortedKeys`, `.withoutEscapingSlashes`) into the same monospaced `NSTextView` used by `RawTextPreview`. Falls back to the raw bytes when JSON parsing fails.
- Source / Rendered toggle now also covers CSV / TSV and JSON. The eye-icon button switches between the table / pretty-printed view and `RawTextPreview`, and the file-info strip is suppressed in rendered mode.
- Plain-text preview kind: `.toml`, `.yaml`, `.yml`, `.ini`, `.cfg`, `.conf`, `.log`, `.txt`, and `.env` are now routed directly through `RawTextPreview` instead of relying on Quick Look's generator. The toggle is intentionally hidden for these because there is no separate rendered form.
- Shared factory `MonospacedTextPreviewView.makeScrollView()` for the read-only monospaced `NSScrollView` used by `RawTextPreview` and `JSONPreview`.

### Changed

- `PreviewKind` gained `.csv`, `.json`, and `.text` cases; `DeferredPreviewPlaceholder` now uses `tablecells`, `curlybraces`, and `doc.plaintext` for their queued-state icons.
- Updated the version to `0.4.6` and the build number to `21`.

## [0.4.5] - 2026-05-16

### Added

- Source/Rendered toggle for Markdown and HTML previews. A small eye-icon button at the top of the preview pane switches between the rendered view (the existing `WKWebView` Markdown renderer or Quick Look for HTML) and a new `RawTextPreview` that shows the file contents in a read-only monospaced `NSTextView`. The button is shown only when the current preview contains a Markdown or HTML file. Toggle state is persisted in `Preview.showsRawSource`.
- `View.cursor(_:)` helper in `Infrastructure/UIInfrastructure`. Drives `NSCursor.push` / `.pop` via `onHover` and respects any `contentShape` already applied to the view.

### Changed

- The preview pane's file-info strip (`PreviewFileInfoView`) is suppressed while a Markdown or HTML file is displayed in rendered mode, so the rendered content takes the full pane. The info strip reappears in source mode and for all other file kinds.
- The toggle button uses background color to convey state: accent-filled with a white eye when rendered (parse on), transparent with a secondary-tinted eye when source (parse off).
- Pane-boundary drag handles (`SplitDragHandle`) and the file-list NAME column resize handle now show the `resizeLeftRight` cursor while the pointer is over their hit area.
- Updated the version to `0.4.5` and the build number to `20`.

## [0.4.4] - 2026-05-16

### Added

- Auto-refresh: each file pane now updates automatically when its current directory changes externally (Finder, shell, other apps). Backed by a `DispatchSource`-based `DirectoryWatcher` per pane with a ~250 ms debounce. Zip-archive virtual paths and missing directories are skipped. Watcher wiring lives in `FileBrowserModel+DirectoryWatch`.

### Changed

- Same-directory reloads (manual reload, auto-refresh, post-operation refresh) no longer blank the file pane. Existing items stay on screen while the new listing loads in the background, and the model atomically swaps in the result once the final batch arrives. Navigation to a different directory still uses the incremental display path.
- `FileItem` directory detection skips an unconditional `resolvedAliasURL` + `FileManager.fileExists` pair when the entry is not a Finder alias, removing ~2 syscalls per non-directory file during directory loads.
- Updated the version to `0.4.4` and the build number to `19`.

## [0.4.3] - 2026-05-12

### Added

- "Open With" submenu in the file row context menu, listing applications that can open the selected file, plus an "Other…" picker for choosing an arbitrary application. Powered by `NSWorkspace.urlsForApplications(toOpen:)` and `NSWorkspace.open(_:withApplicationAt:configuration:)`. The submenu is hidden for plain folders and for `.app` bundles, matching Finder.

### Changed

- Reordered the file row and empty-area context menus to follow Finder's grouping with explicit dividers: Open / Open With → Move to Trash → manipulation (Rename, Compress, Copy/Cut/Paste) → Reveal in Finder / Copy Path → folder-only actions (Pin Folder, Open Terminal Here).
- Updated the version to `0.4.3` and the build number to `18`.

## [0.4.2] - 2026-05-11

### Added

- The path field at the top of each file pane is now editable; press Return to navigate to the typed path (supports `~/` expansion).

### Changed

- Removed the "LEFT" / "RIGHT" badges from the file pane title bar; the active pane is still distinguishable by background and path color.
- Removed the "ICO" header label from the icon column.
- Updated the version to `0.4.2` and the build number to `17`.

## [0.4.1] - 2026-05-11

### Changed

- Removed file-action and selection-action toolbar buttons (new folder, rename, move to trash, copy, cut, paste, reveal in Finder, select all, copy current path) in favor of context menus and keyboard shortcuts.
- Show the empty-area context menu when right-clicking a file row while nothing is selected.
- Skip privacy-protected metadata reads (Desktop, Documents, Downloads) in the preview pane to avoid triggering TCC prompts on hover.
- Separated the pinned-folders section in the folder tree into its own scroll area so it stays visible when the folder tree is scrolled.
- Updated the version to `0.4.1` and the build number to `16`.

### Added

- Press Escape in the file list to clear the current selection.

## [0.4.0] - 2026-05-10

### Added

- Japanese localization for the user interface; macOS automatically displays Japanese when the system language is Japanese and English otherwise.
- `Localizable.xcstrings` string catalog with full English/Japanese translations.

### Changed

- Updated the version to `0.4.0` and the build number to `15`.

## [0.3.2] - 2026-05-09

### Fixed

- Start mouse range selection only from blank file-list space.
- Treat dragging from a file row as normal file drag and drop instead of range selection.

### Changed

- Updated the version to `0.3.2` and the build number to `14`.

## [0.3.1] - 2026-05-09

### Fixed

- Avoid automatically restoring Desktop, Documents, and Downloads paths at launch to reduce macOS privacy prompts.
- Restore protected user-folder paths by opening their safe parent folder instead.
- Avoid privacy prompts while loading default pinned folders by not probing protected folders during startup.
- Rebuild folder-tree cache from the folder-tree reload button.
- Render the folder tree with a non-lazy stack to avoid intermittent blank tree contents.

### Changed

- Updated the version to `0.3.1` and the build number to `13`.
- Use Home as the default folder for both panes when no previous safe folder can be restored.

## [0.3.0] - 2026-05-09

### Fixed

- Seed first-run pinned folders with Home, Documents, and Downloads.
- Read file URLs from the macOS pasteboard so items copied in Finder can be pasted into tfx.
- Write selected file URLs to the macOS pasteboard when copying or cutting in tfx.
- Support `Command + Option + V` as move-paste for copied file URLs.
- Support Option-drag copying for file drops.
- Support mouse drag range selection in the file list.
- Show hidden folders in the folder tree when hidden files are enabled.
- Resolve Finder alias files when opening or navigating to folder aliases.
- Open `.app` bundles from the file-row context menu as applications instead of navigating into the bundle.
- Treat directory symlinks such as Dropbox and Google Drive home-folder links as folders in the file list.
- Resolve directory symlinks to their target paths before navigating, so CloudStorage links open inside tfx.
- Clear search text and search-field focus when navigating to another folder.
- Prevent keyboard handling from stealing focus back from the search field after a single click.

### Added

- Added compact preview metadata for selected files and folders, including kind, size, location, dates, permissions, and code-signature status.

### Changed

- Updated the version to `0.3.0` and the build number to `12`.
- Removed duplicate subfolder-search status text from the header; search progress remains in the file-pane status line.

## [0.2.9] - 2026-05-07

### Added

- Added Enter-triggered subfolder search with progress reporting and cancellation.

### Fixed

- Skipped unreadable folders during subfolder search without interrupting the search.
- Stopped subfolder search when navigating folders.
- Prevented search status text from wrapping in the status line.
- Prevented folder tree refreshes caused by subfolder search result updates.

### Changed

- Updated the version to `0.2.9` and the build number to `11`.

## [0.2.8] - 2026-05-01

### Fixed

- Fixed moving real zip archive files to Trash.

### Changed

- Updated the version to `0.2.8` and the build number to `10`.

## [0.2.7] - 2026-05-01

### Added

- Added clickable breadcrumb navigation for the current path in the header.

### Changed

- Updated the version to `0.2.7` and the build number to `9`.
- Split view now opens the newly visible pane at the same folder as the currently visible pane.
- Reorganized README documentation references around `docs/README.md`.
- Updated design and planning documentation for breadcrumb path navigation.

## [0.2.6] - 2026-05-01

### Fixed

- Fixed the folder tree disappearing when split-pane mode is enabled.

### Changed

- Updated the version to `0.2.6` and the build number to `8`.

## [0.2.5] - 2026-04-29

### Changed

- Updated the version to `0.2.5` and the build number to `7`.
- Updated user and developer documentation for zip browsing, archive actions, New File, Backspace navigation, and delete-key alternatives.
- Added `docs/README.md` as the documentation index.

## [0.2.4] - 2026-04-27

### Changed

- Updated the version to `0.2.4` and the build number to `6`.

## [0.2.3] - 2026-04-27

### Changed

- Updated the version to `0.2.3` and the build number to `5`.

## [0.2.2] - 2026-04-27

### Added

- Added `scripts/build_release_pkg.sh` for Developer ID signed release pkg builds.

### Fixed

- Fixed file-view icons by caching AppKit file icons per path and rendering them as original images.

### Changed

- Updated the version to `0.2.2` and the build number to `4`.

## [0.2.1] - 2026-04-27

### Changed

- Updated the version to `0.2.1` and the build number to `3`.
- Reorganized Swift sources into feature directories: `App`, `TerminalFileManager`, `FileBrowser`, `FilePane`, `FolderTree`, `Preview`, and `Infrastructure`.
- Renamed files to better match their primary types and responsibilities.
- Added `docs/code-organization.md` with source layout and naming rules.
- Converted project documentation to English by default.
- Kept `README.ja.md` as the Japanese README.
- Updated README project structure sections for the new source layout.

## [0.2.0] - 2026-04-27

### Added

- Added drag reordering for pinned folders.
- Added an expanded insertion target while dragging pinned folders to make drops easier.
- Added file drag-and-drop from the file view to the folder tree.
- Added drop-target highlighting for folders.
- Added a context menu for blank space in the file view.
- Added side-by-side previews for multiple selected files.
- Added preview-item selection and drag support.
- Added keyboard-selection scrolling for the folder tree and file view.
- Added horizontal scrolling for the file list.
- Added `TFX_PERFORMANCE_LOGS=1` timing logs.
- Added `docs/detailed-design.md`.
- Added `docs/development-roadmap.md`.

### Changed

- Updated the version to `0.2.0` and the build number to `2`.
- Improved click, double-click, and hover responsiveness.
- Changed double-click behavior so the target selection updates before opening.
- Made toolbar help display more immediate.
- Moved directory loading, filtering, sorting, and metadata loading away from the UI path.
- Changed large-directory loading to display results incrementally.
- Made filtering, sorting, preview loading, and metadata prefetching cancellable.
- Changed the default name sort to the fast `Name` sort while keeping natural sorting as `Name (Natural)`.
- Queued folder-tree child loading and limited concurrency.
- Changed folder-name clicks to both expand and collapse folders.
- Changed pinned folders so they do not expand in the `PINNED` section.
- Changed file operation refreshes to use incremental updates where practical.
- Updated README feature descriptions and project structure.
- Updated the implementation plan to match the current implementation.

### Fixed

- Fixed pinned-folder drops not updating the order.
- Reduced flickering while dragging pinned folders.
- Fixed stale folder selection highlights that could remain after selecting another folder.
- Fixed expansion indicators appearing on folders without subfolders.
- Fixed cases where files in the file view could not be dragged.
- Fixed file-view keyboard selection moving outside the visible area without scrolling.
- Reduced stale preview work after selection changes.

### Planned

- Subfolder search.
- Configuration foundation.
- Color schemes.
- Shortcut organization.
- Markdown preview extensions.
- Extension-based behavior.
- Lua extension API.

## [0.1.0] - Initial

### Added

- Added the initial terminal-style macOS file manager.
- Added folder tree, split file panes, and preview pane.
- Added PDF, video, Markdown, and Quick Look previews.
- Added New Folder, Rename, Move to Trash, Reveal in Finder, and Copy Path.
- Added Copy, Cut, Paste, and same-name conflict handling.
- Added search, hidden-file display, and sorting.
- Added multiple selection, range selection, and keyboard operations.
- Added opening Terminal.app at the current folder.
