# tfx Development Roadmap

This document defines the development order for upcoming work. See `docs/detailed-design.md` for detailed design, `docs/file-manager-implementation-plan.md` for implementation history, and `docs/code-organization.md` for source layout rules.

Project documentation should be written in English by default. `README.md` is the English README, and `README.ja.md` is the Japanese README.

## 0. Principles

- Prioritize everyday responsiveness, clear selection state, and predictable drag-and-drop behavior.
- Use the folder tree for display, navigation, and choosing file drop targets.
- Do not allow moving real folders within the folder tree.
- Allow dragging files from the file view onto folders in the folder tree.
- Treat pinned folders as shortcuts. Only their order in the `PINNED` section can be changed.
- Store user-editable settings in `~/Library/Application Support/tfx/`.
- Use TOML for declarative configuration, Lua for dynamic extension, and `UserDefaults` for UI state such as window size and pane widths.
- Sandbox Lua in the initial implementation. Do not allow file mutation or external command execution.

## 1. Completed Work

### 1.1 Responsiveness and Interaction

- Selection updates immediately on single click.
- Double click first updates the selected target, then performs the open action.
- Toolbar help was changed from delayed `.help` behavior to a faster custom help display.
- Directory loading, filtering, sorting, and metadata loading were moved away from the UI path.
- Filtering, sorting, preview loading, and metadata prefetching can be cancelled.
- Large directories are displayed incrementally.
- The default name sort is the fast `Name` sort; natural sorting remains available as `Name (Natural)`.
- `TFX_PERFORMANCE_LOGS=1` enables timing logs for major operations.

### 1.2 File View and Preview

- Arrow-key movement scrolls the file list when the selected row moves outside the visible area.
- The file list shows a horizontal scrollbar when metadata columns exceed the available width.
- Multiple selected files can be shown side by side in the preview pane.
- Multi-preview loading is limited, and stale preview work is cancelled.
- Preview items can be selected and dragged.

### 1.3 Folder Tree and Pinned Folders

- Pinned folders can be reordered by drag and drop.
- Pinned folders do not expand inside the `PINNED` section.
- The pinned-folder insertion target expands during dragging to make dropping easier.
- Folder tree arrow-key navigation and scrolling were organized.
- Clicking a folder name can both expand and collapse the folder.
- Folders without subfolders do not show an expansion indicator.
- Stale folder selection highlights were reduced.
- Folder-tree child loading is queued with limited concurrency.
- Files can be dropped from the file view onto the folder tree, and the target folder is highlighted.
- Startup expands only the folder-tree ancestor path for the current folder.
- Selecting a pinned folder keeps the active selection on the pinned row while expanding the matching ancestor path in the regular tree.

### 1.4 Code Organization

- The large file manager implementation was split into feature-oriented files.
- Swift sources were organized under `App`, `TerminalFileManager`, `FileBrowser`, `FilePane`, `FolderTree`, `Preview`, and `Infrastructure`.
- File names were aligned with primary types and responsibilities.
- Source layout rules were documented in `docs/code-organization.md`.
- Documentation entry points and maintenance rules were documented in `docs/README.md`.
- Top-level README documentation references were consolidated around `docs/README.md`.

### 1.5 Archive and Context Menu Work

- Zip archives can be browsed without extracting the whole archive.
- Files can be copied from browsed zip archives into real folders.
- Context menus can create files, create folders, compress selected items to zip, and extract zip archives.
- Zip archive virtual directories are read-only.
- The file row context menu has an "Open With" submenu listing applications that can open the file, plus an "Other…" picker for choosing an arbitrary application.
- File row and empty-area context menus follow Finder's grouping with explicit dividers between Open / destructive / manipulation / location / folder-specific groups.

### 1.6 Navigation Refinement

- The header path was changed to a horizontally scrollable breadcrumb.
- Clicking a breadcrumb segment navigates directly to that folder through the normal navigation model.

### 1.7 Finder Compatibility and Search

