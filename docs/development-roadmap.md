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

- File-view to folder-tree drops are wired through `FileBrowserDropDelegate` with target highlighting.
- Folder-tree rows expose no drag source, so folder-to-folder movement inside the tree is structurally impossible.
- Pinned-folder reordering remains a display-order-only behavior driven by a local `DragGesture`; no file-system mutation.
- Drop highlights are cleared on every exit path: `dropExited`, `performDrop`'s `defer`, and navigation through `clearDropTargetDirectory(nil)`.
- Right-clicking a file row activates the pane and updates the selection before the menu opens, matching Finder.
- Each area now has a single context menu: file rows always use `FileItemContextMenu`, the file-pane background uses `EmptyFileAreaContextMenu`, and folder-tree rows use `FolderTreeRowContextMenu` with the same Finder grouping as file rows.

### 1.13 Test Foundation and CI

- Swift Testing target (`tfxTests`) backed by a `PBXFileSystemSynchronizedRootGroup`. 50 tests cover the pure-logic types (`CSVParser`, `FileBrowserFilterSort`, `FileBrowserNavigationHistory`, `FileBrowserSelectionSupport`, `FileBrowserDirectoryState`) plus `FileBrowserModel` mutators (selection, navigation history, context-menu selection, parent-directory selection, pruning).
- A `CSVParser` CRLF bug was caught and fixed by the new tests: Swift collapses `\r\n` into a single grapheme cluster during `Character` iteration, so the original `case "\n", "\r":` did not match Windows-style line endings.
- GitHub Actions workflow `.github/workflows/build.yml` runs `xcodebuild build` plus `xcodebuild test` on `macos-latest` for every push to `main`, every pull request, and on manual dispatch. Failed runs upload `test-results.xcresult` and raw build / test logs as 7-day artifacts. `concurrency` cancels superseded runs on the same ref.
- `docs/contributing.md` covers the test-running command, the `tfxTests/` layout convention, CI expectations, code-style rules, and a placeholder release-process section.

### 1.14 Performance Measurement Infrastructure

- `PerformanceTrace` honors a `UserDefaults`-backed flag (`Developer.showsPerformanceLogs`) in addition to the existing `TFX_PERFORMANCE_LOGS=1` environment variable. The env var still wins so CI and scripted runs do not have to flip the in-app toggle.
- A `Developer` menu item is added through `DeveloperMenuCommands` and exposes a `Show Performance Logs` toggle (localized as 「パフォーマンスログを表示」 in Japanese).
- `tfxTests/PerformanceBenchmarks.swift` adds five informational benchmarks against §3.1 scenarios: `FileItem` creation ×1k / ×5k, `loadHeader` 1k items, `filterAndSort` 1k items, `filterAndSort` 1k items + query. Timings are printed via `print` and **not** asserted — comparison is manual against rolling baselines on the same machine.
- Benchmarks run as part of the regular test suite; a dedicated CI job was intentionally not split out. Should benchmarks become too noisy or slow, they can be moved behind a Swift Testing tag and a separate non-blocking CI job later.

### 1.15 Pane Swap, Focus Cycling, and Shortcut Polish

