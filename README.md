# ZeroFin

会社の金を、どこにもログインせず一目で。ZeroGrid 財務可視化の表示クライアント。

- **Mac**: メニューバー常駐アプリ。⌘F でノッチからダッシュボードが展開（実質残高・売上・広告費・入金・残高推移）。音声/テキストで「今日の売上」等を呼び出し、自由質問は Claude に回答させる。
- **iPhone**: Scriptable ホーム画面ウィジェット。

収集基盤（MF会計API + りそなデビット + Shopify 3店 → Supabase、3時間おき）は Mac mini 専任。本リポジトリは**表示クライアントと配布物**。

## インストール

セットアップページ: https://zerogridcompany-cell.github.io/zerofin/

### Mac
```sh
curl -fsSL https://github.com/zerogridcompany-cell/zerofin/releases/latest/download/install.sh | sh
```
初回に Supabase の URL / 読取キーを入力。⌘F で開く。

### iPhone
App Store で **Scriptable** を入れ、[dist/zerofin-widget.js](dist/zerofin-widget.js) を新規スクリプトに貼付 → ホーム画面にウィジェット追加。

## ビルド（開発）
```sh
xcodegen generate
xcodebuild -project ZeroFin.xcodeproj -scheme ZeroFin -configuration Debug build
```
macOS 26+ / Xcode 26+（Liquid Glass 使用）。

## 構成
- `Sources/` — SwiftUI + AppKit。ノッチパネル、Supabase読取、音声認識、Claude CLI連携。
- `dist/` — 配布物（install.sh, zerofin-widget.js, onboarding）。

秘密情報はリポジトリに含めない。設定は各端末の `~/.zerofin/env`（Mac）/ Keychain（iPhone）。
