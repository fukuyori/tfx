# tfx Configuration

English | [日本語](configuration.ja.md)

tfx stores user-editable configuration in:

```text
~/Library/Application Support/tfx/
```

The main configuration file is `config.toml`. It contains design settings,
startup layout settings, shortcut overrides, terminal-app settings, and
extension-specific open-with settings. This file is created automatically when
tfx starts if it does not already exist. Existing files are not overwritten. If
the file cannot be parsed, tfx falls back to the built-in defaults and shows a
startup configuration alert. tfx also reloads this file when the app becomes
active again, so edits made in another editor are picked up when returning to
tfx.

## Current Scope

`config.toml` supports `[font]`, `[colors]`, `[opacity]`, `[startup]`,
`[shortcuts]`, `[terminal]`, `[openWith]`, and `[[commands]]`. The configuration loaders
intentionally accept a small TOML subset for these first slices:

- Top-level `version = 1`
- `[font]`, `[colors]`, `[opacity]`, `[startup]`, `[shortcuts]`, `[terminal]`, `[openWith]`, and `[[commands]]` tables
- String values in double quotes
- Numeric font size values
- Color values as `"#RRGGBB"`
- Opacity values from `0` through `1`
- Shortcut values such as `"cmd+r"`, `"cmd+shift+x"`, and `"cmd+up"`
- Application references as absolute app paths or bundle identifiers
- `#` comments outside quoted strings

Other sections are ignored for now. Lua and Markdown preview settings are
planned but not implemented in the current configuration loaders.

## Default File

New installations create this file:

```toml
version = 1

[font]
ui = "system"
mono = "monospace"
size = 13

# Optional color overrides. Unspecified colors use the built-in tfx base.
#
# [colors]
# fileListBackground = "#000301"
# fileForeground = "#CFFFCF"
# directoryForeground = "#6FFF80"

# Optional opacity overrides. Values must be between 0 and 1.
#
# [opacity]
# inactivePane = 0.5
# disabledItem = 0.45

[startup]
# "single" starts with one pane and one tab.
# "split" starts with two panes. If rightFolder / rightFolders is omitted, the
# previous right-pane tabs are reused.
# "restore" reuses the previous split state and pane tabs.
layout = "single"
# rightFolder = "~/Downloads"
# rightFolders = ["~/Downloads", "~/Documents"]

[shortcuts]
reload = "cmd+r"
openTerminal = "cmd+t"
togglePreview = "cmd+p"
toggleSplit = "cmd+backslash"
swapPanes = "cmd+shift+x"
focusSearch = "cmd+f"
toggleHidden = "cmd+shift+."
goBack = "cmd+["
goForward = "cmd+]"
goUp = "cmd+up"
newTab = "cmd+shift+t"
closeTab = "cmd+w"
previousTab = "cmd+shift+["
nextTab = "cmd+shift+]"
toggleTerminalPane = "cmd+option+t"
focusTerminalPane = "cmd+option+shift+t"

# Optional application launch overrides.
#
# [terminal]
# app = "/System/Applications/Utilities/Terminal.app"
# bundleIdentifier = "com.apple.Terminal"
#
# [openWith]
# md = "com.microsoft.VSCode"
# pdf = "/Applications/Preview.app"
```

## Keys

### `version`

Required top-level integer.

```toml
version = 1
```

Only `1` is supported. Any other value is treated as a configuration error.

### `[font]`

Controls the app-wide font families and base size.

```toml
[font]
ui = "system"
mono = "monospace"
size = 13
```

| Key | Type | Default | Description |
| --- | --- | --- | --- |
| `ui` | string | `"system"` | Font family for UI-oriented roles such as folder tree, headers, pane title, preview text, and dialog-like surfaces. |
| `mono` | string | `"monospace"` | Font family for file-list rows, status line, raw text, JSON, CSV previews, and the built-in terminal pane. |
| `size` | number | `13` | Base font size in points. Valid range: `8` through `40`. |

`"system"` means the platform system UI font. `"monospace"` means the
platform monospaced system font. Any other string is treated as a font family
name and passed to SwiftUI / AppKit. If a named font is unavailable, rendering
falls back through the platform font APIs.

