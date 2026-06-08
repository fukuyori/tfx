# Changelog

This file records notable changes to `tfx`.

Documentation is written in English by default. `README.ja.md` is maintained as the Japanese README.

## [0.7.8] - 2026-06-07

Pane visibility no longer resets when the app reactivates.

### Fixed

- Terminal pane (and the other startup-controlled pane toggles — split, preview, folder tree) no longer get reset to their `config.toml` `[startup]` values every time the app receives `didBecomeActive`. SwiftUI re-creates `TerminalFileManagerView` whenever a parent re-renders, and the previous `init()` unconditionally wrote startup values to `UserDefaults` on every reinstantiation — so any pane the user toggled during the session was reverted as soon as they switched away from and back to tfx. Startup overrides now run once per process via a static `hasAppliedStartupOverrides` guard.

### Changed

- Updated the version to `0.7.8` and the build number to `51`.

## [0.7.7] - 2026-06-07

Click-to-sort for the file-list column headers.

### Added

- File-list column headers are now click-to-sort. Clicking a column whose `FileListColumn.sortKey` is non-nil (Name, Size, Kind, Modified, Created) sets that key as the active sort and resets to ascending; clicking the active column toggles ascending ↔ descending. The active column shows a `↑` / `↓` chevron next to its label. Icon, Mode, Tags, Git, and Permissions stay non-interactive because they don't map to a sortable file attribute.
- The Name header keeps its existing drag-to-resize gesture; resize and click-to-sort coexist on the same cell because the drag has a 1pt minimum-distance threshold (release without movement registers as a tap).

### Changed

- Updated the version to `0.7.7` and the build number to `50`.

## [0.7.6] - 2026-06-07

Ports of `tfx-for-windows` 0.7.6 / 0.7.7 plus a round of pane / focus / toolbar polish and matching `config.toml` keys.

### Added

- **Terminal**: advertises `COLORTERM=truecolor` so CLI tools (delta, bat, fzf, etc.) emit 24-bit RGB escapes instead of falling back to the 256-color palette.
- **Preview pane**: keyboard shortcut + tooltip for the source / rendered toggle (default `⌘⇧R`) and the "load external images" button (default `⌘⇧I`).
- **Launch**: `-g` / `--geometry` flag accepts an X11-style geometry string (`1200x800+100+50`, `-10-10` to anchor 10pt from the right/bottom edges, individual parts are optional). The same value can be set via `[startup] geometry = "..."` in `config.toml`; the command-line flag wins when both are present.
- **Terminal header**: a folder-sync button reads the foreground process group's working directory via `tcgetpgrp` + `proc_pidinfo` and navigates the active file pane there — no shell round-trip and no pollution of the terminal output.
- **Focus**: new `focusFilePane` shortcut (default `⌘⌥⇧J`), symmetric with the existing `focusTerminalPane` shortcut.
- **Configuration**: `[startup]` section in `config.toml` gains `terminal` / `preview` / `folderTree` boolean keys for initial pane visibility. Precedence remains command-line flag > config.toml > previously saved state.
- **File-list settings**: column reorder is now also possible by dragging rows with the mouse; the up/down chevrons keep working for keyboard / single-click reordering.

### Changed

- **Tab key**: cycles only between the file panes. The terminal pane is intentionally excluded — Tab in the terminal should mean shell completion. `⌘⌥⇧T` (or a click) still moves focus to the terminal explicitly.
- **Startup focus**: the file pane is the keyboard-focus target on launch. The hosted xterm webview no longer auto-focuses on init (the JS `term.focus()` call inside `requestAnimationFrame` and the `webView(_:didFinish:)` / `terminalReady` handlers now defer to the SwiftUI focus state), so the previously-saved terminal-visible layout doesn't pull focus away from the file list.
- **Toolbar**: removed the "open folder" and "pin / unpin current folder" buttons. Pinning is still available from the file-pane and folder-tree context menus.
- Updated the version to `0.7.6` and the build number to `49`.

### Fixed

- File pane's left border is now visible when the folder tree is hidden. The `RoundedRectangle` overlay was using `.stroke` (which paints half-inside, half-outside the frame); switched to `.strokeBorder` so the line stays fully inside the bounds even when the pane's leading edge sits at window x=0.

## [0.7.5] - 2026-06-04

Layout minimum-width fix, reliable address-bar editing, and Markdown preview image handling.

### Added

- Markdown previews now render local images (relative or absolute paths) by reading the file and embedding it inline as a `data:` URL. This keeps the hardened content-security policy (`img-src data:`, nil `baseURL`) intact — the `WKWebView` is never granted local-file access. Non-image references are never read, files above 25 MB are skipped, and an unresolvable reference degrades to its alt text.

### Changed