- Home, Documents, and Downloads are seeded as pinned folders on first launch.
- Files copied or cut in tfx are written to the macOS pasteboard as file URLs.
- Files copied in Finder can be pasted into tfx.
- `Command + Option + V` performs move-paste for file URLs.
- Option-drag copies files while normal drag moves files.
- Finder aliases and directory symlinks are resolved when navigating to folders.
- `.app` bundles are opened as applications from the row context menu.
- Hidden folders appear in the folder tree when hidden-file display is enabled.
- Subfolder search supports progress reporting, incremental results, cancellation, and status-line display.
- Search text and search-field focus are cleared when navigating to another folder.

### 1.8 Selection and Preview Details

- Mouse drag range selection is available in the file list.
- The preview pane shows compact metadata for selected files and folders, including kind, size, location, dates, permissions, and code-signature status.

### 1.9 Live Refresh and Reload

- Each file pane watches its current directory through a `DispatchSource`-based `DirectoryWatcher` and reloads automatically when the contents change externally, with a ~250 ms debounce.
- Same-directory reloads (auto-refresh, manual reload, post-operation refresh) take a differential path that keeps existing items on screen while the new listing loads, and atomically swaps in the result on completion. Navigation to a different directory still uses the incremental display path.
- `FileItem` directory detection avoids an unconditional `resolvedAliasURL` + `FileManager.fileExists` pair for non-alias entries, cutting per-item syscalls during directory loads.

### 1.10 Preview Source Toggle and UI Polish

- Markdown and HTML previews can be switched between rendered and raw-source views through an eye-icon toggle at the top of the preview pane. State is persisted in `Preview.showsRawSource`.
- The per-file info strip is suppressed while a Markdown or HTML preview is rendered, so the rendered output takes the full pane.
- A reusable `View.cursor(_:)` helper backs `resizeLeftRight` cursor feedback on pane-boundary drag handles (`SplitDragHandle`) and on the NAME-column resize handle.

### 1.11 CSV / JSON / Text Previews

- CSV / TSV files are parsed in-app and rendered as a monospaced scrollable table (`CSVPreview` + `CSVParser`). The first row is treated as a header.
- JSON files are pretty-printed in a monospaced `NSTextView` (`JSONPreview`), falling back to raw bytes when parsing fails.
- The Source / Rendered toggle now also covers CSV / TSV and JSON. The file-info strip is hidden in rendered mode for these kinds, matching the Markdown / HTML behavior.
- `.toml`, `.yaml`, `.yml`, `.ini`, `.cfg`, `.conf`, `.log`, `.txt`, and `.env` use the built-in `RawTextPreview` instead of Quick Look, so previews work even when Quick Look has no generator for the extension. These do not participate in the toggle.
- `RawTextPreview` and `JSONPreview` share the read-only monospaced `NSScrollView` configuration through `MonospacedTextPreviewView`.

### 1.12 Drag-and-Drop and Context Menu Cleanup

Closes the short-term work that was tracked as section 2.2.

- File-view to folder-tree drops are wired through `FileBrowserDropDelegate` with target highlighting (carried over from 1.3).
- Folder-tree rows expose no drag source, so folder-to-folder movement inside the tree is structurally impossible.
- Pinned-folder reordering remains a display-order-only behavior driven by a local `DragGesture`; no file-system mutation.
- Drop highlights are cleared on every exit path: `dropExited`, `performDrop`'s `defer`, and navigation through `clearDropTargetDirectory(nil)`.
- Right-clicking a file row activates the pane and updates the selection before the menu opens, matching Finder.
- Each area now has a single context menu: file rows always use `FileItemContextMenu`, the file-pane background uses `EmptyFileAreaContextMenu`, and folder-tree rows use `FolderTreeRowContextMenu` with the same Finder grouping as file rows.

## 2. Quality, Distribution, and Compatibility

Cross-cutting constraints that any feature work has to respect. These are not feature deliverables in themselves; they exist so the feature sections below can refer to them.

### 2.1 Performance Targets

Initial budgets. They will be revised once measurement instrumentation (section 6) gives us real numbers from typical hardware and real folders.

| Path | Target |
| --- | --- |
| Cold launch on Apple Silicon | < 1.0 s |
| Directory load — 1k items | first paint < 100 ms, complete < 300 ms |
| Directory load — 10k items | first paint < 200 ms, complete < 1.0 s |
| External change → auto-refresh visible | < 350 ms (250 ms watcher debounce + load) |
| Typical session memory | < 200 MB |

