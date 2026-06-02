# tfx 設定

[English](configuration.md) | 日本語

tfx はユーザーが編集できる設定を次の場所に保存します。

```text
~/Library/Application Support/tfx/
```

メインの設定ファイルは `config.toml` です。デザイン設定、ショートカット、ターミナルアプリ、拡張子ごとの「このアプリケーションで開く」設定、プレビュー動作、ユーザー定義コマンドを記述できます。このファイルが存在しない場合、tfx は起動時に自動作成します。既存ファイルは上書きしません。ファイルを解析できない場合、tfx は内蔵デフォルトにフォールバックし、起動時に設定エラーのアラートを表示します。

tfx はアプリが再びアクティブになったタイミングでも `config.toml` を再読み込みします。別のエディタで設定を編集した場合は、tfx に戻ると変更が反映されます。

## 現在の対応範囲

`config.toml` は `[font]`、`[colors]`、`[opacity]`、`[startup]`、`[shortcuts]`、`[terminal]`、`[openWith]`、`[preview]`、`[preview.extensions]`、`[preview.markdown]`、`[[commands]]` に対応しています。最初の実装では、設定ローダーが受け付ける TOML を意図的に小さな範囲に絞っています。

- トップレベルの `version = 1`
- `[font]`、`[colors]`、`[opacity]`、`[startup]`、`[shortcuts]`、`[terminal]`、`[openWith]`、`[preview]`、`[preview.extensions]`、`[preview.markdown]`、`[[commands]]` テーブル
- ダブルクォートで囲んだ文字列
- 数値のフォントサイズ
- `"#RRGGBB"` 形式のカラー値
- `0` から `1` までの透過度
- `"cmd+r"`、`"cmd+shift+x"`、`"cmd+up"` などのショートカット値
- 絶対パスまたは bundle identifier によるアプリ指定
- クォート外の `#` コメント

その他のセクションは現時点では無視されます。Lua スクリプトはロード対象としてはまだ実装されていません。

## デフォルトファイル

新規環境では次のファイルが作成されます。

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
# "single" は 1 ペイン 1 タブで起動します。
# "split" は左右 2 ペインで起動します。rightFolder / rightFolders を省略すると、
# 前回の右ペインタブを再利用します。
# "restore" は前回のスプリット状態とペインタブを復元します。
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
#
# [preview]
# default = "auto"
#
# [preview.extensions]
# md = "rendered"
# log = "text"
# zip = "none"
#
# [preview.markdown]
# externalImages = "button"
```

## キー

### `version`

必須のトップレベル整数です。

```toml
version = 1
```

対応している値は `1` のみです。それ以外の値は設定エラーになります。

### `[font]`

アプリ全体のフォントファミリーと基準サイズを設定します。

```toml
[font]
ui = "system"
mono = "monospace"
size = 13
```

| キー | 型 | デフォルト | 説明 |
| --- | --- | --- | --- |
| `ui` | string | `"system"` | フォルダツリー、ヘッダー、ペインタイトル、プレビューテキスト、ダイアログ風 UI などに使う UI 向けフォントです。 |
| `mono` | string | `"monospace"` | ファイル一覧、ステータス行、Raw text、JSON、CSV プレビュー、内蔵ターミナルペインなどに使う等幅フォントです。 |
| `size` | number | `13` | 基準フォントサイズです。単位は point、範囲は `8` から `40` です。 |

`"system"` はプラットフォーム標準の UI フォントです。`"monospace"` はプラットフォーム標準の等幅フォントです。それ以外の文字列はフォントファミリー名として SwiftUI / AppKit に渡されます。指定したフォントが利用できない場合は、プラットフォーム側のフォールバックが使われます。

指定されたフォントが AppKit から見えていない場合、tfx は
`~/Library/Fonts` と `/Library/Fonts` にある `.ttf`、`.otf`、`.ttc`
ファイルを現在のアプリプロセスへ登録します。これにより、
`CaskaydiaCove NF` のようなユーザーインストールフォントも、macOS の
フォントサービスを再起動せずに利用できます。

内蔵ターミナルは WebView 内の xterm.js で描画されます。`mono` と
`size` は内蔵ターミナルにも使われますが、フォントは CSS の
font-family スタックとして解決されます。`mono = "monospace"` の場合、
ターミナルは次の順にフォールバックします。

```text
"SF Mono", Menlo, Monaco, "Courier New", monospace
```

`mono` にカスタムフォント名を指定した場合は、その名前をフォールバック
スタックの先頭に置きます。利用可能な場合は、解決後のファミリー名と
PostScript 名も候補に追加します。ターミナル出力には、`SF Mono`、
`Menlo`、`Monaco`、`JetBrains Mono`、`Cascadia Mono`、
`CaskaydiaCove NF` などの実際の等幅フォントを指定してください。

### `[colors]`

内蔵の黒と緑を基調にしたベースデザインから、個別のセマンティックカラートークンを上書きします。

```toml
[colors]
fileListBackground = "#000301"
fileForeground = "#CFFFCF"
directoryForeground = "#6FFF80"
```

値はすべて、クォートされた `#RRGGBB` 形式の hex カラーです。各トークンは任意です。省略したトークンは tfx 内蔵のベースカラーを使います。

