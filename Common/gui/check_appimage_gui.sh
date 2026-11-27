#!/usr/bin/env bash
set -Eeuo pipefail

# 只在应用构建脚本明确调用时，检查最终 AppImage 能否短时启动。
# 不检查登录、代理、输入法或真实桌面功能。
APPIMAGE="${1:-}"
SECONDS_LIMIT="${2:-}"
WORK_DIR="${3:-}"
SESSION_ORDER="${4:-}"
SUCCESS_MODE="${5:-}"
FATAL_PATTERN="${6:-}"
WINDOW_TITLE="${7:-}"

if (( $# < 7 )); then
  echo "用法：$0 <AppImage> <1-20 秒> <工作目录> <timeout-dbus-xvfb|xvfb-dbus-timeout|timeout-xvfb> <timeout-only|timeout-or-zero> <致命日志正则> <窗口标题正则或空字符串> [-- 应用参数...]" >&2
  exit 2
fi
shift 7
if [[ "${1:-}" == -- ]]; then
  shift
fi
APP_ARGS=("$@")

[[ -f "$APPIMAGE" && -x "$APPIMAGE" && -n "$WORK_DIR" ]] || {
  echo "错误：最终 AppImage 不可执行，或未指定检查工作目录。" >&2
  exit 2
}
[[ "$SECONDS_LIMIT" =~ ^([1-9]|1[0-9]|20)$ ]] || {
  echo "错误：图形启动检查上限必须为 1 至 20 秒。" >&2
  exit 2
}
[[ -n "$FATAL_PATTERN" ]] || {
  echo "错误：必须由调用方传入致命日志特征。" >&2
  exit 2
}
case "$SESSION_ORDER" in
  timeout-dbus-xvfb|xvfb-dbus-timeout|timeout-xvfb) ;;
  *) echo "错误：不支持的会话顺序：$SESSION_ORDER" >&2; exit 2 ;;
esac
case "$SUCCESS_MODE" in
  timeout-only|timeout-or-zero) ;;
  *) echo "错误：不支持的成功退出码规则：$SUCCESS_MODE" >&2; exit 2 ;;
esac

# 窗口标题检查需要在同一个虚拟显示中查询窗口；其他应用不安装 xdotool。
if [[ -n "$WINDOW_TITLE" ]]; then
  command -v xdotool >/dev/null 2>&1 || {
    echo "错误：窗口标题检查需要 xdotool。" >&2
    exit 2
  }
fi

SMOKE_HOME="$WORK_DIR/smoke-home"
SMOKE_RUNTIME="$WORK_DIR/smoke-runtime"
SMOKE_LOG="$WORK_DIR/smoke.log"
mkdir -p "$SMOKE_HOME/config" "$SMOKE_HOME/cache" "$SMOKE_HOME/data" "$SMOKE_RUNTIME"
chmod 0700 "$SMOKE_RUNTIME"

# 窗口模式只要求可见窗口出现后进程再存活两秒；到达上限仍无窗口即失败。
WINDOW_SCRIPT='
  app=$1
  title=$2
  shift 2
  "$app" "$@" &
  app_pid=$!
  trap '\''kill "$app_pid" 2>/dev/null || true; wait "$app_pid" 2>/dev/null || true'\'' EXIT
  while kill -0 "$app_pid" 2>/dev/null; do
    if xdotool search --onlyvisible --name "$title" 2>/dev/null | grep -q .; then
      sleep 2
      kill -0 "$app_pid" 2>/dev/null && exit 0
      exit 125
    fi
    sleep 1
  done
  wait "$app_pid" 2>/dev/null || true
  exit 125
'

# 参数始终使用数组传递；会话包裹顺序由调用方选择，不能统一改变既有启动语义。
if [[ -n "$WINDOW_TITLE" ]]; then
  COMMAND=(bash -c "$WINDOW_SCRIPT" bash "$APPIMAGE" "$WINDOW_TITLE" "${APP_ARGS[@]}")
else
  COMMAND=("$APPIMAGE" "${APP_ARGS[@]}")
fi

set +e
case "$SESSION_ORDER" in
  timeout-dbus-xvfb)
    HOME="$SMOKE_HOME" XDG_CONFIG_HOME="$SMOKE_HOME/config" \
    XDG_CACHE_HOME="$SMOKE_HOME/cache" XDG_DATA_HOME="$SMOKE_HOME/data" \
    XDG_RUNTIME_DIR="$SMOKE_RUNTIME" APPIMAGE_EXTRACT_AND_RUN=1 \
      timeout "${SECONDS_LIMIT}s" dbus-run-session -- xvfb-run -a "${COMMAND[@]}" >"$SMOKE_LOG" 2>&1
    ;;
  xvfb-dbus-timeout)
    HOME="$SMOKE_HOME" XDG_CONFIG_HOME="$SMOKE_HOME/config" \
    XDG_CACHE_HOME="$SMOKE_HOME/cache" XDG_DATA_HOME="$SMOKE_HOME/data" \
    XDG_RUNTIME_DIR="$SMOKE_RUNTIME" APPIMAGE_EXTRACT_AND_RUN=1 \
      xvfb-run -a dbus-run-session -- timeout "${SECONDS_LIMIT}s" "${COMMAND[@]}" >"$SMOKE_LOG" 2>&1
    ;;
  timeout-xvfb)
    HOME="$SMOKE_HOME" XDG_CONFIG_HOME="$SMOKE_HOME/config" \
    XDG_CACHE_HOME="$SMOKE_HOME/cache" XDG_DATA_HOME="$SMOKE_HOME/data" \
    XDG_RUNTIME_DIR="$SMOKE_RUNTIME" APPIMAGE_EXTRACT_AND_RUN=1 \
      timeout "${SECONDS_LIMIT}s" xvfb-run -a "${COMMAND[@]}" >"$SMOKE_LOG" 2>&1
    ;;
esac
STATUS=$?
set -e

cat "$SMOKE_LOG"
if grep -Eqi -- "$FATAL_PATTERN" "$SMOKE_LOG"; then
  echo "错误：图形启动日志包含调用方指定的致命错误：$SMOKE_LOG" >&2
  exit 1
fi

# 不查窗口时，124 表示进程一直运行到上限；窗口模式要求实际找到可见窗口。
if [[ -n "$WINDOW_TITLE" ]]; then
  [[ "$STATUS" -eq 0 ]] || {
    echo "错误：未检测到存活的可见窗口（退出码：$STATUS）：$SMOKE_LOG" >&2
    exit 1
  }
elif [[ "$STATUS" -ne 124 && ( "$SUCCESS_MODE" != timeout-or-zero || "$STATUS" -ne 0 ) ]]; then
  echo "错误：图形启动提前退出（退出码：$STATUS）：$SMOKE_LOG" >&2
  exit 1
fi
