# tfx 詳細設計書

## 1. 概要

`tfx` は macOS 向けの SwiftUI アプリケーションであり、ターミナル風の外観とキーボード中心の操作体系を持つファイルマネージャーである。主要画面は、左のフォルダツリー、中央のファイルペイン、右のプレビューペインで構成する。中央のファイルペインは単一表示と左右分割表示を切り替えられる。

本書は現行実装を基準に、画面構成、状態管理、ファイル操作、プレビュー、永続化、エラー処理の詳細を定義する。

## 2. 対象範囲

### 2.1 対象機能

- フォルダツリーによるディレクトリ移動
- 左右ファイルペインによるファイル一覧表示
- 単一ペイン / 分割ペイン切り替え
- ファイル選択、複数選択、範囲選択
- 戻る / 進む / 親フォルダ移動
- 新規フォルダ作成、リネーム、ゴミ箱移動
- コピー、カット、ペースト、ドラッグアンドドロップ移動
- 同名ファイル競合時の解決
- Finder 表示、パスコピー、Terminal.app 連携
- 検索、隠しファイル表示、ソート
- PDF、動画、Markdown、Quick Look プレビュー
- ピン留めフォルダ
- ピン留めフォルダのドラッグ並べ替え
- レイアウト、カラム設定、ウィンドウ状態の永続化

### 2.2 対象外

- iOS / iPadOS 向けのファイル管理機能
- Developer ID 署名、notarization、配布インストーラ
- Finder 拡張、Spotlight インデックス連携
- ネットワーク越しのファイル操作専用処理
- 権限昇格を伴う管理者操作

## 3. システム構成

### 3.1 アプリ構成

| ファイル | 役割 |
| --- | --- |
| `tfx/tfxApp.swift` | アプリケーションのエントリーポイント。`WindowGroup` に `ContentView` を表示する。 |
| `tfx/ContentView.swift` | macOS では `TerminalFileManagerView` を表示する。非 macOS では未対応表示を行う。 |
| `tfx/TerminalFileManagerView.swift` | メイン画面、状態モデル、ファイル操作、プレビュー、補助 View を含む中心実装。 |
| `docs/file-manager-implementation-plan.md` | 実装計画と進捗管理。 |

### 3.2 技術スタック

| 分類 | 使用技術 |
| --- | --- |
| UI | SwiftUI |
| macOS 連携 | AppKit、NSWorkspace、NSOpenPanel、NSAlert、NSPasteboard |
| PDF プレビュー | PDFKit |
| 動画プレビュー | AVKit |
| Markdown プレビュー | WebKit |
| 汎用プレビュー | QuickLookUI |
| ファイル種別 | UniformTypeIdentifiers |
| 状態永続化 | `UserDefaults` / `@AppStorage` |

## 4. 画面設計

### 4.1 全体レイアウト

`TerminalFileManagerView` は次の階層で画面を構成する。

1. ヘッダー
2. フォルダツリーペイン
3. ファイル表示エリア
4. プレビューペイン

ヘッダーにはナビゲーション、検索、ソート、ファイル操作、表示切り替え、Terminal.app 起動、パスコピーの操作を配置する。フォルダツリー、ファイルペイン、プレビューの幅はドラッグ操作で変更できる。

### 4.2 フォルダツリーペイン

`FolderTreePane` は `/` をルートとする単一ツリーを表示する。ピン留めフォルダが存在する場合は `PINNED` セクションを先頭に表示し、その後に通常の `FOLDERS` セクションを表示する。ピン留めフォルダは `PINNED` セクション内でドラッグして順番を変更できる。この並べ替えはアプリ内の表示順だけを変更し、実際のフォルダは移動しない。`PINNED` セクションの行はショートカットとして扱い、子フォルダは展開しない。

フォルダツリーは表示とナビゲーション専用とする。フォルダツリーへのドロップや、フォルダツリー行のコンテキストメニューからのペーストは提供しない。

フォルダ行は `FolderTreeRow` が担当する。各行は展開 / 折りたたみ、ディレクトリ移動、ドラッグアンドドロップ受け入れ、コンテキストメニューを持つ。

### 4.3 ファイルペイン