#### ファイルペイン / 一覧行

| キー | 説明 |
| --- | --- |
| `fileListBackground` | ファイル行とファイルペインの基準背景です。 |
| `fileListRowSelected` | 選択中ファイル行の背景です。 |
| `fileListRowDropTarget` | ドロップ対象になっている行の背景です。 |
| `directoryForeground` | ディレクトリ名とディレクトリ用グリフです。 |
| `fileForeground` | 通常ファイル名です。 |
| `secondaryForeground` | サイズ、種類、日付、パーミッションなどの副次カラムです。 |

#### ファイルペインの外枠 UI

| キー | 説明 |
| --- | --- |
| `headerForeground` | ファイルペインのカラムヘッダーテキストとアクセントです。 |
| `headerBackground` | ファイルペインのカラムヘッダー背景です。 |
| `titleBarBackgroundActive` | アクティブなファイルペインのタイトルバー背景です。 |
| `titleBarBackgroundInactive` | 非アクティブなファイルペインのタイトルバー背景です。 |
| `statusLineForegroundActive` | キーボード操作対象ペインのステータス行テキストです。 |
| `statusLineForegroundInactive` | 非アクティブ時のステータス行テキストです。 |
| `statusLineBackground` | ステータス行の背景です。 |

#### ペイン境界線

| キー | 説明 |
| --- | --- |
| `paneBorderKeyboardTarget` | 現在のキーボード操作対象の境界線です。 |
| `paneBorderActive` | アクティブだがキーボード操作対象ではないペインの境界線です。 |
| `paneBorderInactive` | 非アクティブペインの境界線です。 |

#### フォルダツリー

| キー | 説明 |
| --- | --- |
| `folderTreeBackground` | フォルダツリーの背景です。 |
| `folderTreeForeground` | フォルダツリー行のテキストです。 |
| `folderTreeSelectedForeground` | 選択中 / 現在位置のフォルダツリー行テキストです。 |
| `folderTreeFolderIcon` | フォルダツリーのフォルダアイコン色です。 |
| `folderTreeSelectedActive` | ツリーがキーボード操作対象のときの選択行背景です。 |
| `folderTreeSelectedInactive` | ツリーが非アクティブのときの選択行背景です。 |
| `folderTreeSectionHeader` | `PINNED` や `FOLDERS` などのセクションヘッダーです。 |

#### スプリットハンドル

| キー | 説明 |
| --- | --- |
| `splitHandleIdle` | 通常時のスプリットペインリサイズハンドルです。 |
| `splitHandleActive` | ドラッグ中のスプリットペインリサイズハンドルです。 |

#### Git ステータス

| キー | 説明 |
| --- | --- |
| `gitModified` | 変更済みファイルのバッジです。 |
| `gitAdded` | 追加ファイルのバッジです。 |
| `gitDeleted` | 削除ファイルのバッジです。 |
| `gitRenamed` | リネームファイルのバッジです。 |
| `gitUntracked` | 未追跡ファイルのバッジです。 |
| `gitIgnored` | ignore 対象ファイルのバッジです。 |
| `gitConflicted` | コンフリクト中ファイルのバッジです。 |

### `[opacity]`

内蔵デザインで使うセマンティック透過度トークンを上書きします。

```toml
[opacity]
background = 1
inactivePane = 0.5
disabledItem = 0.45
headerSecondary = 0.75
```

値はすべて `0` から `1` までの数値です。各トークンは任意です。省略したトークンは tfx 内蔵のベース値を使います。`background` が `1` 未満の場合、tfx はウィンドウ背景を透明化し、設定した背景透過度が見えるようにします。

