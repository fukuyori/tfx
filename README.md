# tfx

**Terminal File eXplorer**  
Pronunciation: **Tafix**  
Version: **0.1.0**

English | [日本語](README.ja.md)

`tfx` is a macOS file manager with a terminal-inspired interface and keyboard-first workflow. It combines a folder tree, split file panes, rich previews, drag and drop, and Terminal.app integration.

## Features

- Terminal-style file list UI
- Single folder tree rooted at `/`
- Persistent pinned folders section
- Single-pane and split-pane modes
- Drag and drop between left and right file panes
- Visual highlighting for the active view
- `..` row for parent-folder navigation
- PDF, video, Markdown, and Quick Look previews
- Toggleable preview pane
- Open Terminal.app at the current folder
- New Folder, Rename, Move to Trash, and Reveal in Finder
- Copy, Cut, Paste, and same-name conflict handling
- Search, hidden-file toggle, and sorting
- Multi-selection with Command-click
- Range selection with Shift + arrow keys and Shift-click
- File-type icons in the file list
- Configurable file-list columns: visibility and order
- Resizable file-name column by dragging the `NAME` header
- Restores window size, visible panes, pane widths, active pane, and open folders

## Keyboard

- `Up / Down`: Move selection in the active file pane or folder tree
- `Shift + Up / Down`: Extend the file-pane selection range
- `Left / Right`: Move focus between the folder tree and file panes
- `Enter`: Open the selected file or enter the selected folder
- `Command + [` / `Command + ]`: Back / Forward
- `Command + Up`: Parent folder
- `Command + F`: Search
- `Command + N`: New folder
- `Delete`: Move to Trash
- `Command + C / X / V`: Copy / Cut / Paste
- `Command + A`: Select all
- `Command + R`: Reload
- `Command + Shift + T`: Open Terminal.app here
- `Command + Shift + .`: Toggle hidden files

## Build

```sh
xcodebuild -project tfx.xcodeproj -scheme tfx -destination 'platform=macOS' -derivedDataPath /tmp/tfx-derived CODE_SIGNING_ALLOWED=NO build
```

Release build:

```sh
xcodebuild -project tfx.xcodeproj -scheme tfx -configuration Release -destination 'platform=macOS' -derivedDataPath /tmp/tfx-release-derived CODE_SIGNING_ALLOWED=NO build
```

## Project Structure

- `tfx/TerminalFileManagerView.swift`: Main file manager implementation
- `tfx/ContentView.swift`: Presents `TerminalFileManagerView` on macOS
- `tfx/Assets.xcassets/AppIcon.appiconset`: App icon assets
- `tools/generate_app_icon.swift`: App icon regeneration script
- `docs/file-manager-implementation-plan.md`: Implementation plan and progress notes

## Notes

- Delete-like operations use the macOS Trash instead of permanent deletion.
- Previews use PDFKit, AVKit, WebKit, and Quick Look.
- Date display uses `yyyy-MM-dd HH:mm:ss`.
- Release builds created with `CODE_SIGNING_ALLOWED=NO` are not Developer ID signed or notarized.
