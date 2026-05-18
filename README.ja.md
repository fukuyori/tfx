# tfx

**Terminal-inspired interface File eXplorer**<br>
読み方: **タフィックス**<br>
Version: **0.5.1**

[English](README.md) | 日本語

`tfx` は、ターミナル風の見た目とキーボード操作を中心にした macOS 向けファイルマネージャーです。フォルダツリー、スプリット表示、プレビュー、ドラッグアンドドロップ、Terminal.app 連携を備えています。

## スクリーンショット

![tfx スクリーンショット](images/screenshot.png)

## 機能

- ターミナル風のファイル一覧 UI
- `/` から始まる単一フォルダツリー
- ピン留めフォルダの常時表示
- 初回起動時に Home / Documents / Downloads をピン留め
- ピン留めフォルダのドラッグ並べ替え
- 単独ビュー / スプリットビュー切り替え
- 左右ペイン間のドラッグアンドドロップ
- Option ドラッグによるコピー、通常ドラッグによる移動
- アクティブビューのハイライト表示
- `..` 行による親フォルダ移動
- Backspace による親フォルダ移動
- クリック可能な breadcrumb パス移動
- PDF / 動画 / Markdown / Quick Look プレビュー
- Markdown / HTML / CSV / JSON プレビューの「描画」/「ソース」表示切り替え
- CSV / TSV をスクロール可能なテーブルで表示、JSON は pretty-print 表示
- TOML / YAML / INI / log などの設定ファイルをプレーンテキストでプレビュー
- 選択中のファイル / フォルダのコンパクトなメタデータ表示
- プレビュー表示のオン / オフ切り替え
- zip ファイルを展開せずに閲覧
- 閲覧中の zip ファイルからファイルをコピー
- Terminal.app を現在フォルダで開く
- New File / New Folder / Rename / Move to Trash / Reveal in Finder
- 「このアプリケーションで開く」サブメニュー（候補アプリ一覧と「その他…」ピッカー）
- 自動更新: 外部からのディレクトリ変更を検知してファイル一覧を自動リフレッシュ
- 選択項目を zip ファイルに圧縮
- zip ファイルを展開
- Copy / Cut / Paste、Finder クリップボード互換、同名ファイル競合ダイアログ
- Finder エイリアスとディレクトリシンボリックリンクのナビゲーション解決
- 検索、隠しファイル表示、ソート
- Command-click による複数選択
- Shift + 上下キー、Shift-click、マウスドラッグによる範囲選択
- 進捗表示とキャンセルに対応したサブフォルダ検索
- ファイル種別に応じたアイコン表示
- ファイル一覧カラムの表示 / 非表示、順番変更
- `NAME` ヘッダーのドラッグによるファイル名カラム幅変更
- ウィンドウサイズ、表示状態、ペイン幅、アクティブペイン、開いているフォルダの復元

## キーボード操作

- `↑ / ↓`: アクティブなファイルビューまたはフォルダツリーの選択移動
- `Shift + ↑ / ↓`: ファイルビューの範囲選択
- `← / →`: フォルダツリーとファイルビュー間のフォーカス移動
- `Enter`: ファイルを開く、またはフォルダへ移動
- `Command + [` / `Command + ]`: 戻る / 進む
- `Command + ↑`: 親フォルダへ移動
- `Backspace`: 親フォルダへ移動
- `Command + F`: 検索
- `Command + N`: 新規フォルダ
- `Delete`: ゴミ箱へ移動
- `Command + Backspace`: ゴミ箱へ移動
- `Command + C / X / V`: コピー / カット / ペースト
- `Command + Option + V`: 移動ペースト
- `Command + A`: すべて選択
- `Command + R`: 再読み込み
- `Command + Shift + T`: 現在フォルダで Terminal.app を開く
- `Command + Shift + .`: 隠しファイル表示切り替え

## コマンドラインから起動

インストール済みアプリを現在のディレクトリで開く:

```sh
open -a tfx "$PWD"
```

任意のディレクトリを指定:

```sh
open -a tfx /path/to/folder
```

`-n` や `--args` は使わず、フォルダを `open` の対象として渡してください。`--args` は起動引数扱いになり、macOS の通常のフォルダオープン経路を通りません。

`open -a tfx` でアプリが見つからない、または別のビルドが起動する場合は、アプリのパスを直接指定します。

```sh
open -a /Applications/tfx.app "$PWD"
```

`/usr/local/bin/tfx` などにラッパーを用意している場合は、次のように相対パスも指定できます。

```sh
tfx .
```

## ビルド

```sh
xcodebuild -project tfx.xcodeproj -scheme tfx -destination 'platform=macOS' -derivedDataPath /tmp/tfx-derived CODE_SIGNING_ALLOWED=NO build
```

リリースビルド:

```sh
xcodebuild -project tfx.xcodeproj -scheme tfx -configuration Release -destination 'platform=macOS' -derivedDataPath /tmp/tfx-release-derived CODE_SIGNING_ALLOWED=NO build
```

## プロジェクト構成

ソースディレクトリ:

- `tfx/App`: アプリのエントリーポイントとルート View
- `tfx/TerminalFileManager`: メイン画面、操作部、キーボード処理、レイアウト状態
- `tfx/FileBrowser`: ファイルブラウザのモデル、ディレクトリ読み込み、選択、ファイル操作、zip 閲覧、メタデータ、ドラッグアンドドロップ
- `tfx/FilePane`: ファイル一覧ペイン、行、ヘッダー、メニュー、表示設定、ステータス行
- `tfx/FolderTree`: フォルダツリーとピン留めフォルダ UI
- `tfx/Preview`: プレビューペイン、Markdown / PDF / 動画 / Quick Look プレビュー、プレビューメタデータ、プレビュー種別判定
- `tfx/Infrastructure`: 小さな AppKit / SwiftUI 共通補助
- `tfx/Assets.xcassets/AppIcon.appiconset`: アプリアイコン

補助ファイル:

- `tools/generate_app_icon.swift`: アプリアイコン再生成スクリプト
- `CHANGELOG.md`: 変更履歴

## ドキュメント

ドキュメント索引、保守ルール、ソース配置、詳細設計、実装履歴、ロードマップは `docs/README.md` を参照してください。

## 注意事項

- 削除操作は完全削除ではなく、macOS の Trash を使用します。
- プレビューは PDFKit、AVKit、WebKit、Quick Look を使います。
- 日付表示は `yyyy-MM-dd HH:mm:ss` 形式です。