| キー | デフォルト | 説明 |
| --- | --- | --- |
| `background` | `1` | テーマ背景面全体の透過度です。ファイル一覧、フォルダツリー、ヘッダー、タイトルバー、ステータス行、選択行、ドロップ対象行に適用されます。 |
| `inactivePane` | `0.5` | アクティブだがキーボード操作対象ではないペインのタイトル背景の強さです。 |
| `disabledItem` | `0.45` | 無効行の透過度です。現在は利用できない親ディレクトリ行で使われます。 |
| `headerSecondary` | `0.75` | リサイズインジケータなど、ヘッダー内の副次要素です。 |
| `selectedParentRow` | `0.8` | 選択中の親ディレクトリ行の背景強度です。 |
| `dropIndicator` | `0.85` | フォルダツリーの挿入インジケータの強度です。 |
| `dragPreview` | `0.96` | ピン留めフォルダのドラッグプレビューの透過度です。 |
| `dragPreviewShadow` | `0.18` | ピン留めフォルダのドラッグプレビュー影の透過度です。 |
| `subtleBackground` | `0.07` | ごく薄い背景です。現在はパス breadcrumb コントロールで使われます。 |

### `[startup]`

tfx 起動時のファイルペイン構成を設定します。

```toml
[startup]
layout = "single"
# rightFolder = "~/Downloads"
# rightFolders = ["~/Downloads", "~/Documents", "~/Desktop"]
```

| 値 | 動作 |
| --- | --- |
| `"single"` | 常に 1 ペイン 1 タブで起動します。デフォルトです。 |
| `"split"` | 常にスプリット表示で起動します。左は 1 タブで開始し、右は `rightFolders` / `rightFolder` があればそのフォルダをタブで開き、なければ前回の右ペインタブを使います。 |
| `"restore"` | 前回のシングル / スプリット状態と保存済みペインタブを復元します。 |

`rightFolders` は任意で、`layout = "split"` のときだけ使われます。有効な各フォルダを右ペインのタブとして開き、先頭のフォルダをアクティブにします。

```toml
[startup]
layout = "split"
rightFolders = ["~/Downloads", "~/Documents", "~/Desktop"]
```

単一タブだけを開く従来の `rightFolder` も引き続き使えます。

```toml
[startup]
layout = "split"
rightFolder = "~/Downloads"
```

どちらも絶対パスまたは `~` 付きのユーザーパスを指定できます。`rightFolders` が設定されている場合は `rightFolder` より優先されます。有効な右側起動フォルダがない場合、tfx は前回の右ペイン表示を維持します。

### `[shortcuts]`

`config.toml` に定義します。

```toml
[shortcuts]
reload = "cmd+shift+r"
togglePreview = "cmd+option+p"
goUp = "cmd+up"
rename = "ctrl+r"
copyPath = "cmd+option+c"
```

対応している修飾キー:

| トークン | 意味 |
| --- | --- |
| `cmd`, `command` | Command |
| `shift` | Shift |
| `opt`, `option`, `alt` | Option |
| `ctrl`, `control` | Control |

対応しているキー:

