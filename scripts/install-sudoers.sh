#!/bin/bash
#
# sudoers ドロップインを検証してインストールする。
#
#   sudo ./scripts/install-sudoers.sh
#
# 壊れた sudoers を /etc/sudoers.d に置くと sudo 自体が使えなくなるため、
# 必ず visudo で構文検証してから install する。
#
set -euo pipefail

DEST=/etc/sudoers.d/sleeptoggle
SRC="$(cd "$(dirname "$0")/.." && pwd)/sudoers.d/sleeptoggle"

if [ "$(id -u)" -ne 0 ]; then
  echo "sudo で実行してください:  sudo $0" >&2
  exit 1
fi

TARGET_USER=${SUDO_USER:-}
if [ -z "$TARGET_USER" ]; then
  echo "SUDO_USER が取得できませんでした。sudo 経由で実行してください。" >&2
  exit 1
fi

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
sed "s/@USER@/$TARGET_USER/g" "$SRC" >"$tmp"

if ! visudo -cqf "$tmp"; then
  echo "error: sudoers の構文検証に失敗しました。インストールを中止します。" >&2
  exit 1
fi

install -m 0440 -o root -g wheel "$tmp" "$DEST"

echo "installed: $DEST"
echo "  → $TARGET_USER に対して pmset -a disablesleep 0|1 のみを NOPASSWD 許可"
echo
echo "確認:"
echo "  sudo -n /usr/bin/pmset -g >/dev/null && echo '(これは許可されないのが正常)'"
echo "  ./scripts/sleeptoggle status"
echo
echo "取り消す場合:"
echo "  sudo rm $DEST"
