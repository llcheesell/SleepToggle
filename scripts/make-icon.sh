#!/bin/bash
#
# アイコンを再生成して Resources/AppIcon.icns を更新する。
# 生成に数秒かかるためビルドの度には走らせない。
#
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

swift scripts/make-icon.swift "$work"
iconutil -c icns "$work/AppIcon.iconset" -o Resources/AppIcon.icns
cp "$work/AppIcon-1024.png" Resources/AppIcon-1024.png

echo "更新: Resources/AppIcon.icns ($(du -h Resources/AppIcon.icns | cut -f1))"
