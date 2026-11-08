#!/usr/bin/env bash
set -e

# 下载 newyorkthink/Keebuntu 最新正式 Release 中的 GTK2 XEmbed 托盘插件，并校验 SHA256SUMS。
# Keebuntu 使用固定 latest Release 标签，实际压缩包文件名仍包含 VERSION，因此不能直接用 tagName 推导文件名。
KEEBUNTU_REPOSITORY="newyorkthink/Keebuntu"
KEEBUNTU_TAG="$(gh release view --repo "$KEEBUNTU_REPOSITORY" --json tagName --jq '.tagName')"
test -n "$KEEBUNTU_TAG"

KEEBUNTU_ARCHIVE="$(
  gh release view "$KEEBUNTU_TAG" \
    --repo "$KEEBUNTU_REPOSITORY" \
    --json assets \
    --jq '.assets[].name | select(startswith("keebuntu-gtk-status-icon-") and endswith(".tar.gz"))' \
    | head -n 1
)"
test -n "$KEEBUNTU_ARCHIVE"

KEEBUNTU_VERSION="${KEEBUNTU_ARCHIVE#keebuntu-gtk-status-icon-}"
KEEBUNTU_VERSION="${KEEBUNTU_VERSION%.tar.gz}"
test -n "$KEEBUNTU_VERSION"

KEEBUNTU_WORK_DIR="/tmp/keebuntu-gtk-status-icon"
KEEBUNTU_PAYLOAD_DIR="$KEEBUNTU_WORK_DIR/keebuntu-gtk-status-icon-${KEEBUNTU_VERSION}"

rm -rf "$KEEBUNTU_WORK_DIR"
mkdir -p "$KEEBUNTU_WORK_DIR"

gh release download "$KEEBUNTU_TAG" \
  --repo "$KEEBUNTU_REPOSITORY" \
  --pattern "$KEEBUNTU_ARCHIVE" \
  --dir "$KEEBUNTU_WORK_DIR" \
  --clobber

gh release download "$KEEBUNTU_TAG" \
  --repo "$KEEBUNTU_REPOSITORY" \
  --pattern "SHA256SUMS" \
  --dir "$KEEBUNTU_WORK_DIR" \
  --clobber

KEEBUNTU_CHECKSUM_LINE="$(
  awk -v filename="$KEEBUNTU_ARCHIVE" '$2 == filename { print; exit }' \
    "$KEEBUNTU_WORK_DIR/SHA256SUMS"
)"
test -n "$KEEBUNTU_CHECKSUM_LINE"
(
  cd "$KEEBUNTU_WORK_DIR"
  printf '%s\n' "$KEEBUNTU_CHECKSUM_LINE" | sha256sum -c -
)

tar -C "$KEEBUNTU_WORK_DIR" -xzf "$KEEBUNTU_WORK_DIR/$KEEBUNTU_ARCHIVE"
test -x "$KEEBUNTU_PAYLOAD_DIR/install.sh"
"$KEEBUNTU_PAYLOAD_DIR/install.sh" --app-dir /usr/share/keepass

# 确认 GTK2 XEmbed 托盘插件已经安装；它只创建 KeePass 图标，不会重新渲染其他程序的托盘图标。
test -f /usr/share/keepass/Plugins/keebuntu/GtkStatusIcon.dll
