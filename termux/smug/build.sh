#!/usr/bin/env bash
set -Eeuo pipefail

###### 准备构建目录 ######
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
: "${GITHUB_WORKSPACE:?请通过 GitHub Actions 构建}"
BUILD_DIR="$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/smug.XXXXXX")"

###### 下载上游源码 ######
# 保持现有上游分支来源，记录实际源码提交。
git clone --depth 1 https://github.com/ivaaaan/smug.git "$BUILD_DIR/source"
cd "$BUILD_DIR/source"
SMUG_REVISION="$(git rev-parse --short HEAD)"
PACKAGING_REVISION="$(git -C "$SCRIPT_DIR" rev-parse --short HEAD)"

###### 适配 Termux 启动与子进程 ######
# 精确修改已核对的命令入口；上游结构变化时退出，避免补丁静默失效。
python3 - <<'PY'
from pathlib import Path

for filename in ("smug.go", "tmux.go", "config.go", "worktree.go"):
    source = Path(filename)
    text = source.read_text()
    if text.count("exec.Command(") != 1:
        raise SystemExit(f"上游 {filename} 的命令入口发生变化，需要重新核对")
    text = text.replace("exec.Command(", "termuxCommand(")
    if filename == "smug.go":
        old = 'termuxCommand("/bin/sh", "-c", c)'
        if text.count(old) != 1:
            raise SystemExit("上游 shell 入口发生变化，需要重新核对")
        text = text.replace(old, 'termuxCommand("sh", "-c", c)')
    if "exec." not in text:
        text = text.replace('\t"os/exec"\n', "")
    source.write_text(text)
PY

# Android 专用适配在 main 解析参数前生效，不按程序文件名猜测参数。
cp "$SCRIPT_DIR/termux_compat_android.go" ./termux_compat_android.go

###### 编译 Android ARM64 程序 ######
# 保留 Android 目标，使用 Go 的 Android 系统调用兼容分支。
GOOS=android GOARCH=arm64 CGO_ENABLED=0 go build -trimpath \
  -ldflags "-X main.version=${SMUG_REVISION}-termux-${PACKAGING_REVISION}" -o smug .

###### 整理发布产物 ######
# 保持现有资产名，归档只包含 smug 可执行文件。
tar -czvf "$GITHUB_WORKSPACE/smug.termux.tar.gz" smug

# 将本次产物校验值写入构建日志。
sha256sum "$GITHUB_WORKSPACE/smug.termux.tar.gz"