- Left and right file panes can be swapped through a toolbar button (`arrow.left.arrow.right`, disabled when split is off), the `View → Swap Left and Right Panes` menu item, and `⌘⇧X`. `swapPanes()` in `TerminalFileManagerState` runs both panes through `navigate(to:)` so the swap records into history and `⌘[` rolls it back.
- `Tab` and `Shift+Tab` cycle keyboard focus across folder tree → left file pane → right file pane (when split is on). Driven by `cycleKeyboardFocus(reverse:)` in `TerminalFileManagerKeyboard`.
- `Left` / `Right` arrow keys now scroll the active file list horizontally instead of moving focus. `HorizontalScrollAccess` resolves the enclosing `NSScrollView` and registers a clamped-scroll closure on `FileBrowserModel.horizontalScrollHandler`.
- Keyboard shortcuts remapped to be shorter and more discoverable: `⌘T` (terminal), `⌘P` (preview), `⌘\\` (split), `⌘⇧X` (swap). Old slots (`⌘⇧T`, `⌘⌥P`, `⌘⌥S`, `⌘⌥X`) are released.
- `Shortcuts` (`Infrastructure/ShortcutInfo.swift`) is the single source of truth for toolbar and menu shortcuts. Each entry produces both the `.keyboardShortcut(_:)` binding and a `displayString` used by the new `quickHelp(_:shortcut:text:)` overload, so toolbar icons show their shortcut on hover (e.g. `Reload  ⌘R`, `Swap left and right panes  ⌘⇧X`).
- `View` menu (`ViewMenuCommands`) collects the layout toggles and the swap entry so they show up in the menu bar with their shortcuts. The swap shortcut is also wired directly in `handleKeyEvent` so it fires reliably even when the menu binding is suppressed by the menu item's disabled state.
- On first appear the left file pane is activated and the `..` row is pre-selected when navigation up is possible; a pending open-from-Finder request still wins.

## 2. Upcoming Work

Items are listed in recommended execution order, weighted by importance, relevance, effort, and risk. Item numbers reflect priority — they are not strict dependency markers. Each item describes its own dependencies in prose. The next concrete starting point is §2.1.

### 2.1 macOS Tags

Goal:

- Display and edit Finder-compatible color tags. High visible impact for low engineering cost; the macOS API is straightforward.

Tasks:

- Read tags through `URLResourceKey.tagNamesKey`.
- Optional tag-color column in the file list (toggleable through existing column settings).
- Context-menu "Tags…" submenu listing the user's existing tags plus an "Add Tag…" picker.
- Multi-selection batch tagging.

Done when:

- Tags applied in tfx appear in Finder, and tags applied in Finder appear in tfx.
- The tag column is toggleable through the existing file-list column settings.

### 2.2 Git Status Indicators

Goal:

- Surface Git status next to files inside a Git working copy. A meaningful differentiator for the developer audience that requires no new infrastructure.

Tasks:

- Detect the Git root for the current directory; cache results.
- Run `git status --porcelain=v2 --untracked-files=normal` on a background queue when entering a Git working copy and on `DirectoryWatcher` events.
- Decorate file rows with status badges: `M` modified, `A` added, `?` untracked, `D` deleted, `!` ignored.
- Display the current branch in the title bar / status line.

Done when:

- File rows in a Git working copy display accurate status badges that update on external changes.
- Non-Git folders incur no `git` cost.

### 2.3 Pane Tabs

Goal:

- Let each file pane carry multiple folders at once and switch between them with the keyboard.

Tasks:

- Introduce a per-pane tab container that owns multiple `FileBrowserModel` instances and tracks the active one.
- Horizontal tab strip above each file pane. Click to switch; `⌘W` closes; `⌘T` opens a new tab at the active folder; `⌘⇧[` / `⌘⇧]` cycles.
- Persistence: per-pane tab list (paths + active index) under new `UserDefaults` keys, following the additive policy in §3.5.
- Folder tree, preview, and search controls follow the active tab.

Done when:

- Each pane can hold multiple tabs that survive relaunch.
- Closing the last tab in a pane is handled deterministically (decide between "hide pane" and "empty-tab placeholder" during design).
- Keyboard shortcuts work for new / close / next / previous tab.

### 2.4 Built-in Terminal Pane

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

### 2.5 Permissions and Owner Editing

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

### 2.6 Built-in Color Themes

Goal:

- Ship 3-4 built-in themes before user-defined TOML themes (§2.10), so users get visible variety without waiting for the configuration foundation.

Tasks:

- Define a theme token table (file pane, folder tree, selected rows, drop targets, active borders, status lines, preview backgrounds).
- Implement 3-4 hardcoded themes (e.g., terminal-classic, light, solarized-ish, monokai-ish).
- Add a "Theme" menu / settings entry to switch between built-in themes.

Done when:

- Switching themes updates the main UI consistently and immediately.
- Missing color tokens in a theme fall back to the default.