`FilePane` はファイル一覧をターミナル風のテーブルとして表示する。分割表示では左ペインと右ペインがそれぞれ独立した `FileBrowserModel` を持つ。単一表示ではアクティブペインのみ表示する。

ファイル一覧の先頭には、親フォルダ移動用の `..` 行を表示する。ファイル行は `FileRow` が担当し、ファイル種別アイコン、モード、名前、サイズ、種類、更新日時、作成日時、権限をカラムとして表示する。

### 4.4 プレビューペイン

`PreviewPane` はアクティブペインの `primarySelectedItem` を対象にプレビューを表示する。選択がない場合は `No preview` を表示する。プレビュー種別は `PreviewKind` が URL の content type と拡張子から判定する。

| 種別 | View | 判定 |
| --- | --- | --- |
| PDF | `PDFPreview` | UTType が `.pdf` に準拠 |
| 動画 | `VideoPreview` | UTType が `.movie` に準拠 |
| Markdown | `MarkdownPreview` | 拡張子が `md`、`markdown`、`mdown`、`mkd` |
| その他 | `QuickLookPreview` | 上記以外 |

## 5. 状態管理設計

### 5.1 ルート状態

`TerminalFileManagerView` は次の状態を保持する。

| 状態 | 種別 | 内容 |
| --- | --- | --- |
| `leftModel` | `@StateObject` | 左ファイルペインの状態モデル |
| `rightModel` | `@StateObject` | 右ファイルペインの状態モデル |
| `isPreviewVisible` | `@AppStorage` | プレビュー表示状態 |
| `isSplitViewVisible` | `@AppStorage` | 分割表示状態 |
| `activePaneRawValue` | `@AppStorage` | アクティブなファイルペイン |
| `activeAreaRawValue` | `@AppStorage` | キーボード操作対象領域 |
| `folderTreeWidth` | `@AppStorage` | フォルダツリー幅 |
| `previewWidth` | `@AppStorage` | プレビュー幅 |
| `fileSplitRatio` | `@AppStorage` | 左右ファイルペイン比率 |
| `fileNameColumnWidth` | `@AppStorage` | ファイル名カラム幅 |
| `fileColumnConfigurationRaw` | `@AppStorage` | ファイル一覧カラム設定 |

アクティブモデルは `activePane` により `leftModel` または `rightModel` から選択する。フォルダツリーとプレビューはアクティブモデルを参照する。

### 5.2 ファイルブラウザ状態

`FileBrowserModel` はディレクトリ単位の状態と操作を集約する。

| 状態 | 内容 |
| --- | --- |
| `currentDirectory` | 現在表示中のディレクトリ |
| `items` | 検索、隠しファイル設定、ソート適用後の表示項目 |
| `allItems` | 現在ディレクトリ内の全項目 |
| `selectedItemIDs` | 選択中ファイルの URL セット |
| `primarySelectedItemID` | プレビューや主要操作の対象 |
| `isParentDirectorySelected` | `..` 行が選択中かどうか |
| `folderTreeSelection` | フォルダツリー上の選択 URL |
| `expandedFolders` | 展開中フォルダ |
| `folderChildrenCache` | フォルダツリーの子フォルダキャッシュ |
| `backStack` / `forwardStack` | ナビゲーション履歴 |
| `clipboard` | アプリ内コピー / 移動用クリップボード |
| `pinnedFolders` | ピン留めフォルダ |
| `availableCapacityText` | 現在ボリュームの空き容量表示 |

## 6. データモデル設計

### 6.1 FileItem

`FileItem` はファイル一覧の 1 行を表す値型である。識別子は URL とする。

| プロパティ | 内容 |
| --- | --- |
| `url` | ファイルまたはフォルダの URL |
| `isDirectory` | ディレクトリ判定 |
| `isHidden` | 隠しファイル判定 |
| `size` | ファイルサイズ |
| `modified` | 更新日時 |
| `created` | 作成日時 |
| `kind` | ローカライズ済み種別説明 |
| `permissions` | POSIX 権限 |

表示用プロパティとして `name`、`mode`、`sizeText`、`kindText`、`modifiedText`、`createdText`、`permissionsText` を提供する。日付は `yyyy-MM-dd HH:mm:ss` 形式で表示する。

