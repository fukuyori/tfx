# Changelog

This file records notable changes to `tfx`.

Documentation is written in English by default. `README.ja.md` is maintained as the Japanese README.

## [0.6.9] - 2026-06-01

Built-in terminal and split-preview refinements.

### Added

- Added regression coverage for split-pane width calculation so split panes stay inside the file area when the preview pane is visible or hidden.
- Added regression coverage for inserting dropped paths into a running built-in terminal session.

### Changed

- Dropping files or folders directly onto the xterm.js WebView terminal now inserts shell-quoted paths, matching drops on the surrounding terminal pane.
- Dropped paths inserted into a running terminal session now include a trailing space so multiple inserted paths do not run together.
- Updated the version to `0.6.9` and the build number to `41`.

### Fixed

- Fixed the right split pane appearing behind the translucent preview pane when split view, preview, and the built-in terminal pane were visible together.
- Fixed preview-pane hiding in split view not shrinking the window by the actual visible preview width.
- Fixed the built-in terminal retaining keyboard input after the user clicked or operated another area of the file manager.

## [0.6.8] - 2026-06-01

Built-in terminal rendering.

### Changed

- Reworked the built-in terminal display to use xterm.js in a WebView backed by the app's PTY session.
- Improved built-in terminal focus handling, startup sequencing, resize handling, and monospace font resolution.
- Updated the version to `0.6.8` and the build number to `40`.

## [0.6.7] - 2026-05-29

Command-line launch polish.

### Added

- Added launch options for printing help and the app version, overriding startup layout, and forcing preview / built-in terminal pane visibility for a single launch. Each option has a short form.

### Changed

- Updated the version to `0.6.7` and the build number to `39`.

## [0.6.6] - 2026-05-29

Markdown preview polish.

### Fixed

- Markdown preview now renders pipe tables, including left, center, and right column alignment markers.

### Changed

- Updated the version to `0.6.6` and the build number to `38`.

## [0.6.5] - 2026-05-29

Built-in terminal refinements.

### Added

- Added file/folder drops onto the built-in terminal pane. Dropped paths are inserted into the command field as shell-quoted absolute paths.
- Added `exit` and `logout` handling to close the built-in terminal pane.

### Changed

- The built-in terminal pane now keeps its working directory fixed after it opens instead of following later file-pane navigation.
- Updated the version to `0.6.5` and the build number to `37`.

## [0.6.4] - 2026-05-29

Startup layout and built-in terminal polish.

### Added

- Added the first built-in terminal pane slice with toggle/focus shortcuts, command execution in the active folder, and persisted visibility/height.

### Changed

- In split view, the close button now appears even when a pane has only one tab; closing that last tab hides the pane and leaves the other pane in single-pane view.
- Added `[startup] layout = "single" | "split" | "restore"` to `config.toml` so launch can start with one pane, start in split view, or restore the previous split/tab state. `layout = "split"` also supports `rightFolder` and `rightFolders`; when omitted, the previous right-pane display is reused.
- Changed the built-in terminal default shortcuts to `cmd+option+t` and `cmd+option+shift+t` to avoid the risky backtick key position.
- Updated the version to `0.6.4` and the build number to `36`.

### Fixed

- `rightFolder = "~/Downloads"` now honors the configured folder instead of falling back to the home directory.
- Opening the built-in terminal pane now moves focus to the terminal input, terminal-pane clicks focus the input, and command completion keeps terminal focus when the terminal is active.

## [0.6.3] - 2026-05-29

Pane tabs.

### Added

- Added the first pane-tabs slice: each file pane now has a folder tab strip, new / close / previous / next tab actions, and per-pane tab persistence.
- Added a light-mode `Light graphite` color sample to the English and Japanese configuration guides.

### Changed

- Updated the version to `0.6.3` and the build number to `35`.

## [0.6.2] - 2026-05-28

Configuration documentation and shortcut polish.

### Added

- Added `docs/configuration.ja.md`, a Japanese version of the full user-editable configuration guide.

### Fixed