### 2.2 Reliability and Quality Gates

- No data loss from drag / drop / move operations. Same-name conflicts must surface the resolver.
- Permission and read errors are surfaced through `show(_:)`, never swallowed.
- CI build + tests must pass before any release tag is cut.
- Every new public mutator on `FileBrowserModel` ships with at least one focused test.
- No new SwiftUI or Swift compiler warnings introduced.

### 2.3 Distribution Plan

| Phase | Channel | Notes |
| --- | --- | --- |
| A (current) | Local Xcode builds | Development only. |
| B | TestFlight beta | Crash reports through App Store Connect; small known-tester pool. |
| C | Direct download via release page | Developer ID signed + notarized; updates delivered through Sparkle (section 3.3). |
| D (optional) | Mac App Store | Requires `ENABLE_APP_SANDBOX = YES`; large adjustment, not committed. |

Decision points:

- TestFlight and direct download are not mutually exclusive — TestFlight for beta cycles, direct download with Sparkle for stable. Plan for both.
- Mac App Store is blocked today by the disabled App Sandbox. Revisit only if MAS reach becomes important enough to justify sandboxing.

### 2.4 macOS and Hardware Compatibility

- Deployment target: macOS 26.4 during development. Re-evaluate lowering to N-1 when distribution starts (section 2.3 phase B).
- Apple Silicon native. No Intel build is planned at this deployment target.
- Public-release support window: current macOS plus one prior major version, applied from the first non-beta release onward.
- Locales: English (source) and Japanese are actively maintained. Additional locales accepted by PR with translation review.

### 2.5 Data and Configuration Migration

- `UserDefaults` schema is additive: new keys ship with defaults; existing keys are never removed without an explicit migration step.
- All persisted `UserDefaults` keys remain documented in `docs/detailed-design.md` §9.1.
- Future TOML configuration files (section 4.1) carry a top-level `version = N` field. The loader migrates older versions forward and keeps at least one prior version's migration code on hand.
- Pinned folders, window state, and other user data are read-merge-write: never destructively rewritten on load when fields are missing.

## 3. Short-Term Work

### 3.1 Test Foundation and CI

Goal:

- Stand up a test suite and continuous integration so future feature work can be reviewed safely.

Tasks:

- Add a Swift Testing target for unit tests.
- Cover pure logic first: `CSVParser`, `FileBrowserFilterSort`, `FileBrowserNavigationHistory`, `FileBrowserSelectionSupport`, `FileBrowserDirectoryState`.
- Add focused tests for `FileBrowserModel` mutators: selection updates, navigation history, the reload differential path.
- Wire up a GitHub Actions workflow that runs `xcodebuild build` plus tests on a macOS runner for every push and PR.
- Document the test-running command in `docs/code-organization.md` (or a new `docs/contributing.md`).

Done when:

- `xcodebuild test` runs all tests successfully.
- CI runs on every push to `main` and on every PR.
- At least one test exists per file in the "pure logic" list above.

### 3.2 Pane Tabs

Goal:

- Let each file pane carry multiple folders at once and switch between them with the keyboard.

Tasks:

- Model: introduce a per-pane tab container that owns multiple `FileBrowserModel` instances and tracks the active one.
- UI: horizontal tab strip above each file pane. Click to switch; `⌘W` closes; `⌘T` opens a new tab pointed at the active folder; `⌘⇧[` / `⌘⇧]` cycles.
- Persistence: per-pane tab list (paths + active index) under new `UserDefaults` keys, following the additive policy in §2.5.
- Folder tree, preview, and search controls follow the active tab.
- Future enhancement: drag tabs between panes (not required for the first cut).

Done when:

- Each pane can hold multiple tabs that survive relaunch.
- Closing the last tab in a pane is handled deterministically (decide between "hide pane" and "empty-tab placeholder" during design).
- Keyboard shortcuts work for new / close / next / previous tab.

### 3.3 Sparkle Auto-Update

Goal:

- Make direct distribution (section 2.3 phase C) viable by enabling in-app updates.

Tasks:

