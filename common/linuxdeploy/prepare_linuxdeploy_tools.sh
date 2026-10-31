#!/usr/bin/env bash

# 被 source 时先独立完成工具下载，再把通用构建环境设置加载到当前脚本。
if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
  # source 调用必须明确提供工具目录、插件、中间产物位置和 runtime。
  if [[ $# -ne 4 || -z "${1:-}" || -z "${3:-}" || -z "${4:-}" ]]; then
    echo "用法：source ${BASH_SOURCE[0]} <工具目录> <gtk|qt|空字符串> <中间 AppImage> <runtime>" >&2
    return 1
  fi

  # 只接受现有下载入口支持的插件类型，避免参数错误时仍下载工具。
  case "$2" in
    ''|gtk|qt) ;;
    *)
      echo "错误：当前不支持的 linuxdeploy 输入插件：$2" >&2
      return 1
      ;;
  esac

  # 在下载前确认环境配置入口可读，已有配置实现继续原样复用。
  if [[ ! -r "$(dirname -- "${BASH_SOURCE[0]}")/configure_environment.sh" ]]; then
    echo "错误：linuxdeploy 通用环境配置入口不存在或不可读。" >&2
    return 1
  fi

  # 在独立 Bash 进程中执行原有下载流程，保留调用方变量、函数和 Shell 选项。
  if bash "${BASH_SOURCE[0]}" "$1" "$2"; then
    # 下载成功后加载环境设置；工具目录使用绝对路径，后续命令可直接调用 linuxdeploy。
    source "$(dirname -- "${BASH_SOURCE[0]}")/configure_environment.sh" "$(cd -- "$1" && pwd)" "$3" "$4"
    return
  else
    # 下载失败时将原退出状态返回调用方，并跳过后续环境设置。
    return "$?"
  fi
fi

# 命令失败、用了没定义的变量，或管道里任一命令失败，就退出。
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DOWNLOAD_FILE="$SCRIPT_DIR/../download/download_file.sh"
GITHUB_API="$SCRIPT_DIR/../github/github_api.sh"
TOOLS_DIR="${1:-}"
PLUGIN="${2:-}"

[[ -n "$TOOLS_DIR" ]] || {
  echo "用法：$0 <工具目录> [gtk|qt]" >&2
  exit 1
}
[[ -x "$DOWNLOAD_FILE" ]] || {
  echo "错误：公共下载脚本不存在或不可执行：$DOWNLOAD_FILE" >&2
  exit 1
}
[[ -r "$GITHUB_API" ]] || {
  echo "错误：GitHub API 公共脚本不存在：$GITHUB_API" >&2
  exit 1
}
[[ "$(uname -m)" == x86_64 ]] || {
  echo "错误：当前公共 linuxdeploy 工具准备脚本只支持 x86_64。" >&2
  exit 1
}
command -v curl >/dev/null 2>&1 || {
  echo "错误：缺少 curl。" >&2
  exit 1
}
command -v jq >/dev/null 2>&1 || {
  echo "错误：缺少 jq。" >&2
  exit 1
}

mkdir -p "$TOOLS_DIR"
TOOLS_DIR="$(cd -- "$TOOLS_DIR" && pwd)"

# shellcheck source=common/github/github_api.sh
source "$GITHUB_API"

# 从官方 continuous Release 解析指定资产及摘要，再交给公共下载脚本取得文件。
# 若上游正在替换 continuous 资产，重新获取 Release 元数据后整体重试，避免旧摘要与新资产短暂错配。
download_release_asset() {
  local repo="$1" asset="$2" output="$3"
  local metadata="" url="" digest="" attempt
  local max_attempts=3

  for ((attempt = 1; attempt <= max_attempts; attempt++)); do
    if metadata="$(github_api_get "https://api.github.com/repos/$repo/releases/tags/continuous")" &&
       url="$(jq -er --arg name "$asset" '.assets[] | select(.name == $name) | .browser_download_url' <<< "$metadata")" &&
       digest="$(jq -er --arg name "$asset" '.assets[] | select(.name == $name) | .digest' <<< "$metadata")" &&
       [[ "$digest" =~ ^sha256:[[:xdigit:]]{64}$ ]] &&
       "$DOWNLOAD_FILE" "$url" "$output" "$digest"; then
      return 0
    fi

    if (( attempt < max_attempts )); then
      echo "警告：取得或校验官方资产失败，将重新获取 continuous Release 元数据后重试：$repo/$asset（$attempt/$max_attempts）。" >&2
      sleep 2
    fi
  done

  echo "错误：连续 $max_attempts 次无法取得并校验官方 continuous Release 资产：$repo/$asset" >&2
  return 1
}

# 动态取得 linuxdeploy、最终封装工具和官方 Type 2 runtime。
download_release_asset linuxdeploy/linuxdeploy linuxdeploy-x86_64.AppImage \
  "$TOOLS_DIR/linuxdeploy-x86_64.AppImage"
download_release_asset AppImage/appimagetool appimagetool-x86_64.AppImage \
  "$TOOLS_DIR/appimagetool-x86_64.AppImage"