- `moveToTrash = "cmd+backspace"` and `moveToTrash = "cmd+delete"` now match macOS Delete / Backspace key events correctly, including Forward Delete fallback handling.

### Changed

- Updated the version to `0.6.2` and the build number to `34`.

## [0.6.1] - 2026-05-28

Configurable design tokens.

### Added

- Added user-editable `config.toml` support for compact `[font]`, `[colors]`, and `[opacity]` blocks.
- Added user-editable `config.toml` `[shortcuts]` support for overriding core toolbar and View-menu shortcuts with conflict detection.
- Added `config.toml` `[terminal]` and `[openWith]` settings for choosing the terminal app and per-extension open-with apps.
- Documented supported configuration keys and added distinct color samples for easier visual verification.
- Added inline name editing for Rename, New File, and New Folder. New items are created with a unique placeholder name, selected immediately, and removed again if the inline edit is cancelled.
- Added configurable shortcut actions for file-list context menu operations, including open, new file/folder, rename, trash, zip compression/extraction, copy/cut/paste, reveal, and copy path.

### Changed

- Replaced bundled theme switching with a single black-and-green base design that users customize through semantic color tokens.
- Unified preview background opacity with the file-list background opacity.
- Updated the version to `0.6.1` and the build number to `33`.

## [0.6.0] - 2026-05-27

Preview hardening: PDF rendered through Quick Look sandbox, markdown locked down against script injection, and text-based previews bounded by a size cap.

### Changed

- `PDFPreview` now renders the first page through `QLThumbnailGenerator`. The PDF parser, image decoders, and any embedded resources run inside Apple's sandboxed Quick Look XPC service (`com.apple.quicklook.QuickLookSatellite`); only the rendered `NSImage` returns to tfx. Embedded JavaScript and AcroForms can no longer execute, PDF link / external-file actions can no longer fire, parser exploits land in the satellite instead of in tfx, and resource attacks (huge page counts, deep nesting) are capped by the satellite's own limits. Multi-page scrolling, text selection, and link navigation — which the file-preview pane did not need — are gone.
- `MarkdownPreview` configures its `WKWebView` with `WKWebpagePreferences.allowsContentJavaScript = false`, loads the rendered HTML with `baseURL: nil`, and attaches a `WKNavigationDelegate` that only permits link activations to `http`, `https`, and `mailto` schemes (those are opened through `NSWorkspace`). `javascript:` and `data:` URLs are rejected, and relative `file://` references no longer resolve, so an attacker-controlled `.md` cannot exfiltrate local files through `<img src="../…">`-style relative loads.
- `MarkdownInlineHTML.inlineHTML` re-escapes captured link URLs as attribute values and validates the URL scheme before emitting `<a href="…">`. Links with non-allowlisted schemes drop the URL entirely and render as plain text, so injected `javascript:`-style hrefs never reach the DOM.
- `MarkdownHTMLDocument` injects a `Content-Security-Policy` meta tag (`default-src 'none'; style-src 'unsafe-inline'; img-src data:; base-uri 'none'; form-action 'none'`) on every rendered page, blocking script execution, external image and frame loads, fetch/XHR, and form submissions as defense in depth.
- New `PreviewTextLoader` enforces a 50 MB cap when reading files into memory for the raw-text, JSON, and CSV previews. Files above the cap render a localized "File too large to preview" placeholder with the actual and allowed sizes, so a runaway file no longer exhausts tfx's resident memory just by being selected.
- Updated the version to `0.6.0` and the build number to `32`.

## [0.5.9] - 2026-05-26

Clearer error alerts for file operation failures.

### Changed

- `FileBrowserModel.show(_:)` now builds the alert body by walking the `NSError` chain instead of relying on `Error.localizedDescription` alone. Recovery suggestions, underlying error messages, and the file path that the operation tried to act on (`NSFilePathErrorKey` / `NSURLErrorKey`) are appended when present. Previously a Cocoa file error showed up as just "The file couldn't be opened.", giving no hint which file or what went wrong; with the chain expanded the alert calls out the path so users can correlate it with permissions, missing sync state, or out-of-space conditions on their own.
- Updated the version to `0.5.9` and the build number to `31`.

