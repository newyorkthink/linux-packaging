#!/usr/bin/env bash
set -Eeuo pipefail

# 接收完整程序目录、系统 desktop 和便携 desktop 输出路径。
if (( $# != 3 )); then
  echo "用法：$0 <完整程序目录> <系统 desktop> <便携 desktop 输出文件>" >&2
  exit 2
fi
APP_ROOT="$1"
DESKTOP_SOURCE="$2"
DESKTOP="$3"

# 核对完整官方布局，并补回 AUR 明确创建的空配置目录。
[[ -d "$APP_ROOT/res" && -f "$DESKTOP_SOURCE" ]] || {
  echo "错误：官方资源目录或桌面入口缺失。" >&2
  exit 1
}
mkdir -p "$APP_ROOT/config"

# 保留四入口检查，不把缺失组件的包继续交给封装工具。
for binary in ToDesk ToDesk_Service ToDesk_Session CrashReport; do
  [[ -x "$APP_ROOT/bin/$binary" ]] || {
    echo "错误：缺少 ToDesk 运行组件：$APP_ROOT/bin/$binary" >&2
    exit 1
  }
done

# 核对现有中文输入模块和显式收集的托盘运行库。
for library in \
  /usr/lib/gtk-3.0/3.0.0/immodules/im-ibus.so \
  /usr/lib/gtk-3.0/3.0.0/immodules/im-fcitx5.so \
  /usr/lib/libappindicator3.so.1 \
  /usr/lib/libdbusmenu-glib.so.4 \
  /usr/lib/libdbusmenu-gtk3.so.4; do
  [[ -f "$library" ]] || {
    echo "错误：缺少 ToDesk 运行库：$library" >&2
    exit 1
  }
done

# 一次汇总四个入口的直接缺库；ldd 自身失败时也保留诊断并停止构建。
MISSING_SHARED_LIBS="$(
  for binary in ToDesk ToDesk_Service ToDesk_Session CrashReport; do
    if dependencies="$(LD_LIBRARY_PATH="$APP_ROOT/bin${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" ldd "$APP_ROOT/bin/$binary" 2>&1)"; then
      awk -v binary="$binary" '/not found/ {print binary ": " $0}' <<< "$dependencies"
    else
      printf '%s: 动态库检查失败。\n' "$binary"
      awk -v binary="$binary" '{print binary ": " $0}' <<< "$dependencies"
    fi
  done | sort -u
)"
if [[ -n "$MISSING_SHARED_LIBS" ]]; then
  printf 'ToDesk 直接动态库检查未通过：\n%s\n' "$MISSING_SHARED_LIBS" >&2
  exit 1
fi

# 使用官方 desktop 作为元数据，只把启动命令改成 AppImage 内实际主入口。
cp -a "$DESKTOP_SOURCE" "$DESKTOP"
# 完整替换启动行，避免残留上游 env 命令后的环境赋值和程序路径。
sed -i -E 's|^Exec=.*|Exec=ToDesk|' "$DESKTOP"
# 保留既有 TryExec 的便携入口调整。
sed -i -E 's|^TryExec=.*|TryExec=ToDesk|' "$DESKTOP"
