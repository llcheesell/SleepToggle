#!/bin/bash
#
# ビルド済みの SleepToggle.app を /Applications へ設置する。
#
# SMAppService はデーモン登録時に App バンドルのパスを記録するため、
# build/ から直接登録すると再ビルド（rm -rf）で登録が壊れる。必ず設置してから登録する。
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/build/SleepToggle.app"
DEST="/Applications/SleepToggle.app"

if [ ! -d "$SRC" ]; then
  echo "error: $SRC がありません。先に ./scripts/build.sh を実行してください。" >&2
  exit 1
fi

# 旧版が動いていると差し替えに失敗するので先に落とす。
if pgrep -x SleepToggle >/dev/null 2>&1; then
  echo "起動中の SleepToggle を終了します"
  osascript -e 'quit app "SleepToggle"' 2>/dev/null || pkill -x SleepToggle || true
  sleep 1
fi

# ditto は拡張属性と署名を保ったままコピーする（cp -R では壊れることがある）。
rm -rf "$DEST"
ditto "$SRC" "$DEST"

echo "設置: $DEST"
codesign --verify --deep --strict "$DEST" && echo "署名検証: OK"

# 設置版を登録し直す（作業用コピーは build.sh で外してある）。
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$DEST"