## [0.5.8] - 2026-05-26

Pinned-folder drag and drop polish.

### Fixed

- Dropping a folder from the file pane onto the pinned-folder section no longer shows a snap-back animation after the folder is pinned.
- Reordering pinned folders now keeps the dragged folder visible, hides the original row label while dragging, and uses a stable insertion line near the original position.

### Changed

- Updated the version to `0.5.8` and the build number to `30`.

## [0.5.7] - 2026-05-23

Paste compatibility with cloud-synced files (Dropbox, iCloud Drive, OneDrive).

### Fixed

- Copy → paste from FileProvider-backed locations (notably Dropbox smart-sync) failed with "file does not exist" while drag-and-drop on the same files worked. `FileBrowserFileOperations.paste` now wraps each source URL with `startAccessingSecurityScopedResource()` / `stopAccessingSecurityScopedResource()` in the same pattern as `drop`. The cloud-placeholder hydration that drag-and-drop already triggered now also runs on paste, so copy-then-paste behaves identically to drag-and-drop for cloud-managed files.

### Changed

- Updated the version to `0.5.7` and the build number to `29`.

## [0.5.6] - 2026-05-23

Built-in color themes.

### Added

- `tfx/Theme/Theme.swift` defines a semantic token table (~30 tokens covering file pane, folder tree, status line, pane borders, split handle, and Git status badge colors).
- Four built-in themes, each built around a small canonical palette layered into a deep-to-bright background ladder so the file pane, chrome, and selection lift read as one family:
  - **Terminal Classic** — phosphor-CRT green family (`#070A07` → `#1C261C` ladder, `#4ADD7C` accent, amber/cyan/coral git signals).
  - **Solarized Dark** — Ethan Schoonover canonical palette with an added `#001820` abyss shade below `base03` so the file list sits one layer below chrome; `base3 #FDF6E3` for body text for ~14:1 contrast, `#4AABF3` for directory names.
  - **Monokai Pro (Filter Octagon)** — `#2D2A2E` base, `#FFD866` yellow as the alert accent, soft coral `#FF6188` reserved for git delete/conflict only. Replaces the original `F92672`-heavy Monokai mock-up.
  - **Dracula** — official `#282A36` background with `currentLine #44475A` selection, pink `#FF79C6` alert hue, purple/cyan navigation.
- `tfx/Theme/ThemeStore.swift` is an `@MainActor`-isolated `ObservableObject` that holds the active theme and persists the selected id under `TerminalFileManager.activeTheme`. Missing or unknown ids fall back to Terminal Classic.
- SwiftUI `EnvironmentKey` exposes the active theme via `@Environment(\.theme)`, so any view can read tokens without holding its own store reference.
- `View → Theme` submenu lets users switch between built-in themes. Switching is instant — `@Published` updates flow through the environment value to every view that reads it.

### Changed

- Migrated `FileRow`, `FilePane`, `FilePaneTitleBar`, `FilePaneStatusLine`, `FilePaneHeaderRow`, `FilePaneFileList`, `ParentDirectoryRow`, `FolderTreeRow`, `FolderTreePane`, `FolderTreeSectionHeader`, `PinnedFolderInsertionSlot`, and `SplitDragHandle` to read colors from the active theme instead of hardcoded `Color.*` literals.
- `GitFileStatus` no longer carries a `color` property; the badge color now comes from `Theme.color(for:)` so each theme can tune its Git palette.
- Updated the version to `0.5.6` and the build number to `28`.

## [0.5.5] - 2026-05-23

Git status badges and branch indicator in the file pane.

### Added