### 6.2 カラム設定

`FileListColumn` はファイル一覧のカラム種別を定義する。`name` カラムは常に表示し、その他のカラムは表示 / 非表示と順序変更を許可する。

`FileListColumnConfiguration` は `column:visible` 形式の文字列を `UserDefaults` に保存可能な設定として扱う。不正な値や不足したカラムがある場合は既定カラムを補完する。

## 7. 処理設計

### 7.1 起動処理

1. `tfxApp` が `ContentView` を表示する。
2. macOS では `TerminalFileManagerView` を生成する。
3. `TerminalFileManagerView.init()` が `UserDefaults` から左右ペインの最終ディレクトリを復元する。
4. 復元先が存在しない場合は、左ペインはホーム、右ペインは Downloads を初期値にする。
5. 各 `FileBrowserModel` が `reload()` を実行し、フォルダツリーの祖先と現在フォルダを展開する。

### 7.2 ディレクトリ読み込み

`FileBrowserModel.reload()` は `FileManager.default.contentsOfDirectory` により現在ディレクトリの内容を読み込む。読み込み時に `FileItem` を生成し、空き容量を更新した後、`applyFiltersAndSort()` を実行する。

読み込みに失敗した場合は `show(_:)` によりエラーメッセージを設定し、画面側の alert で表示する。

### 7.3 検索・フィルタ・ソート

`searchText`、`showHiddenFiles`、`sortKey`、`sortAscending` の変更時に `applyFiltersAndSort()` を実行する。

フィルタ条件は次の通り。

- 隠しファイル非表示時は `isHidden == true` の項目を除外する。
- 検索文字列が空でない場合は、ファイル名に対する大文字小文字を区別しない部分一致で絞り込む。

ソートではディレクトリを常にファイルより前に置く。同一キーの場合は名前で昇順比較する。

### 7.4 ナビゲーション

`navigate(to:recordsHistory:)` がディレクトリ移動の中心処理である。履歴記録ありの場合は現在ディレクトリを `backStack` に追加し、`forwardStack` をクリアする。移動後は選択状態をクリアし、移動先の祖先フォルダと移動先フォルダを展開してから `reload()` を実行する。

戻る / 進むは `goBack()` / `goForward()` が担当する。親フォルダ移動は `goUp()` が担当し、ルートでは何もしない。

### 7.5 選択操作

単一選択は `select(_:)` が担当する。Command-click による追加 / 解除選択では `extending` を `true` にする。

範囲選択は `selectRange(to:)` および `selectRange(toRow:fallbackCurrentRow:)` が担当する。範囲の基準には `selectionAnchorItemID` を使用する。

`..` 行は通常ファイルとは別に `isParentDirectorySelected` で管理する。`..` 選択中に Enter を押すと `goUp()` を実行する。

### 7.6 ファイル操作

| 操作 | メソッド | 概要 |
| --- | --- | --- |
| 新規フォルダ | `createFolder()` | 名前入力後、同名があれば連番付きの一意名で作成する。 |
| リネーム | `renameSelectedItem()` | 単一選択時のみ実行し、同名があれば一意名へ変更する。 |
| ゴミ箱移動 | `moveSelectedItemsToTrash()` | `FileManager.default.trashItem` を使い完全削除しない。 |
| Finder 表示 | `revealSelectedItemsInFinder()` | `NSWorkspace.shared.activateFileViewerSelecting` を使う。 |
| パスコピー | `copyPath(_:)` | `NSPasteboard.general` に文字列としてコピーする。 |
| Terminal 起動 | `openTerminal(at:)` | Terminal.app を指定ディレクトリで開く。 |

操作後は関連するフォルダツリーキャッシュを更新し、ファイル一覧を再読み込みする。

### 7.7 コピー / カット / ペースト

コピーとカットは `FileClipboard` に URL 配列と操作種別を保存し、同時に `NSPasteboard` へ URL を書き込む。ペーストはアプリ内の `clipboard` を参照して実行する。

ペースト時は各 URL について `destinationDecision(for:in:operation:)` を呼び出し、移動先を決定する。同名ファイルが存在する場合は `NSAlert` で次の選択肢を表示する。