When a configured font is not already visible to AppKit, tfx scans
`~/Library/Fonts` and `/Library/Fonts` for `.ttf`, `.otf`, and `.ttc` files and
registers them for the current app process. This allows user-installed fonts
such as `CaskaydiaCove NF` to be used without restarting macOS font services.

The built-in terminal is rendered by xterm.js inside a WebView. It uses the
same `mono` and `size` settings, but the font is resolved as a CSS font-family
stack. When `mono = "monospace"` is used, the terminal falls back through:

```text
"SF Mono", Menlo, Monaco, "Courier New", monospace
```

When `mono` names a custom font, that name is placed before the fallback stack.
tfx also adds the resolved family name and PostScript font name when available.
For terminal output, prefer a true monospaced font such as `SF Mono`, `Menlo`,
`Monaco`, `JetBrains Mono`, `Cascadia Mono`, or `CaskaydiaCove NF`.

### `[colors]`

Overrides individual semantic color tokens from the built-in black-and-green
base design.

```toml
[colors]
fileListBackground = "#000301"
fileForeground = "#CFFFCF"
directoryForeground = "#6FFF80"
```

Every value must be a quoted `#RRGGBB` hex color. Tokens are optional. Missing
tokens keep the built-in tfx base color.

#### File Pane / List Rows

| Key | Description |
| --- | --- |
| `fileListBackground` | Base background for file rows and the file pane. |
| `fileListRowSelected` | Background for selected file rows. |
| `fileListRowDropTarget` | Background for in-progress drop targets. |
| `directoryForeground` | Directory names and directory mode glyphs. |
| `fileForeground` | Regular file names. |
| `secondaryForeground` | Size, kind, date, permission, and other secondary columns. |

#### File Pane Chrome

| Key | Description |
| --- | --- |
| `headerForeground` | File-pane column header text and header accents. |
| `headerBackground` | File-pane column header background. |
| `titleBarBackgroundActive` | File-pane title bar when active. |
| `titleBarBackgroundInactive` | File-pane title bar when inactive. |
| `statusLineForegroundActive` | Status-line text for the keyboard target. |
| `statusLineForegroundInactive` | Status-line text when inactive. |
| `statusLineBackground` | Status-line background. |

#### Pane Borders

| Key | Description |
| --- | --- |
| `paneBorderKeyboardTarget` | Border for the current keyboard target. |
| `paneBorderActive` | Border for an active pane that is not the keyboard target. |
| `paneBorderInactive` | Border for inactive panes. |

#### Folder Tree

| Key | Description |
| --- | --- |
| `folderTreeBackground` | Folder-tree background. |
| `folderTreeForeground` | Folder-tree row text. |
| `folderTreeSelectedForeground` | Selected/current folder-tree row text. |
| `folderTreeFolderIcon` | Folder-tree folder icon tint. |
| `folderTreeSelectedActive` | Selected folder-tree row when the tree is the keyboard target. |
| `folderTreeSelectedInactive` | Selected folder-tree row when the tree is inactive. |
| `folderTreeSectionHeader` | Folder-tree section headers such as `PINNED` and `FOLDERS`. |

#### Split Handle

| Key | Description |
| --- | --- |
| `splitHandleIdle` | Split-pane resize handle when idle. |
| `splitHandleActive` | Split-pane resize handle during drag. |

#### Git Status

| Key | Description |
| --- | --- |
| `gitModified` | Modified file badge. |
| `gitAdded` | Added file badge. |
| `gitDeleted` | Deleted file badge. |
| `gitRenamed` | Renamed file badge. |
| `gitUntracked` | Untracked file badge. |
| `gitIgnored` | Ignored file badge. |
| `gitConflicted` | Conflicted file badge. |

### `[opacity]`

Overrides semantic opacity tokens used by the built-in design.

```toml
[opacity]
background = 1
inactivePane = 0.5
disabledItem = 0.45
headerSecondary = 0.75
```

Every value must be a number from `0` through `1`. Tokens are optional.
Missing tokens keep the built-in tfx base value.
When `background` is less than `1`, tfx makes the window background transparent
so the configured background opacity is visible.