| トークン | 意味 |
| --- | --- |
| `r`、`.`、`[`、`]` などの 1 文字 | そのキー |
| `up`, `down`, `left`, `right` | 矢印キー |
| `escape`, `esc` | Escape |
| `delete`, `backspace` | Delete / Backspace。Forward Delete にも対応します。 |
| `return`, `enter` | Return |
| `tab` | Tab |
| `space` | Space |
| `backslash` | `\` |
| `f1` から `f20` | ファンクションキー |

対応しているアクションキー:

| キー | デフォルト | 動作 |
| --- | --- | --- |
| `reload` | `cmd+r` | アクティブなファイルペインを再読み込みします。 |
| `openTerminal` | `cmd+t` | アクティブフォルダで設定済みターミナルアプリを開きます。 |
| `togglePreview` | `cmd+p` | プレビューペインの表示 / 非表示を切り替えます。 |
| `toggleSplit` | `cmd+backslash` | スプリット表示の表示 / 非表示を切り替えます。 |
| `swapPanes` | `cmd+shift+x` | 左右ペインを入れ替えます。 |
| `focusSearch` | `cmd+f` | 検索フィールドにフォーカスします。 |
| `toggleHidden` | `cmd+shift+.` | 隠しファイルの表示 / 非表示を切り替えます。 |
| `goBack` | `cmd+[` | 戻ります。 |
| `goForward` | `cmd+]` | 進みます。 |
| `goUp` | `cmd+up` | 親フォルダへ移動します。 |
| `openItem` | `cmd+o` | 選択項目を開きます。 |
| `newFolder` | `cmd+n` | フォルダを作成し、インライン名前編集を開始します。 |
| `newFile` | `cmd+shift+n` | ファイルを作成し、インライン名前編集を開始します。 |
| `rename` | `cmd+return` | 選択項目の名前をインラインで変更します。 |
| `moveToTrash` | `cmd+backspace` | 選択項目をゴミ箱に移動します。 |
| `compressToZip` | `cmd+option+z` | 選択項目を zip アーカイブに圧縮します。 |
| `extractZip` | `cmd+option+e` | 選択中の zip アーカイブを展開します。 |
| `copyItems` | `cmd+c` | 選択項目をコピーします。 |
| `cutItems` | `cmd+x` | 選択項目をカットします。 |
| `pasteItems` | `cmd+v` | アクティブフォルダにペーストします。 |
| `movePasteItems` | `cmd+option+v` | アクティブフォルダに移動ペーストします。 |
| `selectAll` | `cmd+a` | 表示中の項目をすべて選択します。 |
| `revealInFinder` | `cmd+option+r` | 選択項目を Finder で表示します。 |
| `copyPath` | `cmd+option+c` | 選択項目のパスをコピーします。未選択時は現在フォルダのパスをコピーします。 |
| `newTab` | `cmd+shift+t` | アクティブペインの現在フォルダで新規タブを開きます。 |
| `closeTab` | `cmd+w` | アクティブタブを閉じます。ペイン内の最後のタブは閉じません。 |
| `previousTab` | `cmd+shift+[` | アクティブペインの前のタブを選択します。 |
| `nextTab` | `cmd+shift+]` | アクティブペインの次のタブを選択します。 |
| `toggleTerminalPane` | `cmd+option+t` | 内蔵ターミナルペインの表示 / 非表示を切り替えます。 |
| `focusTerminalPane` | `cmd+option+shift+t` | 内蔵ターミナルペインを表示してフォーカスします。 |

2 つのアクションが同じショートカットに解決された場合、tfx は設定エラーを報告し、内蔵ショートカットデフォルトを使います。

同じアクションキーは、ツールバーボタン、View メニュー、キーボード処理、ファイル一覧のコンテキストメニューで使われます。たとえば `rename` を変更すると、行コンテキストメニューの表示と、インラインリネームを開始するショートカットの両方が更新されます。

### `[terminal]`

ターミナルボタンと `openTerminal` ショートカットで使うアプリを上書きします。

```toml
[terminal]
app = "/Applications/Ghostty.app"
```

bundle identifier でも指定できます。

```toml
[terminal]
bundleIdentifier = "com.googlecode.iterm2"
```

`app` と `bundleIdentifier` の両方がある場合は `app` が使われます。このテーブルを省略した場合、tfx は `/System/Applications/Utilities/Terminal.app` を使います。

### `[openWith]`

拡張子ごとに、ファイルを開くアプリを上書きします。キーは先頭のドットを除いた拡張子です。値にはアプリの絶対パスまたは bundle identifier を指定できます。

```toml
[openWith]
md = "com.microsoft.VSCode"
txt = "/System/Applications/TextEdit.app"
pdf = "/Applications/Preview.app"
```

複合拡張子のキーはクォートできます。

```toml
[openWith]
"tar.gz" = "com.example.ArchiveApp"
```

未設定の拡張子は通常の macOS デフォルトアプリ動作を使います。ディレクトリ、zip ナビゲーション、アーカイブ内部ファイルは既存の tfx 動作を維持します。

### `[preview]`

プレビュー動作を設定します。`default` は `[preview.extensions]` に未設定の拡張子へ適用されます。

```toml
[preview]
default = "auto"
```

| キー | 型 | デフォルト | 説明 |
| --- | --- | --- | --- |
| `default` | string | `"auto"` | 拡張子ごとの上書きがない場合のプレビューモードです。 |

プレビューモード:

| モード | 動作 |
| --- | --- |
| `auto` | tfx の既定判定を使います。対応ファイルではレンダリング / ソース表示の切り替えができます。 |
| `rendered` | その拡張子をレンダリング表示に固定します。 |
| `text` | その拡張子を Raw text 表示に固定します。 |
| `none` | その拡張子の内容プレビューを無効にします。ファイル情報は表示されます。 |

### `[preview.extensions]`

拡張子ごとのプレビュー動作を上書きします。キーは先頭のドットを除いた拡張子です。複合拡張子のキーはクォートできます。

```toml
[preview.extensions]
md = "rendered"
markdown = "rendered"
txt = "text"
log = "text"
json = "text"
zip = "none"
"tar.gz" = "none"
```

### `[preview.markdown]`

Markdown 固有のプレビュー動作を設定します。

```toml
[preview.markdown]
externalImages = "button"
```

| キー | 型 | デフォルト | 説明 |
| --- | --- | --- | --- |
| `externalImages` | string | `"button"` | `button`、`always`、`never` を指定します。 |

Markdown の外部画像モード:

| モード | 動作 |
| --- | --- |
| `button` | 現在のプレビューで画像読み込みボタンを押すまで、外部 `https:` 画像をブロックします。 |
| `always` | 外部 `https:` 画像を最初から読み込みます。 |
| `never` | 外部画像を常にブロックします。 |

### `[[commands]]`

ファイル一覧のコンテキストメニューにユーザー定義コマンドを追加します。コマンドは、現在の選択内容がフィルタに一致するときだけ表示されます。`shortcut` を設定した場合、そのショートカットは組み込みショートカットより先に判定されます。

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

対応キー:

| キー | 型 | デフォルト | 説明 |
| --- | --- | --- | --- |
| `name` | string | 必須 | メニュー表示名です。 |
| `run` | string | 必須 | 実行するコマンドライン、または複数行スクリプト本文です。 |
| `extensions` | string array | 全拡張子 | 対象ファイル拡張子です。先頭のドットは不要です。全対象にする場合は `["*"]` を使えます。 |
| `target` | string | `"any"` | `file`、`folder`、`current`、`any` を指定します。`current` は現在のフォルダを対象にし、ファイル一覧の空白部分のメニューに表示されます。 |
| `selection` | string | `"any"` | `single`、`multiple`、`any` を指定します。`target = "current"` では無視されます。 |
| `requireGit` | boolean | `false` | Git ワークツリー内でだけ表示します。 |
| `terminal` | boolean | `false` | stdout/stderr を内蔵ターミナルペインの Output タブへ表示します。 |
| `shortcut` | string | なし | `[shortcuts]` と同じ文法のショートカットです。 |
| `shell` | string | `$SHELL` または `/bin/zsh` | コマンド実行に使うシェルです。 |

`run` で使えるトークン:

| トークン | 値 |
| --- | --- |
| `{path}` | 最初に選択された項目のパスです。選択がない場合は現在のフォルダです。 |
| `{paths}` | 選択されたすべての項目のパスです。空白区切りです。選択がない場合は現在のフォルダです。 |
| `{dir}` | 最初に選択された項目の親フォルダです。選択がない場合は現在のフォルダです。 |
| `{name}` | 最初に選択された項目の拡張子付きファイル名です。フォルダ選択時はフォルダ名です。 |
| `{stem}` | 最初に選択された項目の拡張子なしファイル名です。 |
| `{ext}` | 最初に選択された項目の拡張子です。先頭のドットは付きません。フォルダでは空文字列です。 |
| `{cwd}` | 選択内容に関係なく、現在のフォルダです。 |
| `{scripts}` | `config.toml` と同じ場所にある `scripts` フォルダです。必要に応じて自動作成されます。 |

パス系トークンは自動的にシェルクォートされます。`{scripts}` はそのままのパスとして置換されるため、空白を含む可能性がある場合は `run` 側でクォートしてください。`$NAME` または `${NAME}` 形式の環境変数は、トークン置換の前に展開されます。

ユーザー定義コマンドは専用の別プロセスで実行されます。プロセスの working directory は、最初に選択された項目の親フォルダです。選択がない場合は現在のフォルダです。`cd {dir}` はそのコマンドプロセス内だけに作用し、すでに開いている内蔵ターミナルの対話シェルのカレントディレクトリは変更しません。`terminal = true` の場合、stdout/stderr を内蔵ターミナルペインの Output タブへ表示します。`terminal = false` の場合、stdout/stderr は破棄されます。

ユーザー定義コマンドに不正な値がある場合、設定エラーのアラートにはコマンド番号と、すでに解析できていれば `name` も表示されます。長い `config.toml` でも、不正な `target` などを見つけやすくするためです。

複数行スクリプトは TOML のリテラル文字列で記述できます。実行時に一時スクリプトファイルへ書き出され、`shell` 経由で実行されます。

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

`.xcodeproj` フォルダは、scheme 名や `.app` 名を固定せず、`xcodebuild` から先頭の scheme と wrapper 名を取得してビルド / 起動できます。

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

複数の scheme がある場合、このサンプルは `xcodebuild -list -json` が返す先頭の scheme を使います。

## フォントロール対応

ユーザー向け設定は小さく保ち、アプリ内部で各 UI ロールへ割り当てます。

| UI ロール | ファミリー元 | サイズ |
| --- | --- | --- |
| ファイル一覧行 | `mono` | `size` |
| 親ディレクトリ行 | `mono` | `size` |
| フォルダツリー行 | `ui` | `size` |
| パス / 検索コントロール | `mono` | `size` |
| Raw text プレビュー | `mono` | `size` |
| JSON プレビュー | `mono` | `size` |
| CSV プレビュー | `mono` | `size` |
| 内蔵ターミナルペイン | `mono` | `size` |
| ヘッダー | `ui` | `size - 1`、最小 `8` |
| ペインタイトルのパス欄 | `ui` | `size - 1`、最小 `8` |
| ステータス行 | `mono` | `size - 2`、最小 `8` |
| キャプション / 補助テキスト | `ui` | `size - 2`、最小 `8` |
| 設定タイトル / 空プレビューアイコンのスケール | `ui` | `size + 2` |

## 例

システム UI フォントと、少し大きい等幅ファイル一覧を使う例:

```toml
version = 1