| 選択肢 | 動作 |
| --- | --- |
| Replace | 既存項目を削除して置き換える。 |
| Keep Both | 連番付きの一意名でコピー / 移動する。 |
| Skip | 該当項目を処理しない。 |
| Cancel | 残りの処理を中止する。 |

移動操作の完了後はアプリ内クリップボードをクリアする。

### 7.8 ドラッグアンドドロップ

`FileRow`、`FilePane`、`FolderTreeRow`、`FolderTreePane` は `UTType.fileURL` のドロップを受け入れる。`FileDropDelegate` が `FileBrowserModel.moveDroppedFiles(_:to:completion:)` を呼び出し、対象ディレクトリへ移動する。

ドロップされた URL がセキュリティスコープ付きリソースの場合は、移動中のみ `startAccessingSecurityScopedResource()` を呼び出す。

### 7.9 プレビュー

プレビューは選択中の主項目 URL を入力にして View を切り替える。PDF、動画、Markdown は専用 View を使い、それ以外は Quick Look を使用する。

Markdown は外部ライブラリを使わず、簡易パーサーで HTML に変換して `WKWebView` に表示する。対応する主な Markdown 要素は見出し、段落、リスト、コードブロック、引用、インラインコード、強調、リンクである。

将来の Markdown プレビュー拡張では、ルビ表示、数式表示、Mermaid 図表、独自記法、CSS カスタマイズを対象とする。設定は TOML で管理し、KaTeX、MathJax、Mermaid、CSS を個別に指定できるようにする。

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

## 8. 永続化設計

### 8.1 UserDefaults キー

| キー | 内容 |
| --- | --- |
| `TerminalFileManager.leftDirectory` | 左ペインの最終ディレクトリ |
| `TerminalFileManager.rightDirectory` | 右ペインの最終ディレクトリ |
| `TerminalFileManager.isPreviewVisible` | プレビュー表示状態 |
| `TerminalFileManager.isSplitViewVisible` | 分割表示状態 |
| `TerminalFileManager.activePane` | アクティブペイン |
| `TerminalFileManager.activeArea` | アクティブ領域 |
| `TerminalFileManager.folderTreeWidth` | フォルダツリー幅 |
| `TerminalFileManager.previewWidth` | プレビュー幅 |
| `TerminalFileManager.fileSplitRatio` | ファイルペイン分割比率 |
| `TerminalFileManager.fileNameColumnWidth` | ファイル名カラム幅 |
| `TerminalFileManager.fileColumnConfiguration` | カラム表示 / 順序設定 |
| `TerminalFileManager.pinnedFolders` | ピン留めフォルダ一覧 |

ピン留めフォルダ一覧は保存された配列順を表示順として扱う。新規ピン留め時は末尾に追加し、ドラッグ並べ替え時は更新後の順序を保存する。並べ替えは macOS のファイルドラッグアンドドロップではなく、アプリ内ドラッグジェスチャで処理する。

### 8.2 ウィンドウ状態

`WindowFrameAutosaver` が AppKit の `setFrameAutosaveName(_:)` を使用し、`TerminalFileManagerWindow` 名でウィンドウフレームを保存する。

## 9. キーボード操作設計

`KeyboardEventHandler` は `NSViewRepresentable` で `NSView` を埋め込み、`keyDown(with:)` を SwiftUI 側へ橋渡しする。検索フィールドがフォーカス中の場合は独自キー処理を無効化する。

| キー | 動作 |
| --- | --- |
| 上 / 下 | ファイルペインまたはフォルダツリーの選択移動 |
| Shift + 上 / 下 | ファイルペインの範囲選択 |
| 左 / 右 | フォルダツリーとファイルペイン、または左右ペイン間のフォーカス移動 |
| Enter | 選択ファイルを開く、または選択フォルダへ移動 |
| Command + [ / ] | 戻る / 進む |
| Command + 上 | 親フォルダへ移動 |
| Command + F | 検索フォーカス |
| Command + N | 新規フォルダ |
| Delete | ゴミ箱へ移動 |
| Command + C / X / V | コピー / カット / ペースト |
| Command + A | 表示中項目をすべて選択 |
| Command + R | 再読み込み |
| Command + Shift + T | Terminal.app 起動 |
| Command + Shift + . | 隠しファイル表示切り替え |

