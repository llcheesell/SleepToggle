#!/bin/bash
#
# SleepToggle.app を公証（notarization）して配布可能な状態にする。
#
# Control Center は未公証の Developer ID 署名 App の拡張を読み込まない。
# spctl が "Unnotarized Developer ID" で reject する状態だとコントロールが
# ギャラリーに出てこない。
#
# 初回だけ資格情報を Keychain に保存する（対話で訊かれる）:
#
#   xcrun notarytool store-credentials SleepToggle \
#     --apple-id <Apple ID> --team-id KCA45GR99A
#
#   パスワードは Apple ID のパスワードではなく「App用パスワード」。
#   https://account.apple.com/account/manage で発行する。
#
# 以降はこれだけ:
#   ./scripts/notarize.sh
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PROFILE="${SLEEPTOGGLE_NOTARY_PROFILE:-SleepToggle}"
APP="$ROOT/build/SleepToggle.app"

step() { printf '\n\033[1m==> %s\033[0m\n' "$1"; }

# 公証はセキュアタイムスタンプ付き署名と hardened runtime を要求する。
# --timestamp は project.yml の OTHER_CODE_SIGN_FLAGS で常に付く。
step "配布用にビルド（--timestamp 付き）"
CLEAN=1 ./scripts/build.sh >/dev/null
echo "ビルド完了"

work="$(mktemp -d)"
LSREG=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
# 一時フォルダの App も LaunchServices に登録されて残るので、消す前に外す。
trap '"$LSREG" -u "$work/SleepToggle.app" 2>/dev/null; rm -rf "$work"' EXIT
staged="$work/SleepToggle.app"
zip="$work/SleepToggle.zip"

# 公証チケットは提出したバイナリの cdhash に紐づく。build/ を直接提出すると、
# 提出中に誰かが再ビルドしただけで staple が "Record not found" で落ちる。
# スナップショットを取り、それを提出・staple する。
step "スナップショットを取得"
ditto "$APP" "$staged"
echo "cdhash: $(codesign -d --verbose=4 "$staged" 2>&1 | awk -F= '/^CandidateCDHash/{print $2; exit}')"

step "アーカイブ作成"
# ditto でないと署名と拡張属性が壊れる。zip コマンドは使わない。
ditto -c -k --keepParent "$staged" "$zip"
du -h "$zip" | cut -f1

step "提出（完了まで待機）"
# Invalid でも staple に進むと "Record not found" という無関係な
# エラーが出て原因を見失う。ここで必ず止める。
submit_log="$work/submit.txt"
xcrun notarytool submit "$zip" --keychain-profile "$PROFILE" --wait | tee "$submit_log"
if ! grep -q "status: Accepted" "$submit_log"; then
  id=$(awk '/^  id:/ { print $2; exit }' "$submit_log")
  echo "" >&2
  echo "error: 公証が通りませんでした。理由:" >&2
  [ -n "$id" ] && xcrun notarytool log "$id" --keychain-profile "$PROFILE" >&2
  exit 1
fi

step "チケットを添付"
# staple しておくとオフラインでも検証が通る。
xcrun stapler staple "$staged"

step "検証"
spctl -a -vvv -t exec "$staged" 2>&1
xcrun stapler validate "$staged" 2>&1 | tail -1

step "staple 済みのものを build/ に戻す"
rm -rf "$APP"
ditto "$staged" "$APP"

printf '\n\033[1m公証完了。./scripts/install.sh で設置してください。\033[0m\n'