[font]
ui = "system"
mono = "SF Mono"
size = 14
```

日本語表示に向いた UI フォントと、別の等幅フォントを使う例:

```toml
version = 1

[font]
ui = "Hiragino Sans"
mono = "Menlo"
size = 13
```

ファイル操作周りに JetBrains Mono を使う例:

```toml
version = 1

[font]
ui = "system"
mono = "JetBrains Mono"
size = 13
```

内蔵ターミナルとその他の等幅表示に Menlo を使う例:

```toml
version = 1

[font]
ui = "system"
mono = "Menlo"
size = 13
```

内蔵ターミナルは次のカラートークンも使います。

| ターミナル領域 | カラートークン |
| --- | --- |
| ターミナル背景 | `fileListBackground` |
| ターミナル文字 | `fileForeground` |
| ターミナルカーソル | `directoryForeground` |
| ターミナル選択範囲 | `fileListRowSelected` |

主要なファイル / フォルダ色だけを変更する例:

```toml
version = 1

[colors]
fileForeground = "#E6FFE6"
directoryForeground = "#80FF9A"
fileListRowSelected = "#12351E"
```

ファイル一覧の読みやすさを保ちながら、ペイン外枠 UI を少し暗くする例:

```toml
version = 1

[colors]
headerForeground = "#58D66E"
statusLineForegroundInactive = "#2B7A3A"
paneBorderInactive = "#174021"
```

### カラーサンプル

次のサンプルは `config.toml` にコピーして、トークン単位で調整できます。各サンプルはカラーだけを定義します。フォント設定は同じファイルの `[font]` に追加できます。

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

アクティブ / 非アクティブの差を強める例:

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

## エラー処理

tfx は次のような内容を設定エラーとして扱います。

- `size: 13` のような、不正な代入構文
- `ui` または `mono` が文字列ではない
- `size` が数値ではない
- `size` が `8...40` の範囲外
- カラー値がクォートされた `#RRGGBB` 文字列ではない
- 透過度が `0...1` の範囲外
- アプリ起動設定の代入または文字列構文が不正
- プレビューモード、Markdown 外部画像モード、拡張子キー、代入構文が不正
- ユーザー定義コマンドの代入、boolean、target、selection、shortcut、複数行スクリプト終端が不正
- 設定されたターミナル / open-with アプリが利用時に見つからない
- 未対応の `version`

エラーが見つかっても tfx はクラッシュしません。デザインとショートカットの解析エラーでは内蔵デフォルトにフォールバックし、解析エラーのアラートを表示します。アプリ起動エラーは、設定された操作を使ったタイミングで表示されます。

## 今後の予定

組み込みの設定テーブルを超えるカスタマイズとして、Lua スクリプト対応は今後の予定に残っています。
