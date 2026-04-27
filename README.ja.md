# tfx

**Terminal File eXplorer**  
読み方: **タフィックス**  
Version: **0.2.1**

[English](README.md) | 日本語

`tfx` は、ターミナル風の見た目とキーボード操作を中心にした macOS 向けファイルマネージャーです。フォルダツリー、スプリット表示、プレビュー、ドラッグアンドドロップ、Terminal.app 連携を備えています。

## 機能

- ターミナル風のファイル一覧 UI
- `/` から始まる単一フォルダツリー
- ピン留めフォルダの常時表示
- ピン留めフォルダのドラッグ並べ替え
- 単独ビュー / スプリットビュー切り替え
- 左右ペイン間のドラッグアンドドロップ
- アクティブビューのハイライト表示
- `..` 行による親フォルダ移動
- PDF / 動画 / Markdown / Quick Look プレビュー
- プレビュー表示のオン / オフ切り替え
- Terminal.app を現在フォルダで開く
- New Folder / Rename / Move to Trash / Reveal in Finder
- Copy / Cut / Paste と同名ファイル競合ダイアログ
- 検索、隠しファイル表示、ソート
- Command-click による複数選択
- Shift + 上下キー、Shift-click による範囲選択
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
- `Command + F`: 検索
- `Command + N`: 新規フォルダ
- `Delete`: ゴミ箱へ移動
- `Command + C / X / V`: コピー / カット / ペースト
- `Command + A`: すべて選択
- `Command + R`: 再読み込み
- `Command + Shift + T`: 現在フォルダで Terminal.app を開く
- `Command + Shift + .`: 隠しファイル表示切り替え

## ビルド

```sh
xcodebuild -project tfx.xcodeproj -scheme tfx -destination 'platform=macOS' -derivedDataPath /tmp/tfx-derived CODE_SIGNING_ALLOWED=NO build
```

リリースビルド:

```sh
xcodebuild -project tfx.xcodeproj -scheme tfx -configuration Release -destination 'platform=macOS' -derivedDataPath /tmp/tfx-release-derived CODE_SIGNING_ALLOWED=NO build
```

## プロジェクト構成

- `tfx/App`: アプリのエントリーポイントとルート View
- `tfx/TerminalFileManager`: メイン画面、操作部、キーボード処理、レイアウト状態
- `tfx/FileBrowser`: ファイルブラウザのモデル、ディレクトリ読み込み、選択、ファイル操作、メタデータ、ドラッグアンドドロップ
- `tfx/FilePane`: ファイル一覧ペイン、行、ヘッダー、メニュー、表示設定、ステータス行
- `tfx/FolderTree`: フォルダツリーとピン留めフォルダ UI
- `tfx/Preview`: プレビューペイン、Markdown / PDF / 動画 / Quick Look プレビュー、プレビュー種別判定
- `tfx/Infrastructure`: 小さな AppKit / SwiftUI 共通補助
- `tfx/Assets.xcassets/AppIcon.appiconset`: アプリアイコン
- `tools/generate_app_icon.swift`: アプリアイコン再生成スクリプト
- `docs/code-organization.md`: ソース配置と命名規則
- `docs/file-manager-implementation-plan.md`: 実装計画と進捗
- `docs/development-roadmap.md`: 今後の開発計画
- `docs/detailed-design.md`: 詳細設計書
- `CHANGELOG.md`: 変更履歴

## 注意事項

- 削除操作は完全削除ではなく、macOS の Trash を使用します。
- プレビューは PDFKit、AVKit、WebKit、Quick Look を使います。
- 日付表示は `yyyy-MM-dd HH:mm:ss` 形式です。
- `CODE_SIGNING_ALLOWED=NO` で作成した Release ビルドは、Developer ID 署名や notarization は未実施です。
