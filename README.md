# tfx

**Terminal-inspired interface File eXplorer**<br>
Pronunciation: **Tafix**<br>
Version: **0.5.3**

English | [日本語](README.ja.md)

`tfx` is a macOS file manager with a terminal-inspired interface and keyboard-first workflow. It combines a folder tree, split file panes, rich previews, drag and drop, and Terminal.app integration.

## Screenshot

![tfx screenshot](images/screenshot.png)

## Features

- Terminal-style file list UI
- Single folder tree rooted at `/`
- Persistent pinned folders section
- Home, Documents, and Downloads are pinned by default on first launch
- Drag reordering for pinned folders
- Single-pane and split-pane modes
- Drag and drop between left and right file panes
- Option-drag copies files; normal drag moves files
- Visual highlighting for the active view
- `..` row for parent-folder navigation
- Backspace parent-folder navigation
- Clickable breadcrumb path navigation
- PDF, video, Markdown, and Quick Look previews
- Toggle between rendered and source view for Markdown, HTML, CSV, and JSON previews
- CSV / TSV preview as a scrollable table; JSON preview as pretty-printed text
- Plain-text preview for TOML, YAML, INI, log, and similar config formats
- Compact preview metadata for selected files and folders
- Toggleable preview pane
- Browse zip archives without extracting them
- Copy files from browsed zip archives
- Open Terminal.app at the current folder
- New File, New Folder, Rename, Move to Trash, and Reveal in Finder
- "Open With" submenu listing applications that can open the file, with an "Other…" picker
- Auto-refresh: each file pane updates automatically when its directory changes externally
- Compress selected items to a zip archive
- Extract zip archives
- Copy, Cut, Paste, Finder pasteboard interoperability, and same-name conflict handling
- Finder aliases and directory symlinks are resolved for navigation
- Search, hidden-file toggle, and sorting
- Multi-selection with Command-click
- Range selection with Shift + arrow keys, Shift-click, and mouse drag
- Subfolder search with progress and cancellation
- File-type icons in the file list
- Configurable file-list columns: visibility and order
- Resizable file-name column by dragging the `NAME` header
- Restores window size, visible panes, pane widths, active pane, and open folders

## Keyboard

- `Up / Down`: Move selection in the active file pane or folder tree
- `Shift + Up / Down`: Extend the file-pane selection range
- `Left / Right`: Scroll the file list horizontally
- `Tab` / `Shift + Tab`: Cycle keyboard focus across folder tree → left file pane → right file pane
- `Enter`: Open the selected file or enter the selected folder
- `Command + [` / `Command + ]`: Back / Forward
- `Command + Up`: Parent folder
- `Backspace`: Parent folder
- `Command + F`: Search
- `Command + N`: New folder
- `Delete`: Move to Trash
- `Command + Backspace`: Move to Trash
- `Command + C / X / V`: Copy / Cut / Paste
- `Command + Option + V`: Move-paste
- `Command + A`: Select all
- `Command + R`: Reload
- `Command + T`: Open Terminal.app here
- `Command + P`: Toggle preview pane
- `Command + \`: Toggle split view
- `Command + Shift + X`: Swap left and right panes (split view only)
- `Command + Shift + .`: Toggle hidden files

## Command Line Launch

Open the installed app at the current directory:

```sh
open -a tfx "$PWD"
```

Open a specific directory:

```sh
open -a tfx /path/to/folder
```

Do not use `-n` or `--args`; pass the folder as the item for `open` instead. `--args` is treated as a launch argument and does not use macOS's normal folder-open path.

If `open -a tfx` cannot find the app, or launches a different build, pass the app path directly:

```sh
open -a /Applications/tfx.app "$PWD"
```

If you have a wrapper such as `/usr/local/bin/tfx`, relative paths are supported:

```sh
tfx .
```

## Build

```sh
xcodebuild -project tfx.xcodeproj -scheme tfx -destination 'platform=macOS' -derivedDataPath /tmp/tfx-derived CODE_SIGNING_ALLOWED=NO build
```

Release build:

```sh
xcodebuild -project tfx.xcodeproj -scheme tfx -configuration Release -destination 'platform=macOS' -derivedDataPath /tmp/tfx-release-derived CODE_SIGNING_ALLOWED=NO build
```

## Project Structure

Source directories:

- `tfx/App`: App entry points and root view wiring
- `tfx/TerminalFileManager`: Top-level file manager screen, controls, keyboard routing, and layout state
- `tfx/FileBrowser`: File browser model, directory loading, selection, file operations, zip archive browsing, metadata, and drag/drop behavior
- `tfx/FilePane`: File list panes, rows, headers, menus, settings, and status line
- `tfx/FolderTree`: Folder tree and pinned-folder UI
- `tfx/Preview`: Preview pane, Markdown/PDF/video/Quick Look previews, preview metadata, and preview type selection
- `tfx/Infrastructure`: Small reusable AppKit and SwiftUI helpers
- `tfx/Assets.xcassets/AppIcon.appiconset`: App icon assets

Supporting directories:

- `tools/generate_app_icon.swift`: App icon regeneration script
- `CHANGELOG.md`: Release history

## Documentation

See `docs/README.md` for the documentation index, maintenance rules, source layout guide, detailed design, implementation history, and roadmap.

## Notes

- Delete-like operations use the macOS Trash instead of permanent deletion.
- Previews use PDFKit, AVKit, WebKit, and Quick Look.
- Date display uses `yyyy-MM-dd HH:mm:ss`.
