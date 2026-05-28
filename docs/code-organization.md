# Code Organization

This document describes the current Swift source layout and the rules for keeping file names and placement consistent.

## Source Directories

### `tfx/App`

Application entry points and root app wiring.

- `tfxApp.swift`
- `ContentView.swift`

### `tfx/TerminalFileManager`

Top-level terminal file manager screen composition, keyboard routing, header controls, and whole-screen state.

Use this directory for code that coordinates multiple panes or owns the main screen layout.

### `tfx/FileBrowser`

File browser model, directory loading, selection state, file operations, zip archive browsing, folder-tree data, pinned folders, drag/drop model actions, metadata, icon caching, and browser-level shared types.

Use this directory for non-visual file browsing behavior and model-side operations.

### `tfx/FilePane`

File list UI, rows, headers, menus, status line, and file-list display settings.

Use this directory for views that render or interact with the file list pane.

### `tfx/FolderTree`

Folder tree and pinned-folder UI.

Use this directory for views that render folder rows, section headers, expansion controls, and pinned-folder rows.

### `tfx/Preview`

Preview pane, preview kind selection, Markdown rendering, PDF/video/Quick Look preview views, and multi-preview item UI.

Use this directory for preview rendering and preview-specific interaction.

### `tfx/Git`

`GitFileStatus` enum, `GitRepositoryStatus` aggregate, and `GitStatusReader` (background `git rev-parse` / `git status --porcelain=v2` invocations). The model wiring lives in `FileBrowser/FileBrowserModel+GitStatus.swift`; this directory keeps the platform-facing Git plumbing isolated.

Use this directory for additional Git integration (branch operations, diff display, etc.) that needs to call out to `git` or parse its output.

### `tfx/Theme`

`Theme` color token table, `DesignTokens` font / design aggregate, `DesignStore`, and the environment keys that surface colors via `@Environment(\.theme)` and the full design via `@Environment(\.design)`.

Use this directory for adding new design tokens or the configuration-backed customization path from §2.10. tfx has one built-in black-and-green base design; user configuration should override that base rather than adding multiple bundled themes.

### `tfx/Infrastructure`

Small reusable UI and platform helpers that are not owned by one feature.

Keep this directory small. If a helper becomes feature-specific, move it to that feature directory.

## Naming Rules

- Prefer a file name that matches the primary type in the file.
- Use `FileBrowserModel+Feature.swift` for focused extensions on `FileBrowserModel`.
- Avoid broad names such as `Support`, `Helpers`, or `Utils` unless the file is intentionally a small collection of closely related helpers.
- Do not split files solely to make them short. Split when a separate responsibility has a clear name and can be found independently.
- Do not merge unrelated UI and model code into the same file just to reduce file count.

## Current Granularity Guidance

- Around 50 to 180 lines is a normal range for most files.
- Files over 200 lines should be reviewed, but do not need splitting if the responsibility is still coherent.
- Files under 30 lines are acceptable for single-purpose view components or small platform adapters, but should be merged if the name becomes vague.

## Placement Rules

- UI row/view components belong to the directory of the pane that renders them.
- Model-side file system operations belong to `FileBrowser`.
- Preview-specific type detection and caches belong to `Preview`.
- Top-level keyboard and pane coordination belongs to `TerminalFileManager`.
- Cross-feature reusable SwiftUI or AppKit adapters belong to `Infrastructure`.

## Review Checklist

Before adding or moving a file:

- Is the file name searchable from the feature or primary type name?
- Does the file belong to one feature directory?
- Is this model behavior, pane UI, preview UI, or top-level coordination?
- Would splitting or merging make the next change easier to locate?
- Does the project still build after the move?