- The "load external images" button in the Markdown preview now appears only when the document actually references a remote (`http` / `https`) image, instead of for every Markdown file. Detection reads the file off the main thread and is keyed on the previewed URLs.
- Clicking the file pane's address bar now reliably enters edit mode. The editable `TextField` is mounted (via a dedicated `isEditing` state) before focus is requested on the next runloop tick, fixing the case where the click appeared to do nothing because the focus request was dropped in the same render pass.
- Updated the version to `0.7.5` and the build number to `48`.

### Fixed

- Fixed the window being draggable narrower than the toolbar/header needs, which clipped the content and pushed the width-locked folder tree off the left edge. `MainPaneSplitView.Coordinator.applyContentMinSize` now folds in the header-driven minimum width that SwiftUI's `WindowGroup` propagates into `NSWindow.contentMinSize`, so the window floor is `max(pane minimum, header minimum)` and every pane always fits its frame. This closes the §2.12.5 follow-up from the 0.7.4 `NSSplitView` migration.

## [0.7.4] - 2026-06-03

Layout refactor: pane state unification and migration to `NSSplitView` for the horizontal pane container.

### Added

- Added `LayoutPane` enum that centralizes per-pane metadata (which side, minimum/default widths, `UserDefaults` keys) so every consumer reads pane settings through one surface.
- Added `TerminalFileManagerPanes.swift` extension with a unified read/write API: `isVisible(_:)`, `storedWidth(_:)`, `displayedWidth(_:)`, `setVisible(_:_:)`, `setStoredWidth(_:_:)`, `visibilityBinding(_:)`. Toolbar / menu / keyboard toggles and the drag handler now all route through this surface.
- Added `MainPaneSplitView`, an `NSViewRepresentable` wrapping `NSSplitView` for the folder | file area | preview row. Each pane's SwiftUI content is hosted through `NSHostingView` with layer-backed clipping so SwiftUI content can never paint past its frame onto a neighbor pane.
- Added opt-in pane-layout diagnostics gated on the `TFX_PANE_LAYOUT_LOGS=1` environment variable or `Developer.showsPaneLayoutLogs` in `UserDefaults`.

### Changed

- `Tab` / `Shift + Tab` cycle keyboard focus across the working surfaces only (left file pane → right file pane → built-in terminal when visible). The folder tree is no longer a Tab stop; it remains reachable with a mouse click.
- The horizontal pane container is now `NSSplitView` instead of a SwiftUI `HStack` + per-divider drag handles. `NSSplitView`'s holding-priority model resists window-resize changes on the folder / preview panes (`.defaultHigh`) and concentrates absorption on the file area (`.defaultLow`).
- All window-level layout state (`NSWindow.contentMinSize`, the toggle-driven window grow/shrink) is now owned by exactly one place: `MainPaneSplitView.Coordinator`. The previous WindowMinSizeBinder / `applyWindowContentMinSize` / `adjustWindowForPaneToggle` / `windowWillResize` writers are removed in favor of `applyContentMinSize()` and `resizeWindowForToggleIfNeeded()` on the Coordinator.
- `splitViewDidResizeSubviews` only persists a new stored width when the frame change reflects an actual user drag — guards skip persistence during NSSplitView's mid-layout passes (frame width below the pane's hard minimum) and during forced shrinks (window too narrow to fit stored, so NSSplitView clamped down).
- Updated the version to `0.7.4` and the build number to `47`.

### Removed

- Removed `WindowMinSizeBinder.swift` (Coordinator now owns `contentMinSize`).
- Removed `NSWindowDelegate.windowWillResize` clamping from `WindowFrameAutosaver.Coordinator`; NSWindow's native `contentMinSize` enforcement is sufficient now that there is one consistent writer.

### Fixed

- Fixed folder / preview pane SwiftUI content overflowing past its allotted area when `NSSplitView` constrained the host narrower than the content's intrinsic width.
- Fixed `splitViewDidResizeSubviews` persistence corrupting stored pane widths during NSSplitView's automatic mid-layout passes (e.g. writing `0` or the pane's hard minimum back to `AppStorage` over the user's stored value).

## [0.7.3] - 2026-06-03

Layout overhaul: dynamic window minimum, folder-tree toggle, equal split, and the long-running pane-overlap fix.

### Added

- Added a folder-tree visibility toggle alongside the existing split / preview toggles (toolbar button, View menu entry, and `cmd+option+f` keyboard shortcut). Hiding the tree drops the corresponding minimum from the window content min.
- Added `WindowMinSizeBinder` so `NSWindow.contentMinSize` tracks the live combination of folder-tree, split, and preview visibility — the window can now be dragged narrow when nothing but the file pane is shown, and refuses to shrink past the configuration's true minimum.
- Added `WindowFrameAutosaver.Coordinator` `NSWindowDelegate` conformance with `windowWillResize(_:to:)` clamping, as a second layer of enforcement that survives SwiftUI's automatic `contentMinSize` propagation.
- Added `TerminalFileManagerLayout` as the single source of truth for window / pane / divider minimums (folder, file pane, preview, terminal) — every magic pixel value used to be scattered across `ContentView`, `TerminalFileManagerView`, and `TerminalFileManagerFileArea`.