download_release_asset AppImage/type2-runtime runtime-x86_64 \
  "$TOOLS_DIR/runtime-x86_64"

# GTK / Qt 项目按需取得对应的官方 linuxdeploy 输入插件。
case "$PLUGIN" in
  '')
    ;;
  gtk)
    # GTK 插件没有 Release 资产；从官方仓库默认分支动态解析当前文件并核对 Git blob SHA。
    command -v sha1sum >/dev/null 2>&1 || {
      echo "错误：缺少 sha1sum。" >&2
      exit 1
    }
    gtk_metadata="$(github_api_get \
      "https://api.github.com/repos/linuxdeploy/linuxdeploy-plugin-gtk/contents/linuxdeploy-plugin-gtk.sh")"
    gtk_url="$(jq -er '.download_url' <<< "$gtk_metadata")"
    gtk_blob_sha="$(jq -er '.sha' <<< "$gtk_metadata")"
    [[ "$gtk_blob_sha" =~ ^[[:xdigit:]]{40}$ ]] || {
      echo "错误：官方 GTK 插件没有有效的 Git blob SHA。" >&2
      exit 1
    }
    "$DOWNLOAD_FILE" "$gtk_url" "$TOOLS_DIR/linuxdeploy-plugin-gtk"
    gtk_actual_blob_sha="$({
      printf 'blob %s\0' "$(stat -c '%s' "$TOOLS_DIR/linuxdeploy-plugin-gtk")"
      cat "$TOOLS_DIR/linuxdeploy-plugin-gtk"
    } | sha1sum | awk '{print $1}')"
    [[ "$gtk_actual_blob_sha" == "$gtk_blob_sha" ]] || {
      echo "错误：GTK 插件 Git blob SHA 校验失败。" >&2
      exit 1
    }

    # 官方 GTK 插件当前没有复制 GIO 动态模块；GTK AppImage 需要使用 AppDir 内对应模块时必须随包部署。
    # 只在上游仍缺少该逻辑时，把已经验证的最小 GIO 修复加入当前下载文件。
    if ! grep -Fq 'gio_moduledir=' "$TOOLS_DIR/linuxdeploy-plugin-gtk"; then
      gtk_patch_tmp="$(mktemp "$TOOLS_DIR/linuxdeploy-plugin-gtk.patch.XXXXXX")"
      if ! awk '
        {
          print
          if (index($0, "export GI_TYPELIB_PATH=") == 1) {
            after_typelib_export = 1
            next
          }
          if (after_typelib_export && $0 == "EOF") {
            print "echo \"Installing GIO modules\""
            print "gio_moduledir=\"$(get_pkgconf_variable \"giomoduledir\" \"gio-2.0\" \"/usr/lib/x86_64-linux-gnu/gio/modules\")\""
            print "copy_tree \"$gio_moduledir\" \"$APPDIR/\""
            after_typelib_export = 0
            patched = 1
          }
        }
        END {
          if (patched != 1) exit 42
        }
      ' "$TOOLS_DIR/linuxdeploy-plugin-gtk" > "$gtk_patch_tmp"; then
        rm -f "$gtk_patch_tmp"
        echo "错误：无法把 GIO modules 修复应用到官方 GTK 插件。" >&2
        exit 1
      fi
      chmod --reference="$TOOLS_DIR/linuxdeploy-plugin-gtk" "$gtk_patch_tmp"
      mv -f "$gtk_patch_tmp" "$TOOLS_DIR/linuxdeploy-plugin-gtk"
    fi

    [[ "$(grep -Fc 'gio_moduledir=' "$TOOLS_DIR/linuxdeploy-plugin-gtk")" -eq 1 ]] || {
      echo "错误：GTK 插件中的 GIO modules 修复数量异常。" >&2
      exit 1
    }
    bash -n "$TOOLS_DIR/linuxdeploy-plugin-gtk"
    chmod +x "$TOOLS_DIR/linuxdeploy-plugin-gtk"
    sha256sum "$TOOLS_DIR/linuxdeploy-plugin-gtk"
    ;;
  qt)
    download_release_asset linuxdeploy/linuxdeploy-plugin-qt linuxdeploy-plugin-qt-x86_64.AppImage \
      "$TOOLS_DIR/linuxdeploy-plugin-qt-x86_64.AppImage"
    chmod +x "$TOOLS_DIR/linuxdeploy-plugin-qt-x86_64.AppImage"
    ;;
  *)
    echo "错误：当前不支持的 linuxdeploy 输入插件：$PLUGIN" >&2
    exit 1
    ;;
esac

# 只给需要直接执行的 AppImage 工具增加执行权限，并提供标准 linuxdeploy 命令名。
chmod +x \
  "$TOOLS_DIR/linuxdeploy-x86_64.AppImage" \
  "$TOOLS_DIR/appimagetool-x86_64.AppImage"
ln -sfn linuxdeploy-x86_64.AppImage "$TOOLS_DIR/linuxdeploy"