- `tfx/Git/GitStatus.swift` defines `GitFileStatus` (modified, added, deleted, renamed, untracked, conflicted, ignored) with one-character badges and color hints.
- `tfx/Git/GitStatusReader.swift` resolves the working-tree root with `git rev-parse --show-toplevel` and reads `git status --porcelain=v2 -b -z --untracked-files=normal --ignored=no` off the main thread. It runs `/usr/bin/git` with `LC_ALL=C` and `GIT_OPTIONAL_LOCKS=0` so output is stable and `.git/index.lock` is not touched.
- `FileBrowserModel.gitRepositoryStatus` is published after a fetch lands, and a per-directory work-tree-root cache (`gitRootCache`) makes navigation inside a single repository cost zero `rev-parse` calls.
- New `.gitStatus` file-list column shows the per-file badge in its status color. Column width is tightened to 10pt, just enough for a single monospaced character.
- File pane status line gains a `⎇ branch` segment when the current directory is inside a Git working copy. Detached HEAD falls back to a short SHA.

### Changed

- The default column order now includes `.gitStatus` between `.tags` and `.modified`. Existing user configurations are migrated additively so a missing entry inherits the default placement.
- Reloading a directory now triggers a parallel Git status refresh, so badges appear as soon as both the directory load and the status read complete. The directory watcher already triggers `reload()`, so external edits update badges automatically on local volumes.
- Updated the version to `0.5.5` and the build number to `27`.

## [0.5.4] - 2026-05-23

Finder-compatible tag display and editing.

### Added

- File rows now read macOS Finder tags through `URLResourceKey.tagNamesKey` and expose them through `FileItem.tags`.
- The file list has a toggleable `Tags` column. It renders tag colors as compact dots and is included in the default column set.
- File-row context menus now include a `Tags` submenu with the seven standard Finder color tags, custom tags already visible in the current directory, and `Add Custom Tag…` for assigning an arbitrary tag name to the selected items.
- Tag operations support multi-selection and write through `URLResourceValues.tagNames`, so tags added in tfx appear in Finder and tags added in Finder appear in tfx after reload.

### Changed

- Folder rows use the first colored tag to tint the folder icon, matching Finder's visual emphasis while regular files keep their standard icons.
- Updated the version to `0.5.4` and the build number to `26`.

## [0.5.3] - 2026-05-18

Directory-load performance pass, with extra attention to network-mounted volumes.

### Added

- "Loading…" hint in the file-pane status line when a directory load is still waiting for its first batch after a 500 ms grace period (Japanese: 「読み込み中…」). The hint is driven by a new `FileBrowserModel.isLoadingDirectory` flag and a delayed `Task` in `FilePaneStatusLine`, so quick local loads do not flicker the indicator. Differential reloads (existing items still on screen) skip the hint.
- `FileIconCache.prefetch(for:cancellation:)`. The metadata-prefetch worker now warms the icon cache before the file pane starts asking for icons, removing the on-main-thread `NSWorkspace.shared.icon(forFile:)` calls during the first paint.

### Changed

- `FileItem` declares an explicit `==` and `hash(into:)` that compare URL + size + modified + isHidden + isDirectory. SwiftUI's `ForEach(model.items)` diff no longer walks 13+ String properties per row, reducing per-diff cost on large directories.
- `FileItem.init` skips `FolderDisplayNameCache.shared.displayName(for:)` for plain files and uses `url.lastPathComponent` directly. The `displayName` API only meaningfully differs from `lastPathComponent` for localized system directories, so the lookup is now limited to directories. On network volumes this removes one round trip per file.
- `FileBrowserDirectoryReader.loadHeader` adds `.isAliasFileKey` to the `contentsOfDirectory(at:includingPropertiesForKeys:)` prefetch list. The per-item `resourceValues(forKeys:)` call in `FileItem.init` now reads every key it needs from the prefetched cache instead of issuing a kernel call per item.
- `volumeAvailableCapacity` is no longer fetched inline by `loadHeader`. The header reports `"-"` for free space immediately; `FileBrowserModel+Reload` schedules an asynchronous follow-up that updates `availableCapacityText` once `statvfs`-equivalent calls return. On network volumes this removes a 100–500 ms hitch from the initial paint.
- `FileBrowserModel+DirectoryWatch.startWatchingDirectory(_:)` skips installing a `DirectoryWatcher` on non-local volumes (`URLResourceKey.volumeIsLocalKey == false`). `DispatchSource.makeFileSystemObjectSource` does not receive events from remote SMB / AFP / NFS servers, so the file descriptor was held without ever firing. Manual reload via `⌘R` or post-operation refresh still works on network shares.
- `FileIconCache` is now `@unchecked Sendable`, its singleton and methods are `nonisolated`, and the underlying `NSCache` is `nonisolated(unsafe)` so the metadata-prefetch worker can warm it from a background queue.
- Updated the version to `0.5.3` and the build number to `25`.