| Key | Default | Description |
| --- | --- | --- |
| `background` | `1` | Global opacity for theme background surfaces: file list, folder tree, headers, title bars, status lines, selected rows, and drop-target rows. |
| `inactivePane` | `0.5` | Active-but-not-keyboard-target pane title background strength. |
| `disabledItem` | `0.45` | Disabled row opacity, currently used by the unavailable parent-directory row. |
| `headerSecondary` | `0.75` | Secondary header affordances such as the resize indicator. |
| `selectedParentRow` | `0.8` | Selected parent-directory row background strength. |
| `dropIndicator` | `0.85` | Folder-tree insertion indicator strength. |
| `dragPreview` | `0.96` | Floating pinned-folder drag preview opacity. |
| `dragPreviewShadow` | `0.18` | Floating pinned-folder drag preview shadow opacity. |
| `subtleBackground` | `0.07` | Very subtle backgrounds, currently used by the path breadcrumb control. |

### `[startup]`

Controls the file-pane layout used when tfx starts.

```toml
[startup]
layout = "single"
# rightFolder = "~/Downloads"
# rightFolders = ["~/Downloads", "~/Documents", "~/Desktop"]
```

| Value | Behavior |
| --- | --- |
| `"single"` | Always starts with one file pane and one tab. This is the default. |
| `"split"` | Always starts in split view. The left pane starts with one tab; the right pane opens `rightFolders` / `rightFolder` when set, otherwise it reuses the previous right-pane tabs. |
| `"restore"` | Restores the previous split/single state and saved pane tabs. |

`rightFolders` is optional and only affects `layout = "split"`. It opens each
valid folder as a right-pane tab, with the first item active:

```toml
[startup]
layout = "split"
rightFolders = ["~/Downloads", "~/Documents", "~/Desktop"]
```

`rightFolder` remains supported for a single right-pane startup tab:

```toml
[startup]
layout = "split"
rightFolder = "~/Downloads"
```

Both settings accept absolute paths or `~`-expanded user paths. If
`rightFolders` is set, it takes precedence over `rightFolder`. If no valid
right-side startup folder is available, tfx keeps the previous right-pane
display.

### `[shortcuts]`

Defined in `config.toml`.

```toml
[shortcuts]
reload = "cmd+shift+r"
togglePreview = "cmd+option+p"
goUp = "cmd+up"
rename = "ctrl+r"
copyPath = "cmd+option+c"
```

Supported modifier tokens:

| Token | Meaning |
| --- | --- |
| `cmd`, `command` | Command |
| `shift` | Shift |
| `opt`, `option`, `alt` | Option |
| `ctrl`, `control` | Control |

Supported key tokens:

| Token | Meaning |
| --- | --- |
| Single character, such as `r`, `.`, `[`, `]` | That key |
| `up`, `down`, `left`, `right` | Arrow keys |
| `escape`, `esc` | Escape |
| `delete`, `backspace` | Delete / Backspace. Also matches Forward Delete. |
| `return`, `enter` | Return |
| `tab` | Tab |
| `space` | Space |
| `backslash` | `\` |
| `f1` through `f20` | Function keys |

Supported action keys:

| Key | Default | Action |
| --- | --- | --- |
| `reload` | `cmd+r` | Reload the active file pane. |
| `openTerminal` | `cmd+t` | Open the configured terminal app at the active folder. |
| `togglePreview` | `cmd+p` | Show or hide the preview pane. |
| `toggleSplit` | `cmd+backslash` | Show or hide split view. |
| `swapPanes` | `cmd+shift+x` | Swap the left and right panes. |
| `focusSearch` | `cmd+f` | Focus the search field. |
| `toggleHidden` | `cmd+shift+.` | Show or hide hidden files. |
| `goBack` | `cmd+[` | Navigate back. |
| `goForward` | `cmd+]` | Navigate forward. |
| `goUp` | `cmd+up` | Navigate to the parent folder. |
| `openItem` | `cmd+o` | Open the selected item. |
| `newFolder` | `cmd+n` | Create a folder and start inline name editing. |
| `newFile` | `cmd+shift+n` | Create a file and start inline name editing. |
| `rename` | `cmd+return` | Rename the selected item inline. |
| `moveToTrash` | `cmd+backspace` | Move the selected items to Trash. |
| `compressToZip` | `cmd+option+z` | Compress the selected items to a zip archive. |
| `extractZip` | `cmd+option+e` | Extract the selected zip archive. |
| `copyItems` | `cmd+c` | Copy the selected items. |
| `cutItems` | `cmd+x` | Cut the selected items. |
| `pasteItems` | `cmd+v` | Paste into the active folder. |
| `movePasteItems` | `cmd+option+v` | Paste by moving into the active folder. |
| `selectAll` | `cmd+a` | Select all visible items. |
| `revealInFinder` | `cmd+option+r` | Reveal the selected items in Finder. |
| `copyPath` | `cmd+option+c` | Copy the selected item path, or the current folder path when no item is selected. |
| `newTab` | `cmd+shift+t` | Open a new tab in the active pane at the current folder. |
| `closeTab` | `cmd+w` | Close the active tab. The last tab in a pane stays open. |
| `previousTab` | `cmd+shift+[` | Select the previous tab in the active pane. |
| `nextTab` | `cmd+shift+]` | Select the next tab in the active pane. |
| `toggleTerminalPane` | `cmd+option+t` | Show or hide the built-in terminal pane. |
| `focusTerminalPane` | `cmd+option+shift+t` | Show and focus the built-in terminal pane. |

If two actions resolve to the same shortcut, tfx reports a configuration error
and uses the built-in shortcut defaults.

The same action keys are used by toolbar buttons, the View menu, keyboard
handling, and file-list context menu items. For example, changing `rename`
updates both the row context menu display and the shortcut that starts inline
renaming.

### `[terminal]`

Overrides the app used by the terminal button and `openTerminal` shortcut.

```toml
[terminal]
app = "/Applications/Ghostty.app"
```

You can also use a bundle identifier:

```toml
[terminal]
bundleIdentifier = "com.googlecode.iterm2"
```

If both `app` and `bundleIdentifier` are present, `app` is used. If this table
is omitted, tfx uses `/System/Applications/Utilities/Terminal.app`.

### `[openWith]`

Overrides the app used when opening files by extension. Keys are extensions
without the leading dot. Values can be absolute app paths or bundle
identifiers.

```toml
[openWith]
md = "com.microsoft.VSCode"
txt = "/System/Applications/TextEdit.app"
pdf = "/Applications/Preview.app"
```

Compound extension keys can be quoted:

```toml
[openWith]
"tar.gz" = "com.example.ArchiveApp"
```

Unknown extensions keep the normal macOS default-app behavior. Directories,
zip navigation, and archive-internal files keep their existing tfx behavior.

### `[[commands]]`

Adds user-defined commands to the file-list context menus. Commands are shown
only when the current selection matches their filters. A command shortcut, when
set, is checked before built-in shortcuts.

```toml
[[commands]]
name = "Open in VS Code"
run = "code {path}"
target = "any"
selection = "single"

[[commands]]
name = "Optimize PNG"
run = "pngquant --force --ext .png {paths}"
extensions = ["png"]
target = "file"
terminal = true