### 2.7 Sparkle Auto-Update

Goal:

- Enable direct distribution by supporting in-app updates. Scheduled here because the infrastructure is only useful once a public release is imminent; landing it earlier means maintaining unused plumbing.

Tasks:

- Integrate Sparkle 2 via Swift Package Manager.
- Generate an Ed25519 signing keypair. Ship the public key in the app; keep the private key offline for release signing.
- Define the appcast feed URL and channel layout (stable / beta).
- Add a "Check for Updates…" menu item and a user-visible toggle for automatic checks (`SUEnableAutomaticChecks`).

Done when:

- A test release pushed through the appcast can be installed in-app.
- The appcast feed, signing process, and channel layout are documented.
- The direct-download distribution channel described in §3.3 is unblocked.

### 2.8 Configuration Foundation

Goal:

- Introduce user-editable configuration so later items can build on it. This is the hub for §2.9, §2.10, §2.11, §2.12, and §2.13.

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
- Define `version = N` at the top of every TOML file; carry forward at least one prior version's migration code (§3.5).
- Built-in defaults remain in code; TOML overrides are merged on top.

Done when:

- The configuration directory is created on demand.
- The app runs with built-in defaults when no configuration files exist.
- TOML loading errors are surfaced clearly to the user.

### 2.9 Shortcut Organization

Goal:

- Centralize shortcut definitions and prepare for user-defined shortcuts. Depends on §2.8.

Tasks:

- Define an action list with stable identifiers.
- Manage default shortcuts centrally (single source of truth).
- Define the `shortcuts.toml` override format.
- Detect shortcut conflicts (both default-vs-user and user-vs-user).

Done when:

- Existing shortcuts can be reviewed from one action definition list.
- User-defined shortcut conflicts are reported clearly.

### 2.10 Theme Customization via TOML

Builds on §2.8 and §2.6. Maps the TOML theme files to the same color tokens used by the built-in themes.

Done when:

- A user-defined `themes/*.toml` file can override built-in themes and appears in the theme picker.
- Missing tokens fall back to the active built-in default.

### 2.11 Extension-Based Behavior

Goal:

- Allow extension-specific open behavior, preview behavior, and context-menu behavior. Depends on §2.8.

Tasks:

- Define extension rules in `filetypes.toml`.
- Define precedence between built-in behavior, TOML rules, and Lua hooks (§2.12).
- Fall back to current built-in behavior for unknown extensions.

Done when:

- The default preview / open behavior can be changed per extension.
- Rule precedence is explicit and documented.

### 2.12 Lua Extension API

Goal:

- Allow extension behavior, shortcuts, and Markdown conversion to be customized with Lua, starting from the smallest useful API surface. Depends on §2.8 and is most useful after §2.9.

Introduced incrementally. Each step ships and is reviewed before the next begins.

1. Read-only inspection. A Lua script reads current folder / selection / extension info and returns a value (filter, label, classification).
2. Markdown post-processing. Lua filters Markdown source before conversion or HTML after conversion. Output is sanitized before being shown.
3. Shortcut bindings. Lua callbacks bound to shortcut TOML actions.
4. Open / preview hooks. Lua decides how a file is opened or previewed, within the sandbox.

Restrictions preserved across all steps:

- No file mutation.
- No external command execution.
- Read-oriented APIs only; the host returns sanitized data.
- Long-running scripts can be detected and stopped.

Done when:

- Each step has its own "done when" gate; step 1 ships before step 2 begins.
- Lua script errors never crash the app.

### 2.13 Markdown Preview Extensions

Goal:

- Let users extend Markdown preview behavior. Lowest current priority; address once §2.8 lands and concrete user demand surfaces, since the engineering cost (CSP, `WKWebView` content sandboxing, external library bundling) is significant.

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

Priority: lower than §2.12. Address once §2.8 lands and there is concrete user demand.

## 3. Cross-Cutting Concerns

Constraints and policies that apply across every item in §2. These are not feature deliverables; they exist so feature work can refer to them.

