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

## 2. Short-Term Work

### 2.1 Measurement-Based Performance Work

Goal:

- Use timing logs to identify slow paths instead of relying only on perceived latency.

Tasks:

- Use `TFX_PERFORMANCE_LOGS=1` to measure:
  - directory header loading
  - directory item creation
  - filtering and sorting
  - metadata prefetching
  - folder-tree child loading
- Add targeted optimizations when a specific folder or operation is slow.
- Consider a developer setting for enabling performance logs from the UI.

Done when:

- Slow paths can be identified in large directories.
- Reproduction conditions and before/after timings can be recorded for each optimization.

### 2.2 Drag-and-Drop Final Cleanup

Goal:

- Make the boundary between file movement, pinned-folder ordering, and folder-tree navigation clear.

Tasks:

- Allow file-view to folder-tree drops.
- Forbid folder-to-folder movement inside the folder tree.
- Keep pinned-folder reordering as display-order-only behavior.
- Verify that drop highlights are cleared after cancellation and failure.
- Clarify the roles of context menus on blank file-view space, file rows, and folder rows.

Done when:

- UI behavior clearly separates real file movement from display-order changes.
- Drop highlights never remain after a failed or cancelled drop.

## 3. Mid-Term Work

### 3.1 Configuration Foundation

Goal:

- Introduce user-editable configuration.
- Provide the foundation for themes, file type rules, shortcuts, Markdown extensions, and Lua extensions.

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

Done when:

- The configuration directory is created when needed.
- The app runs with built-in defaults when no configuration files exist.
- TOML loading errors are shown clearly to the user.

### 3.2 Color Schemes

Goal:

- Let users select and edit terminal-style UI colors.

Tasks:

- Define built-in themes.
- Load user-defined themes from TOML.
- Apply themes to file panes, folder tree, selected rows, drop targets, active borders, status lines, and preview backgrounds.

Done when:

- Switching themes updates the main UI consistently.
- Missing color values fall back to defaults.

### 3.3 Shortcut Organization

Goal:

- Centralize shortcut definitions and prepare for user-defined shortcuts.

Tasks:

- Define an action list.
- Manage default shortcuts centrally.
- Define the TOML override format.
- Detect shortcut conflicts.

Done when:

- Existing shortcuts can be reviewed from one action definition list.
- User-defined shortcut conflicts can be detected.

### 3.4 Extension-Based Behavior

Goal:

- Allow extension-specific open behavior, preview behavior, and context menu behavior.

Tasks:

- Define extension rules in `filetypes.toml`.
- Define precedence between built-in behavior, TOML rules, and Lua hooks.
- Fall back to current built-in behavior for unknown extensions.

Done when:

- The default preview/open behavior can be changed per extension.
- Rule precedence is explicit.

## 4. Long-Term Work

### 4.1 Markdown Preview Extensions

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

### 4.2 Lua Extension API

Goal:

- Allow extension behavior, shortcuts, and Markdown conversion to be extended with Lua.

Initial restrictions:

- File mutation is forbidden.
- External command execution is forbidden.
- Scripts can only use read-oriented APIs exposed by tfx.
- Markdown filters return Markdown text or sanitized HTML fragments.

Done when:

- Lua script errors do not crash the app.
- Long-running scripts can be detected or stopped.
- Lua can read selected files, current folder, extension, and preview target information.

## 5. Documentation Work

Tasks:

- Keep `docs/detailed-design.md` aligned with the current folder tree and drag-and-drop behavior.
- Keep `docs/file-manager-implementation-plan.md` current.
- Keep `README.md` and `README.ja.md` aligned.
- Keep `docs/README.md` aligned with the documentation set.
- Add sample configuration files.
- Convert remaining Japanese documentation to English, except for `README.ja.md`.

Done when:

- The implementation plan, detailed design, and READMEs do not contradict each other.
- Users can start basic customization from the configuration examples.
