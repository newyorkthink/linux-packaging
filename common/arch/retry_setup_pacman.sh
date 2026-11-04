#!/usr/bin/env bash

# 只在共享 Arch 容器初始化步骤中接管 pacman 调用。
pacman() (
  set -o pipefail

  # 将本次安装输出写入临时日志，供判断下载失败原因。
  download_log="$(mktemp "${TMPDIR:-/tmp}/setup-pacman.XXXXXXXX")" || return
  trap 'rm -f -- "$download_log"' EXIT

  for attempt in 1 2 3 4 5; do
    # 保留上游传入的完整参数和 pacman 的签名校验。
    if /usr/bin/pacman "$@" 2>&1 | tee "$download_log"; then
      return 0
    else
      statuses=("${PIPESTATUS[@]}")
    fi

    # 日志写入失败时立即退出。
    if (( statuses[1] != 0 )); then
      return "${statuses[1]}"
    fi

    # 仅重试未安装任何软件包的网络下载失败。
    if ! grep -iEq "failed retrieving file '[^']+[.]pkg[.]tar[.][^']+' from .*:.*(SSL_read|SSL_ERROR_SYSCALL|timed out|timeout|Operation too slow|Connection reset|Could not resolve host|Failed to connect)" "$download_log" ||
       ! grep -Fq 'Errors occurred, no packages were upgraded.' "$download_log"; then
      return "${statuses[0]}"
    fi

    # 达到尝试上限时返回 pacman 的失败状态。
    if (( attempt == 5 )); then
      printf 'Arch 初始化下载失败，已尝试 5 次。\n' >&2
      return "${statuses[0]}"
    fi

    # 按 5、10、15、20 秒退避后，以原参数重试。
    delay=$((attempt * 5))
    printf 'Arch 初始化下载失败，%d 秒后重试（第 %d/5 次尝试失败）。\n' "$delay" "$attempt" >&2
    sleep "$delay"
  done
)