### 3.1 Performance Targets

Initial budgets. Revise once the measurement infrastructure landed in §1.14 produces real numbers from typical hardware.

| Path | Target |
| --- | --- |
| Cold launch on Apple Silicon | < 1.0 s |
| Directory load — 1k items | first paint < 100 ms, complete < 300 ms |
| Directory load — 10k items | first paint < 200 ms, complete < 1.0 s |
| External change → auto-refresh visible | < 350 ms (250 ms watcher debounce + load) |
| Typical session memory | < 200 MB |

### 3.2 Reliability and Quality Gates

- No data loss from drag / drop / move operations. Same-name conflicts must surface the resolver.
- Permission and read errors are surfaced through `show(_:)`, never swallowed.
- CI build + tests must pass before any release tag is cut.
- Every new public mutator on `FileBrowserModel` ships with at least one focused test.
- No new SwiftUI or Swift compiler warnings introduced.

### 3.3 Distribution Plan

The distribution channel escalates as the app matures. Earlier channels do not preclude later ones; TestFlight and direct download can run in parallel.

| Channel | Notes |
| --- | --- |
| Local Xcode builds | Current state. Development only. |
| TestFlight beta | Crash reports through App Store Connect; small known-tester pool. |
| Direct download via release page | Developer ID signed + notarized; updates delivered through Sparkle (§2.7). |
| Mac App Store | Requires `ENABLE_APP_SANDBOX = YES`; large adjustment, not committed. |

Decision points:

- TestFlight and direct download are not mutually exclusive — TestFlight for beta cycles, direct download with Sparkle for stable. Plan for both.
- Mac App Store is blocked today by the disabled App Sandbox. Revisit only if MAS reach becomes important enough to justify sandboxing.

### 3.4 macOS and Hardware Compatibility

- Deployment target: macOS 26.4 during development. Re-evaluate lowering to N-1 when distribution starts (§3.3, TestFlight channel).
- Apple Silicon native. No Intel build is planned at this deployment target.
- Public-release support window: current macOS plus one prior major version, applied from the first non-beta release onward.
- Locales: English (source) and Japanese are actively maintained. Additional locales accepted by PR with translation review.

### 3.5 Data and Configuration Migration

- `UserDefaults` schema is additive: new keys ship with defaults; existing keys are never removed without an explicit migration step.
- All persisted `UserDefaults` keys remain documented in `docs/detailed-design.md` §9.1.
- Future TOML configuration files (§2.8) carry a top-level `version = N` field. The loader migrates older versions forward and keeps at least one prior version's migration code on hand.
- Pinned folders, window state, and other user data are read-merge-write: never destructively rewritten on load when fields are missing.

## 4. Performance Measurement (On-Demand)

The proactive measurement infrastructure shipped in §1.14. This section is the reactive checklist for when slowness is reported or detected.

- Reproduce with `TFX_PERFORMANCE_LOGS=1` (env var) or **Developer → Show Performance Logs** (in-app).
- Compare timings against the §3.1 targets.
- For repeatable scenarios, add a corresponding benchmark to `tfxTests/PerformanceBenchmarks.swift`.
- Land the fix with a regression test where feasible.

## 5. Documentation Work

Tasks:

- Keep `docs/detailed-design.md` aligned with the current folder tree and drag-and-drop behavior.
- Keep `docs/file-manager-implementation-plan.md` current.
- Keep `README.md` and `README.ja.md` aligned.
- Keep `docs/README.md` aligned with the documentation set.
- Keep `docs/contributing.md` (added by §1.13, extended by §1.14) current with the test, benchmark, CI, and release commands.
- Add sample configuration files once §2.8 lands.
- Convert remaining Japanese documentation to English, except for `README.ja.md`.
- Expand `docs/contributing.md` with the release process once §2.7 lands.

Done when:

- The implementation plan, detailed design, and READMEs do not contradict each other.
- Users can start basic customization from the configuration examples.
- New contributors can run tests and benchmarks and understand the release process from the documentation.
