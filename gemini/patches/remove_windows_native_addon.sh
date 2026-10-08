#!/usr/bin/env bash
# Linux 补丁：去掉 Speak to Window 的 Windows PE 原生模块。
# stdout 只输出 true 或 false，表示是否实际删除了 gemini_native.node。
set -Eeuo pipefail

if (( $# != 2 )) || [[ -z "$1" || -z "$2" ]]; then
  printf '用法：%s <AppDir/bin> <已提取的 app.asar 目录>\n' "$0" >&2
  exit 2
fi

APP_ROOT="$1"
LINUX_ASAR_DIR="$2"
removed=false

log() {
  printf '[Gemini] %s\n' "$*" >&2
}

die() {
  printf '错误：%s\n' "$*" >&2
  exit 1
}

# ASAR 索引把 unpacked 文件记录为外置内容，必须在完整提取后才能删除对应文件。
# Gemini 的 Windows 原生 Node 模块只用于 Speak to Window；产品层在模块缺失时有明确的安全回退。
while IFS= read -r -d '' node_file; do
  if file -b "$node_file" | grep -q '^PE32'; then
    [[ "${node_file##*/}" == gemini_native.node ]] || \
      die "发现未识别的 Windows 原生 Node 模块：${node_file#"$APP_ROOT/resources/"}"
    [[ "$node_file" == "$APP_ROOT/resources/app.asar.unpacked/"* ]] || \
      die "已确认的 Windows 原生 Node 模块位于未识别路径：${node_file#"$APP_ROOT/resources/"}"

    unpacked_relative="${node_file#"$APP_ROOT/resources/app.asar.unpacked/"}"
    extracted_node="$LINUX_ASAR_DIR/$unpacked_relative"
    [[ -f "$extracted_node" ]] || \
      die "ASAR 提取目录缺少对应的 Windows 原生 Node 模块：$unpacked_relative"

    log "移除 Windows 原生 Node 模块：${node_file#"$APP_ROOT/resources/"}"
    rm -f -- "$node_file" "$extracted_node"
    removed=true
  fi
done < <(find "$APP_ROOT/resources" -type f -name '*.node' -print0)

printf '%s\n' "$removed"
