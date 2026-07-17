#!/bin/sh
# ZeroFin Mac ビューア インストーラ
#   curl -fsSL <BASE_URL>/install.sh | sh
# 収集は Mac mini 専任。他Macは Supabase を読むビューアだけ入れる。
set -eu

BASE_URL="https://github.com/zerogridcompany-cell/zerofin/releases/latest/download"                 # 配布元（後で埋める）
APP="ZeroFin.app"
DEST="/Applications/$APP"
ZIP_URL="$BASE_URL/ZeroFin.app.zip"
ENV_DIR="$HOME/.zerofin"
ENV_FILE="$ENV_DIR/env"

echo "▸ ZeroFin をインストールします"

# 1. アプリ取得
TMP="$(mktemp -d)"
echo "  ダウンロード中…"
curl -fsSL "$ZIP_URL" -o "$TMP/ZeroFin.zip"
echo "  展開中…"
ditto -x -k "$TMP/ZeroFin.zip" "$TMP"
rm -rf "$DEST"
mv "$TMP/$APP" "$DEST"
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true
rm -rf "$TMP"

# 2. Supabase 読取設定
mkdir -p "$ENV_DIR"; chmod 700 "$ENV_DIR"
if [ ! -f "$ENV_FILE" ] || ! grep -q SUPABASE_URL "$ENV_FILE" 2>/dev/null; then
  # 事前に環境変数で渡されていれば聞かずに使う（管理者が配る1コマンド用）
  SB_URL="${ZEROFIN_SB_URL:-}"
  SB_KEY="${ZEROFIN_SB_KEY:-}"
  if [ -z "$SB_URL" ] || [ -z "$SB_KEY" ]; then
    printf "  Supabase URL (https://xxxx.supabase.co): "; read -r SB_URL </dev/tty
    printf "  Supabase 読取キー: "; read -r SB_KEY </dev/tty
  fi
  {
    echo "SUPABASE_URL=$SB_URL"
    echo "SUPABASE_SERVICE_KEY=$SB_KEY"
  } >> "$ENV_FILE"
  chmod 600 "$ENV_FILE"
  echo "  設定を $ENV_FILE に保存"
fi

# 3. ログイン時に自動起動（LaunchAgent）
PLIST="$HOME/Library/LaunchAgents/ai.zerogrid.zerofin.viewer.plist"
mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>ai.zerogrid.zerofin.viewer</string>
  <key>ProgramArguments</key><array><string>/usr/bin/open</string><string>-a</string><string>$DEST</string></array>
  <key>RunAtLoad</key><true/>
</dict></plist>
PL
launchctl unload "$PLIST" 2>/dev/null || true
launchctl load "$PLIST" 2>/dev/null || true

# 4. 起動
open "$DEST"
echo "✅ 完了。⌘F でダッシュボードが開きます（メニューバーの ¥ からも）"
