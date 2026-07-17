#!/bin/sh
# ZeroFin Mac アンインストーラ
#   curl -fsSL <BASE_URL>/uninstall.sh | sh
set -eu

APP="/Applications/ZeroFin.app"
PLIST="$HOME/Library/LaunchAgents/ai.zerogrid.zerofin.viewer.plist"

echo "▸ ZeroFin を削除します"

# 常駐停止
osascript -e 'quit app "ZeroFin"' 2>/dev/null || true
if [ -f "$PLIST" ]; then
  launchctl unload "$PLIST" 2>/dev/null || true
  rm -f "$PLIST"
  echo "  自動起動を解除"
fi

# アプリ削除
if [ -d "$APP" ]; then
  rm -rf "$APP"
  echo "  アプリを削除"
fi

# ビューア設定（Supabase読取キー）を削除
if [ -d "$HOME/.zerofin" ]; then
  rm -rf "$HOME/.zerofin"
  echo "  設定 (~/.zerofin) を削除"
fi

echo "✅ 完了。ZeroFin を完全に削除しました"