### Changed

- Split view now keeps the left and right file panes at equal width at all times; the inner drag handle is gone and a non-interactive `SplitDivider` sits between them. Width adjustments happen through the folder / preview dividers or the window edge.
- Reworked `mainLayout` so the file area is the single squeeze target: `folderWidth + dividers + mainWidth + previewWidth ≡ geometry.size.width` is now a hard invariant, eliminating the long-standing symptom where the file pane drew over adjacent panes when the configured minimum exceeded the geometry width.
- Pane widths are snapped to integer points; the file area absorbs the half-point residue so every divider lands on a whole pixel.
- File rows and the column header are now left-aligned in the file pane (they were centered when the pane was wider than the rows).
- Replaced the file pane title bar's always-on `TextField` with a `Text` display that swaps to `TextField` only while editing — SwiftUI's plain `TextField` ignores `.lineLimit(1)` for sizing and was claiming the path string's natural width as the pane's intrinsic minimum.
- Removed `.fixedSize(horizontal: true)` from the file pane status line texts so the row truncates instead of forcing the entire pane wider than its allotted frame.
- Removed the path breadcrumb from the toolbar (each file pane already shows its own path) and swapped the split / preview toolbar buttons so the order matches `folder | split | preview`.
- Lowered the window vertical minimum to 300pt so a narrow short window stays usable.
- Updated the version to `0.7.3` and the build number to `46`.

### Removed

- Removed the per-side file split ratio (`fileSplitRatio`) — split view is always 50:50 now.

### Fixed

- Fixed the file pane drawing on top of adjacent panes (folder tree, preview, or sibling split pane) so each active pane's left and right borders are always visible.
- Fixed the preview pane's minimum width not being enforced when the window was at the configuration's minimum (an off-by-divider in the clamp helpers).

## [0.7.2] - 2026-06-03

Markdown preview fixes.

### Added

- Added Markdown horizontal rule rendering for `---`.
- Added Markdown ordered-list rendering and compact table delimiter handling, including compact alignment markers.

### Fixed

- Fixed Markdown files opening as raw source in the default rendered preview mode.

### Changed

- Cleaned up preview display-mode selection so rendered, raw source, and disabled preview states are explicit.
- Updated the version to `0.7.2` and the build number to `45`.

## [0.7.1] - 2026-06-02

Documentation and configuration cleanup.

### Changed

- Cleaned up preview configuration documentation and reduced duplicated design notes.
- Cleaned up preview-pane configuration handling and added compound extension matching for preview overrides.
- Updated the version to `0.7.1` and the build number to `44`.

## [0.7.0] - 2026-06-02

User-defined commands.

### Added

- Added `[[commands]]` support in `config.toml` so context menus can run user-defined commands filtered by target type, extension, selection count, and Git work tree state.
- Added command tokens such as `{path}`, `{paths}`, `{dir}`, `{name}`, `{stem}`, `{ext}`, `{cwd}`, and `{scripts}` with shell quoting for path-like values.
- Added user-defined command shortcuts using the same shortcut grammar as built-in actions.
- Added built-in terminal Output tab support for commands with `terminal = true`.
- Added English and Japanese configuration documentation for user-defined commands, including an Xcode project build/run sample.

### Changed

- User-defined command output now appears in the built-in terminal pane's Output tab, separate from the interactive Shell tab.
- Switching from Output back to Shell now synchronizes existing PTY output so the shell prompt is not lost when the terminal WebView is recreated.
- Updated the version to `0.7.0` and the build number to `43`.

## [0.6.10] - 2026-06-02

Preview-pane and window interaction refinements.

### Added

- Added title-bar double-click handling to toggle the window's display size.

### Changed

- Reworked preview-pane toggling so the window expands to the right without moving position, keeping the file list from shrinking when screen space allows.
- Cleaned up preview-pane state handling so window resizing is isolated to the preview visibility transition.
- Updated the version to `0.6.10` and the build number to `42`.

## [0.6.9] - 2026-06-01

Built-in terminal and split-preview refinements.

### Added

- Added regression coverage for split-pane width calculation so split panes stay inside the file area when the preview pane is visible or hidden.
- Added regression coverage for inserting dropped paths into a running built-in terminal session.

### Changed

- Dropping files or folders directly onto the xterm.js WebView terminal now inserts shell-quoted paths, matching drops on the surrounding terminal pane.
- Dropped paths inserted into a running terminal session now include a trailing space so multiple inserted paths do not run together.
- Markdown preview now renders image syntax, including linked badge images, while keeping external `https:` images blocked until the user presses the load-images button for the current preview.
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
