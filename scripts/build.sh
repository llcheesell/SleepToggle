#!/bin/bash
#
# SleepToggle.app をビルドする。
#
#   ./scripts/build.sh
#
# 注意: swiftc を直接呼ぶ方式から xcodebuild に移行した。
# WidgetKit の拡張は AppIntents のメタデータ抽出
# (Contents/Resources/Metadata.appintents/extract.actionsdata) を必要とし、
# これは Xcode のビルドフェーズでしか生成されない。
# これが無いと chronod の getAllDescriptors が失敗し続け、
# Control Center にもウィジェットギャラリーにも一切出てこない。
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

CONFIG="${CONFIGURATION:-Release}"
DD="$ROOT/build/dd"

step() { printf '\n\033[1m==> %s\033[0m\n' "$1"; }

step "Xcode プロジェクトを生成"
xcodegen generate

# 設定変更が増分ビルドで拾われず、埋め込み済みの実行ファイルだけ古いまま残る
# ことがある（get-task-allow が消えない等）。配布ビルドでは必ずクリーンする。
if [ "${CLEAN:-0}" = "1" ]; then
  step "クリーン"
  rm -rf "$DD"
fi

step "ビルド"
xcodebuild -project SleepToggle.xcodeproj -scheme SleepToggle \
  -configuration "$CONFIG" -derivedDataPath "$DD" build \
  | grep -E 'error:|warning: .*(sign|entitle)|\*\* ' || true

APP="$DD/Build/Products/$CONFIG/SleepToggle.app"
[ -d "$APP" ] || { echo "error: $APP が生成されていません" >&2; exit 1; }

# 以降のスクリプトが参照する固定パスに置く。
rm -rf "$ROOT/build/SleepToggle.app"
ditto "$APP" "$ROOT/build/SleepToggle.app"

step "検証"
# ビルドが成功しても中身が欠けることがあるので、配布できない状態ならここで止める:
#   - xcodegen の resources: キーは存在せず黙って無視される（リソースが入らない）
#   - AppIntents メタデータが無いと拡張が列挙されない
#   - tool の署名 identifier が製品名になると XPC が通らない
#   - get-task-allow が入っていると公証が通らない
OUT="$ROOT/build/SleepToggle.app"
CONTROL="$OUT/Contents/PlugIns/SleepToggleControl.appex"
fail=0
need() { if [ -e "$1" ]; then echo "  ok  ${1#"$OUT"/}"; else echo "  NG  ${1#"$OUT"/} がありません" >&2; fail=1; fi; }
need "$OUT/Contents/Resources/LidWarning.wav"
need "$OUT/Contents/Resources/AppIcon.icns"
need "$OUT/Contents/Resources/Assets.car"
need "$CONTROL/Contents/Resources/Assets.car"
need "$CONTROL/Contents/Resources/Metadata.appintents/extract.actionsdata"
need "$OUT/Contents/Library/LaunchDaemons/com.llcheesell.SleepToggle.helper.plist"
need "$OUT/Contents/Library/LaunchAgents/com.llcheesell.SleepToggle.watcher.plist"

check_id() {
  local actual
  actual=$(codesign -d --verbose=2 "$1" 2>&1 | awk -F= '/^Identifier=/{print $2}')
  if [ "$actual" = "$2" ]; then echo "  ok  identifier $2"
  else echo "  NG  $(basename "$1") の identifier が $actual（期待: $2）" >&2; fail=1; fi
}
check_id "$OUT" com.llcheesell.SleepToggle
check_id "$CONTROL" com.llcheesell.SleepToggle.Control
check_id "$OUT/Contents/MacOS/SleepToggleHelper" com.llcheesell.SleepToggle.helper
check_id "$OUT/Contents/MacOS/SleepToggleWatcher" com.llcheesell.SleepToggle.watcher

for bin in "$OUT" "$CONTROL" "$OUT/Contents/MacOS/SleepToggleHelper" "$OUT/Contents/MacOS/SleepToggleWatcher"; do
  if codesign -d --entitlements - --xml "$bin" 2>/dev/null | grep -q get-task-allow; then
    echo "  NG  $(basename "$bin") に get-task-allow が入っています（公証で弾かれる）" >&2; fail=1
  fi
done

codesign --verify --deep --strict "$OUT" || fail=1
[ "$fail" = 0 ] || { echo "error: バンドルの検証に失敗しました" >&2; exit 1; }
echo "  ok  署名"

# ビルド成果物は macOS が自動で LaunchServices に登録してしまう。同じ bundle ID の拡張が
# 複数登録されると Control Center が作業用コピーの方を見に行き、アイコンが「?」になった。
# 設置版以外は登録から外しておく。
LSREG=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
"$LSREG" -u "$APP" 2>/dev/null || true
"$LSREG" -u "$OUT" 2>/dev/null || true

printf '\n\033[1m完成: %s\033[0m\n' "$ROOT/build/SleepToggle.app"
