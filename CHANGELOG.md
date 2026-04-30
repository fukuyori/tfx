# Changelog

This file records notable changes to `tfx`.

Documentation is written in English by default. `README.ja.md` is maintained as the Japanese README.

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