[[commands]]
name = "Git Pull"
run = "git -C {cwd} pull --ff-only"
target = "current"
requireGit = true
terminal = true
shortcut = "cmd+shift+g"
```

Supported keys:

| Key | Type | Default | Description |
| --- | --- | --- | --- |
| `name` | string | required | Menu label. |
| `run` | string | required | Command line or multi-line script body. |
| `extensions` | string array | all | Matching file extensions without dots. Use `["*"]` for all. |
| `target` | string | `"any"` | `file`, `folder`, `current`, or `any`. `current` acts on the current folder and appears in the empty-area context menu. |
| `selection` | string | `"any"` | `single`, `multiple`, or `any`. Ignored for `target = "current"`. |
| `requireGit` | boolean | `false` | Show only inside a Git work tree. |
| `terminal` | boolean | `false` | Stream stdout/stderr to the built-in terminal pane's Output tab. |
| `shortcut` | string | none | Shortcut using the same grammar as `[shortcuts]`. |
| `shell` | string | `$SHELL` or `/bin/zsh` | Shell used to run the command. |

Tokens in `run`:

| Token | Value |
| --- | --- |
| `{path}` | First selected item path, or the current folder when nothing is selected. |
| `{paths}` | All selected item paths separated by spaces, or the current folder when nothing is selected. |
| `{dir}` | Parent folder of the first selected item, or the current folder. |
| `{name}` | First selected item filename with extension. For a selected folder, this is the folder name. |
| `{stem}` | First selected item filename without extension. |
| `{ext}` | First selected item extension without the dot. Empty for folders. |
| `{cwd}` | Current folder regardless of selection. |
| `{scripts}` | `scripts` folder next to `config.toml`, created on demand. |

Path-like tokens are shell-quoted automatically. `{scripts}` is substituted as
a raw path, so quote it in `run` if the path may contain spaces. Environment
variables in `$NAME` or `${NAME}` form are expanded before token substitution.

User-defined commands run in their own process. The process working directory
is the parent folder of the first selected item, or the current folder when
nothing is selected. `cd {dir}` affects that command process only; it does not
change the current directory of an already open interactive built-in terminal
session. When `terminal = true`, stdout/stderr is shown in the built-in terminal
pane's Output tab. When `terminal = false`, stdout/stderr is discarded.

Multi-line scripts can be written with TOML literal strings. They are written
to a temporary script file and run through `shell`.

```toml
[[commands]]
name = "File Info"
target = "file"
terminal = true
run = '''
file {path}
stat -f "size=%z modified=%Sm" {path}
'''
```

Xcode project folders can be built and opened without hard-coding the scheme
or app name by reading the first scheme and wrapper name from `xcodebuild`:

```toml
[[commands]]
name = "Build and Run Xcode Project"
extensions = ["xcodeproj"]
target = "folder"
terminal = true
run = '''
cd {dir}

project={name}
derived=".build/xcode"

scheme=$(
  xcodebuild -list -json -project "$project" |
  /usr/bin/python3 -c 'import json,sys; p=json.load(sys.stdin).get("project",{}); s=p.get("schemes",[]); print(s[0] if s else "")'
)

if [ -z "$scheme" ]; then
  echo "No scheme found in $project"
  exit 1
fi

xcodebuild -project "$project" -scheme "$scheme" -configuration Debug -derivedDataPath "$derived" build

app=$(
  xcodebuild -project "$project" -scheme "$scheme" -configuration Debug -showBuildSettings 2>/dev/null |
  awk -F" = " '/ WRAPPER_NAME = / { print $2; exit }'
)

if [ -z "$app" ]; then
  echo "No app product found for scheme: $scheme"
  exit 1
fi

open "$derived/Build/Products/Debug/$app"
'''
```

If the project has multiple schemes, this sample uses the first scheme reported
by `xcodebuild -list -json`.

## Font Role Mapping

The user-facing configuration stays small, while the app maps roles internally:

| UI role | Family source | Size |
| --- | --- | --- |
| File list rows | `mono` | `size` |
| Parent directory row | `mono` | `size` |
| Folder tree rows | `ui` | `size` |
| Path/search controls | `mono` | `size` |
| Raw text preview | `mono` | `size` |
| JSON preview | `mono` | `size` |
| CSV preview | `mono` | `size` |
| Built-in terminal pane | `mono` | `size` |
| Headers | `ui` | `size - 1`, minimum `8` |
| Pane title path field | `ui` | `size - 1`, minimum `8` |
| Status line | `mono` | `size - 2`, minimum `8` |
| Captions/help text | `ui` | `size - 2`, minimum `8` |
| Settings title / empty preview icon scale | `ui` | `size + 2` |

## Examples

Use the system UI font and a larger monospaced file list:

```toml
version = 1

[font]
ui = "system"
mono = "SF Mono"
size = 14
```

Use custom Japanese-friendly UI text with a separate monospaced font:

```toml
version = 1