## [0.5.2] - 2026-05-18

Keyboard / focus / swap feature work plus shortcut remapping with hover discoverability.

### Added

- Left and right file panes can be swapped with a new toolbar button (`arrow.left.arrow.right` icon, disabled when split is off), a `View → Swap Left and Right Panes` menu item, and `⌘⇧X`. Internally drives both panes through `navigate(to:)` so history records the swap and `⌘[` rolls it back. Lives in `TerminalFileManagerState.swapPanes()`.
- `Tab` cycles keyboard focus across the visible targets — folder tree → left file pane → right file pane (when split is on) → folder tree — and `Shift+Tab` cycles in reverse. Implemented through `cycleKeyboardFocus(reverse:)` in `TerminalFileManagerKeyboard`.
- `View` menu (`ViewMenuCommands`) collects the layout toggles: `Show Preview Pane (⌘P)`, `Split View (⌘\\)`, and `Swap Left and Right Panes (⌘⇧X)`. The swap entry is disabled when split is off; the swap action is also handled directly in `handleKeyEvent` so the shortcut fires reliably regardless of menu binding quirks.
- `HorizontalScrollAccess` (`Infrastructure/HorizontalScrollAccess.swift`) bridges the file-pane `ScrollView` to its underlying `NSScrollView` and registers a clamped horizontal-scroll closure on `FileBrowserModel.horizontalScrollHandler`.
- `Shortcuts` registry (`Infrastructure/ShortcutInfo.swift`) is the single source of truth for keyboard bindings used in the toolbar and `View` menu. Each entry exposes both the `KeyEquivalent` + `EventModifiers` for `.keyboardShortcut(_:)` and a `displayString` (e.g. `⌘R`, `⌘⇧X`, `⌘\\`, `⌘↑`) for hover help.
- Toolbar icons now show their keyboard shortcut alongside the label on hover (e.g. `Reload  ⌘R`, `Open Terminal here  ⌘T`). Driven by a new `quickHelp(_:shortcut:text:)` overload.
- Startup focus: on first appear the left file pane is activated and the `..` parent-folder row is pre-selected when navigation up is possible. Pending `open` requests from Finder still win and set their own focus.

### Changed

- Keyboard shortcuts remapped:
  - `⌘T` opens the terminal (was `⌘⇧T`).
  - `⌘P` toggles the preview pane (was `⌘⌥P`).
  - `⌘\\` toggles the split view (was `⌘⌥S`).
  - `⌘⇧X` swaps the left and right panes (was `⌘⌥X`).
  - Old slots (`⌘⇧T`, `⌘⌥P`, `⌘⌥S`, `⌘⌥X`) are released and intentionally unassigned.
- `Left` / `Right` arrow keys now scroll the active file list horizontally (60 pt per press, clamped to the document bounds) instead of moving keyboard focus. Focus movement is on `Tab` / `Shift+Tab` (see above).
- `TerminalFileManagerUtilityControls`, `TerminalFileManagerNavigationControls`, and `TerminalFileManagerSearchControls` apply shortcuts through the central `Shortcuts` registry, so renaming or remapping a shortcut now touches one place.
- Split-view directory sync (the other pane follows the active pane when split is enabled) moved from `setSplitViewVisible(_:)` to an `.onChange(of: isSplitViewVisible)` handler on the view body, so every entry point (toolbar toggle, menu, shortcut) produces the same behavior.
- Updated the version to `0.5.2` and the build number to `24`.

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