- Integrate Sparkle 2 via Swift Package Manager.
- Generate an Ed25519 signing keypair. Ship the public key in the app; keep the private key offline for release signing.
- Define the appcast feed URL and channel layout (stable / beta).
- Add a "Check for Updates…" menu item that calls into Sparkle.
- Add a user-visible toggle for automatic checks (`SUEnableAutomaticChecks`).

Done when:

- A test release pushed through the appcast can be installed in-app.
- The appcast feed, signing process, and channel layout are documented.

## 4. Mid-Term Work

Ordered roughly by dependency. Several entries (terminal pane, Git status, Tags, permissions) can run independently and may be scheduled around the configuration / theming track.

### 4.1 Configuration Foundation

Goal:

- Introduce user-editable configuration that the later mid-term items can build on.
- Provide the foundation for themes, file-type rules, shortcuts, Markdown extensions, and Lua extensions.

Configuration directory:

```text
~/Library/Application Support/tfx/
```

Planned layout:

```text
config.toml
themes/*.toml
filetypes.toml
shortcuts.toml
scripts/*.lua
markdown/preview.css
```

Tasks:

- Pick and integrate a TOML parser.
- Define `version = N` at the top of every TOML file; carry forward at least one prior version's migration code (§2.5).
- Built-in defaults remain in code; TOML overrides are merged on top.

Done when:

- The configuration directory is created on demand.
- The app runs with built-in defaults when no configuration files exist.
- TOML loading errors are surfaced clearly to the user.

### 4.2 Built-in Color Themes

Goal:

- Ship 3-4 built-in themes before user-defined TOML themes (§4.7), so users get visible variety without waiting for the full configuration foundation.

Tasks:

- Define a theme token table (file pane, folder tree, selected rows, drop targets, active borders, status lines, preview backgrounds).
- Implement 3-4 hardcoded themes (e.g., terminal-classic, light, solarized-ish, monokai-ish).
- Add a "Theme" menu / settings entry to switch between built-in themes.

Done when:

- Switching themes updates the main UI consistently and immediately.
- Missing color tokens in a theme fall back to the default.

### 4.3 Built-in Terminal Pane

Goal:

- Add a collapsible shell pane at the bottom of the file-manager window. Aligns with the project's terminal-inspired identity (section 0).

Tasks:

- Embed a PTY-backed terminal view (evaluate SwiftTerm or a similar library before writing custom).
- Default shell from `$SHELL`; working directory follows the active pane's current folder (configurable, default on).
- Commands: toggle terminal pane, focus terminal pane, run command on selected files.
- Persistence: visibility, height, font size.

Done when:

- A terminal pane can be toggled on / off through a menu item and a keyboard shortcut.
- Active pane folder changes drive a `cd` in the terminal when the follow-folder setting is on.

### 4.4 Git Status Indicators

Goal:

- Surface Git status next to files inside a Git working copy.

Tasks:

- Detect the Git root for the current directory; cache results.
- Run `git status --porcelain=v2 --untracked-files=normal` on a background queue when entering a Git working copy and on `DirectoryWatcher` events.
- Decorate file rows with status badges: `M` modified, `A` added, `?` untracked, `D` deleted, `!` ignored.
- Display the current branch in the title bar / status line.

Done when:

- File rows in a Git working copy display accurate status badges that update on external changes.
- Non-Git folders incur no `git` cost.

### 4.5 macOS Tags

Goal:

- Display and edit Finder-compatible color tags.

Tasks:

- Read tags through `URLResourceKey.tagNamesKey`.
- Optional tag-color column in the file list (toggleable through existing column settings).
- Context-menu "Tags…" submenu listing the user's existing tags plus an "Add Tag…" picker.
- Multi-selection batch tagging.

Done when:

- Tags applied in tfx appear in Finder, and tags applied in Finder appear in tfx.
- The tag column is toggleable through the existing file-list column settings.

### 4.6 Permissions and Owner Editing

Goal:

- Provide POSIX permission and owner / group editing through the UI.

Tasks:

- "Get Info" sheet showing chmod-style permission bits and current owner / group.
- Permission edits apply through `FileManager.setAttributes(_:ofItemAtPath:)`.
- Owner / group edits prompt for admin credentials when elevation is required (privileged helper or `AuthorizationServices`).
- Failures (permission denied, requires admin, etc.) surface through `show(_:)`.