[font]
ui = "Hiragino Sans"
mono = "Menlo"
size = 13
```

Use JetBrains Mono throughout the file-oriented parts:

```toml
version = 1

[font]
ui = "system"
mono = "JetBrains Mono"
size = 13
```

Use Menlo for the built-in terminal and other monospaced surfaces:

```toml
version = 1

[font]
ui = "system"
mono = "Menlo"
size = 13
```

The built-in terminal also uses these color tokens:

| Terminal area | Color token |
| --- | --- |
| Terminal background | `fileListBackground` |
| Terminal text | `fileForeground` |
| Terminal cursor | `directoryForeground` |
| Terminal selection | `fileListRowSelected` |

Change only the primary file and folder colors:

```toml
version = 1

[colors]
fileForeground = "#E6FFE6"
directoryForeground = "#80FF9A"
fileListRowSelected = "#12351E"
```

Use a dimmer pane chrome while keeping the file list readable:

```toml
version = 1

[colors]
headerForeground = "#58D66E"
statusLineForegroundInactive = "#2B7A3A"
paneBorderInactive = "#174021"
```

### Color Samples

These samples can be copied into `config.toml` and adjusted token by token.
Each sample defines only colors; font settings can be added in the same file
under `[font]`.

Amber console:

```toml
version = 1

[colors]
fileListBackground = "#120800"
fileListRowSelected = "#3A2406"
fileListRowDropTarget = "#6B3A08"
fileForeground = "#FFE7B0"
directoryForeground = "#FFB84D"
secondaryForeground = "#B87928"
headerForeground = "#FFD36A"
headerBackground = "#1C0D00"
titleBarBackgroundActive = "#4A2A08"
titleBarBackgroundInactive = "#1C0D00"
statusLineForegroundActive = "#FFD36A"
statusLineForegroundInactive = "#B87928"
statusLineBackground = "#1C0D00"
paneBorderKeyboardTarget = "#FFD36A"
paneBorderActive = "#B87928"
paneBorderInactive = "#5A3510"
folderTreeBackground = "#120800"
folderTreeForeground = "#FFE7B0"
folderTreeSelectedForeground = "#FFF0C8"
folderTreeFolderIcon = "#FFB84D"
folderTreeSelectedActive = "#4A2A08"
folderTreeSelectedInactive = "#2A1805"
folderTreeSectionHeader = "#FFD36A"
splitHandleIdle = "#5A3510"
splitHandleActive = "#FFD36A"
gitModified = "#FFD36A"
gitAdded = "#A6E36A"
gitDeleted = "#FF6B5F"
gitRenamed = "#D8A6FF"
gitUntracked = "#B87928"
gitIgnored = "#5A3510"
gitConflicted = "#6FE7D6"
```

Cyan deep sea:

```toml
version = 1

[colors]
fileListBackground = "#020A12"
fileListRowSelected = "#07314A"
fileListRowDropTarget = "#0A5C78"
fileForeground = "#D6F7FF"
directoryForeground = "#66D9FF"
secondaryForeground = "#4A91A8"
headerForeground = "#8AEFFF"
headerBackground = "#03131D"
titleBarBackgroundActive = "#06354A"
titleBarBackgroundInactive = "#03131D"
statusLineForegroundActive = "#8AEFFF"
statusLineForegroundInactive = "#4A91A8"
statusLineBackground = "#03131D"
paneBorderKeyboardTarget = "#8AEFFF"
paneBorderActive = "#4A91A8"
paneBorderInactive = "#1D5265"
folderTreeBackground = "#020A12"
folderTreeForeground = "#D6F7FF"
folderTreeSelectedForeground = "#FFFFFF"
folderTreeFolderIcon = "#66D9FF"
folderTreeSelectedActive = "#06354A"
folderTreeSelectedInactive = "#062235"
folderTreeSectionHeader = "#8AEFFF"
splitHandleIdle = "#1D5265"
splitHandleActive = "#8AEFFF"
gitModified = "#FFD166"
gitAdded = "#7CFFB2"
gitDeleted = "#FF6B7A"
gitRenamed = "#BDA7FF"
gitUntracked = "#4A91A8"
gitIgnored = "#1D5265"
gitConflicted = "#8AEFFF"
```

Magenta slate:

```toml
version = 1