## 10. エラー処理設計

ファイル操作、ディレクトリ読み込み、Terminal.app 起動で発生したエラーは `FileBrowserModel.show(_:)` に集約する。モデルは `errorMessage` と `isShowingError` を更新し、`TerminalFileManagerView` が alert として表示する。

同名競合はエラーではなくユーザー判断が必要な状態として扱い、専用の競合解決ダイアログを表示する。

## 11. セキュリティ・安全性

- 削除相当の操作は完全削除ではなく Trash へ移動する。
- 同名ファイルは黙って上書きせず、必ず競合解決を行う。
- ドラッグアンドドロップ元がセキュリティスコープ付きリソースの場合、アクセス期間を処理中に限定する。
- 権限不足などの失敗はユーザーに alert で通知する。
- 管理者権限を要求する操作は提供しない。

## 12. 性能設計

- フォルダツリーは全ディレクトリを再帰的に走査せず、展開されたフォルダの子フォルダのみ読み込む。
- フォルダツリーの子フォルダは `folderChildrenCache` に保持する。
- ファイル一覧は `LazyVStack` を使用して行描画の負荷を抑える。
- 検索とソートは現在ディレクトリ内の `allItems` に対して実行する。
- ファイル操作後は対象ディレクトリのキャッシュとファイル一覧を更新する。

## 13. 既知の制約

- `FileBrowserModel` と多くの View が単一ファイルに同居しているため、機能追加時の見通しが悪くなりやすい。
- アプリ内ペーストは `FileClipboard` を参照するため、Finder など外部アプリからのペースト内容は現在の中心設計では扱わない。
- Markdown プレビューは簡易変換であり、CommonMark 完全準拠ではない。
- フォルダツリーは隠しフォルダを表示しない。
- コピー / 移動処理は同期的に実行されるため、大容量ファイルでは UI 応答性に影響する可能性がある。
- ファイル監視は行わず、外部変更の反映は再読み込み操作または一部操作後の reload に依存する。

## 14. 将来の分割方針

現行実装を保ちながら保守性を高める場合、次の単位でファイル分割する。

| 分割先候補 | 移動対象 |
| --- | --- |
| `Models/FileBrowserModel.swift` | `FileBrowserModel`、`FileItem`、`FileSortKey`、`FileClipboard` |
| `Views/TerminalFileManagerView.swift` | ルート画面とヘッダー |
| `Views/FilePane.swift` | `FilePane`、`FileRow`、`ParentDirectoryRow`、`FileIcon` |
| `Views/FolderTreePane.swift` | `FolderTreePane`、`FolderTreeRow`、`FolderTreeSectionHeader` |
| `Views/PreviewPane.swift` | `PreviewPane` と各プレビュー View |
| `Views/FileListSettingsView.swift` | カラム設定 UI と設定モデル |
| `Platform/AppKitBridges.swift` | `WindowFrameAutosaver`、`KeyboardEventHandler` |

## 15. テスト観点

### 15.1 手動確認

- 初回起動時にホームと Downloads が左右ペインへ表示されること。
- 戻る / 進む / 親フォルダ移動で履歴と一覧が整合すること。
- フォルダツリークリック、ファイルダブルクリック、キーボード操作で同じディレクトリ移動結果になること。
- 複数選択と範囲選択がプレビュー対象を壊さないこと。
- コピー / カット / ペーストで同名競合ダイアログが表示されること。
- Trash 移動後に一覧とフォルダツリーキャッシュが更新されること。
- PDF、動画、Markdown、その他ファイルのプレビューが切り替わること。
- レイアウト幅、表示ペイン、カラム設定、ピン留めフォルダが再起動後に復元されること。

### 15.2 自動テスト候補

- `FileListColumnConfiguration` の raw value 復元、補完、表示切り替え、順序変更。
- `FileBrowserModel` のフィルタ、ソート、選択、履歴操作。
- `uniqueDestination(for:in:)` の連番生成。
- `PreviewKind` の拡張子 / UTType 判定。
- Markdown 簡易変換の HTML エスケープ。
