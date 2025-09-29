# emacs-cdp

Chrome DevTools Protocol (CDP) を使用して Emacs から Chrome/Chromium ブラウザを制御します。

## 機能

- **ブラウザ制御**: Emacs から直接 Chrome タブに接続して制御
- **キー転送**: Emacs から Chrome にキーボード入力を送信
- **タブ管理**: Chrome タブの選択、作成、切り替え
- **ページ制御**: ページのリロードやテキストのプログラム的な挿入
- **マイナーモード**: シームレスなブラウザ操作のための便利なキー送信モード

## 必要要件

- Emacs 30.1 以降
- `websocket` パッケージ（MELPA から入手可能）
- Chrome または Chromium ブラウザ

## インストール

### 手動インストール

1. リポジトリをクローン:
```bash
git clone https://github.com/ofnhwx/emacs-cdp.git
```

2. Emacs 設定に追加:
```elisp
(add-to-list 'load-path "/path/to/emacs-cdp")
(require 'emacs-cdp)
```

### パッケージインストール

`websocket` 依存関係をインストール:
```elisp
(package-install 'websocket)
```

## セットアップ

### リモートデバッグを有効にして Chrome を起動

Chrome はリモートデバッグを有効にして起動する必要があります:

```bash
# デフォルトポート 9222
google-chrome --remote-debugging-port=9222

# カスタムユーザープロファイルを使用
google-chrome --remote-debugging-port=9222 --user-data-dir=/tmp/chrome-debug
```

または Emacs から組み込みコマンドを使用:
```elisp
M-x emacs-cdp-start-chrome
```

## 使用方法

### 基本的な接続

1. **Chrome タブに接続**:
   ```elisp
   M-x emacs-cdp-select-tab
   ```
   開いている Chrome タブのリストからタブを選択します。

2. **新しいタブを作成して接続**:
   ```elisp
   M-x emacs-cdp-new-tab
   ```

### キー送信モード

マイナーモードを有効にして Chrome にキーを転送:

```elisp
M-x emacs-cdp-mode          ; CDP 制御モードを有効化
```

CDP モードが有効な場合:
- すべてのキーが接続された Chrome タブに送信されます（特殊キー組み合わせ除く）
- `C-g` で CDP モードを終了
- `C-c C-s` で別のタブを選択
- `C-c C-t` で新しいタブを作成
- `C-c C-r` でページをリロード
- `C-c C-i` でテキストを挿入
- `C-c C-n` で URL にナビゲート

### コマンド

| コマンド | キーバインド | 説明 |
|---------|-------------|------|
| `emacs-cdp-select-tab` | `C-c C-s` (CDP モード中) | Chrome タブを選択して接続 |
| `emacs-cdp-new-tab` | `C-c C-t` (CDP モード中) | 新しいタブを作成して接続 |
| `emacs-cdp-reload-page` | `C-c C-r` (CDP モード中) | 現在のページをリロード |
| `emacs-cdp-insert-text` | `C-c C-i` (CDP モード中) | ミニバッファプロンプトでテキストを挿入 |
| `emacs-cdp-navigate` | `C-c C-n` (CDP モード中) | URL にナビゲート |
| `emacs-cdp-start-chrome` | - | リモートデバッグで Chrome を起動 |
| `emacs-cdp-mode` | - | CDP 制御モードをトグル |

### 設定

パッケージの動作をカスタマイズ:

```elisp
;; Chrome 実行可能ファイルのパス（デフォルト: "google-chrome-stable"）
(setq emacs-cdp-chrome-executable "chromium")

;; リモートデバッグポート（デフォルト: 9222）
(setq emacs-cdp-debug-port 9222)

;; Chrome プロファイルディレクトリ（nil で一時ディレクトリ）
(setq emacs-cdp-profile-directory "~/.config/chrome-debug")

;; デバッグログを有効化
(setq emacs-cdp-debug t)
```

## ワークフローの例

```elisp
;; デバッグで Chrome を起動
(emacs-cdp-start-chrome)

;; タブに接続
(emacs-cdp-select-tab)

;; CDP モードを有効化
(emacs-cdp-mode 1)

;; すべてのキーが Chrome に送信されます（C-c 組み合わせ除く）
;; 制御用 C-c コマンドを使用:
;; C-c C-r でページリロード
;; C-c C-i でテキスト挿入
;; C-c C-n で URL ナビゲーション
;; C-g で CDP モードを終了

;; または個別のコマンドを使用
(emacs-cdp-reload-page)
(emacs-cdp-insert-text)  ; 挿入するテキストを入力
(emacs-cdp-navigate)     ; URL を入力
```

## キーマッピング

パッケージは Emacs のキーシーケンスを Chrome のキーコードに自動的にマッピングします:

- `RET` → `Enter`
- `TAB` → `Tab`
- `ESC` → `Escape`
- `C-` → Control 修飾子
- `M-` → Alt 修飾子
- `S-` → Shift 修飾子
- 矢印キー、Page Up/Down、Home/End がサポートされています

## トラブルシューティング

1. **Chrome に接続できない**:
   - Chrome が `--remote-debugging-port=9222` で実行されていることを確認
   - ポートがアクセス可能か確認: `curl http://localhost:9222/json`

2. **キーが送信されない**:
   - `(emacs-cdp-connected-p)` で接続を確認
   - デバッグモードを有効化: `(setq emacs-cdp-debug t)`

3. **接続が切れる**:
   - Chrome は非アクティブ後に WebSocket 接続を閉じることがあります
   - `emacs-cdp-select-tab` で再接続

## ライセンス

GPL-3.0。詳細はファイルヘッダーを参照してください。

## 作者

ofnhwx

## コントリビューション

Issues とプルリクエストは [GitHub](https://github.com/ofnhwx/emacs-cdp) で歓迎します。