Done when:

- A user can change permissions on a file they own without elevation.
- Owner / group changes prompt for credentials when needed and roll back cleanly on cancel / failure.

### 4.7 Theme Customization via TOML

Builds on §4.1 and §4.2. Maps the TOML theme files to the same color tokens used by the built-in themes.

Done when:

- A user-defined `themes/*.toml` file can override built-in themes and appears in the theme picker.
- Missing tokens fall back to the active built-in default.

### 4.8 Shortcut Organization

Goal:

- Centralize shortcut definitions and prepare for user-defined shortcuts.

Tasks:

- Define an action list with stable identifiers.
- Manage default shortcuts centrally (single source of truth).
- Define the `shortcuts.toml` override format.
- Detect shortcut conflicts (both default-vs-user and user-vs-user).

Done when:

- Existing shortcuts can be reviewed from one action definition list.
- User-defined shortcut conflicts are reported clearly.

### 4.9 Extension-Based Behavior

Goal:

- Allow extension-specific open behavior, preview behavior, and context-menu behavior.

Tasks:

- Define extension rules in `filetypes.toml`.
- Define precedence between built-in behavior, TOML rules, and Lua hooks (§5.1).
- Fall back to current built-in behavior for unknown extensions.

Done when:

- The default preview / open behavior can be changed per extension.
- Rule precedence is explicit and documented.

## 5. Long-Term Work

### 5.1 Lua Extension API (Incremental)

Goal:

- Allow extension behavior, shortcuts, and Markdown conversion to be customized with Lua, starting from the smallest useful API surface.

Phases:

1. **Read-only inspection.** A Lua script reads current folder / selection / extension info and returns a value (filter, label, classification).
2. **Markdown post-processing.** Lua filters Markdown source before conversion or HTML after conversion. Output is sanitized before being shown.
3. **Shortcut bindings.** Lua callbacks bound to shortcut TOML actions.
4. **Open / preview hooks.** Lua decides how a file is opened or previewed, within the sandbox.

Initial restrictions (preserved across all phases):

- No file mutation.
- No external command execution.
- Read-oriented APIs only; the host returns sanitized data.
- Long-running scripts can be detected and stopped.

Done when:

- Each phase has its own "done when" gate; Phase 1 ships before Phase 2 begins.
- Lua script errors never crash the app.

### 5.2 Markdown Preview Extensions

Goal:

- Let users extend Markdown preview behavior.

Targets:

- Ruby text
- KaTeX / MathJax math rendering
- Mermaid diagrams
- Custom inline syntax
- Custom block syntax
- CSS customization

Planned TOML:

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

Done when:

- CSS can be loaded from configuration.
- Ruby, math, and Mermaid display settings can be loaded from TOML.
- Unsafe HTML and script handling is explicitly controlled.

Priority: lower than §5.1. Address once §4.1 lands and there is concrete user demand, since the engineering cost (CSP, sandboxing of `WKWebView` content, external library bundling) is significant.

## 6. Performance Measurement (On-Demand)

Performance work is not on the main timeline anymore — auto-refresh and the differential reload landed in 1.9, and no specific user-facing slowness is currently open. This section exists as a reusable checklist rather than a queued task.

When user-reported slowness or measurement reveals a hotspot:

- Reproduce with `TFX_PERFORMANCE_LOGS=1`.
- Compare timings against the §2.1 targets.
- Land the fix with a regression test where feasible.
- Consider a developer setting for enabling performance logs from the UI if the workflow is repeated often.

## 7. Documentation Work

Tasks:

- Keep `docs/detailed-design.md` aligned with the current folder tree and drag-and-drop behavior.
- Keep `docs/file-manager-implementation-plan.md` current.
- Keep `README.md` and `README.ja.md` aligned.
- Keep `docs/README.md` aligned with the documentation set.
- Add sample configuration files once §4.1 lands.
- Convert remaining Japanese documentation to English, except for `README.ja.md`.
- Maintain a contributor-facing entry point that covers test running, CI expectations, and release process once §3.1 and §3.3 land.

Done when:

- The implementation plan, detailed design, and READMEs do not contradict each other.
- Users can start basic customization from the configuration examples.
- New contributors can run tests and understand the release process from the documentation.