[colors]
fileListBackground = "#0B0A10"
fileListRowSelected = "#2A2038"
fileListRowDropTarget = "#583066"
fileForeground = "#ECE7F2"
directoryForeground = "#FF8BD1"
secondaryForeground = "#9A8BA8"
headerForeground = "#FFB3E1"
headerBackground = "#14111C"
titleBarBackgroundActive = "#322440"
titleBarBackgroundInactive = "#14111C"
statusLineForegroundActive = "#FFB3E1"
statusLineForegroundInactive = "#9A8BA8"
statusLineBackground = "#14111C"
paneBorderKeyboardTarget = "#FFB3E1"
paneBorderActive = "#9A6BB8"
paneBorderInactive = "#493858"
folderTreeBackground = "#0B0A10"
folderTreeForeground = "#ECE7F2"
folderTreeSelectedForeground = "#FFFFFF"
folderTreeFolderIcon = "#FF8BD1"
folderTreeSelectedActive = "#322440"
folderTreeSelectedInactive = "#211A2A"
folderTreeSectionHeader = "#FFB3E1"
splitHandleIdle = "#493858"
splitHandleActive = "#FFB3E1"
gitModified = "#FFD166"
gitAdded = "#7DDE92"
gitDeleted = "#FF6B8A"
gitRenamed = "#C9A7FF"
gitUntracked = "#9A8BA8"
gitIgnored = "#493858"
gitConflicted = "#7BE7FF"
```

Light graphite:

```toml
version = 1

[colors]
fileListBackground = "#F7FAF5"
fileListRowSelected = "#DDEFD8"
fileListRowDropTarget = "#BEE5B7"
fileForeground = "#18221A"
directoryForeground = "#167A3A"
secondaryForeground = "#5D6B60"
headerForeground = "#1C6B37"
headerBackground = "#EAF3E7"
titleBarBackgroundActive = "#D5EBD0"
titleBarBackgroundInactive = "#EAF3E7"
statusLineForegroundActive = "#176B34"
statusLineForegroundInactive = "#5D6B60"
statusLineBackground = "#EAF3E7"
paneBorderKeyboardTarget = "#17813A"
paneBorderActive = "#6AA66F"
paneBorderInactive = "#C5D5C2"
folderTreeBackground = "#F2F7EF"
folderTreeForeground = "#18221A"
folderTreeSelectedForeground = "#0E2614"
folderTreeFolderIcon = "#167A3A"
folderTreeSelectedActive = "#D5EBD0"
folderTreeSelectedInactive = "#E3EFE0"
folderTreeSectionHeader = "#1C6B37"
splitHandleIdle = "#C5D5C2"
splitHandleActive = "#17813A"
gitModified = "#9A6A00"
gitAdded = "#16813D"
gitDeleted = "#B23B3B"
gitRenamed = "#7653B5"
gitUntracked = "#4F8053"
gitIgnored = "#9AA89A"
gitConflicted = "#007C73"
```

Use stronger active/inactive separation:

```toml
version = 1

[opacity]
background = 0.88
inactivePane = 0.35
disabledItem = 0.35
headerSecondary = 0.55
selectedParentRow = 0.9
dropIndicator = 1
dragPreview = 0.98
dragPreviewShadow = 0.26
subtleBackground = 0.12
```

## Error Handling

tfx treats these as configuration errors:

- Missing or invalid assignment syntax, such as `size: 13`
- Non-string `ui` or `mono` values
- Non-numeric `size`
- `size` outside `8...40`
- Color values that are not quoted `#RRGGBB` strings
- Opacity values outside `0...1`
- Invalid application launch assignment or string syntax
- Invalid user-defined command assignment, boolean, target, selection, shortcut, or unterminated multi-line script
- Unavailable configured terminal / open-with application when used
- Unsupported `version`

When an error is found, tfx does not crash. Design and shortcut parse errors
fall back to their built-in defaults and show an alert with the parse error.
Application launch errors are shown when the configured action is used.

## Planned Sections

Richer preview behavior by extension will be added separately from user-defined
commands.
