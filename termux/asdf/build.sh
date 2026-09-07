#!/usr/bin/env bash
set -Eeuo pipefail

###### 准备构建目录 ######
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
: "${GITHUB_WORKSPACE:?请通过 GitHub Actions 构建}"
BUILD_DIR="$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/asdf.XXXXXX")"

###### 下载上游源码 ######
# 保持现有上游分支来源，记录实际源码和打包提交。
git clone --depth 1 https://github.com/asdf-vm/asdf.git "$BUILD_DIR/source"
cd "$BUILD_DIR/source"
git rev-parse HEAD
git -C "$SCRIPT_DIR" rev-parse HEAD

###### 适配 Termux 参数与进程执行 ######
# 同时接入普通子进程和替换进程入口；上游结构变化时明确退出。
python3 - <<'PY'
from pathlib import Path

patches = {
    "internal/execute/execute.go": (
        ('exec.Command("bash", "-c", command)', 'termuxCommand("bash", "-c", command)'),
        ('\t"os/exec"\n', ''),
    ),
    "internal/exec/exec.go": (
        ('\t"syscall"\n', '\t"github.com/asdf-vm/asdf/internal/execute"\n'),
        (
            'return syscall.Exec(executablePath, append([]string{executablePath}, args...), env)',
            'return execute.TermuxExec(executablePath, args, env)',
        ),
    ),
}
for filename, replacements in patches.items():
    source = Path(filename)
    text = source.read_text()
    for old, new in replacements:
        if text.count(old) != 1:
            raise SystemExit(f"上游 {filename} 的执行入口发生变化，需要重新核对")
        text = text.replace(old, new)
    source.write_text(text)
PY

# main 包通过 init 在 CLI 解析前归一化参数。
cp "$SCRIPT_DIR/cmd_termux_compat.go" ./cmd/asdf/termux_compat_android.go
# execute 包提供 Bash 子进程及 asdf exec / shim 共用的适配。
cp "$SCRIPT_DIR/execute_termux_compat.go" ./internal/execute/termux_compat_android.go

###### 编译 Android ARM64 程序 ######
# 采用 smug 已实测的 Android 目标，避免 Linux 目标的系统调用兼容问题。
GOOS=android GOARCH=arm64 CGO_ENABLED=0 go build -trimpath -o asdf ./cmd/asdf

###### 整理发布产物 ######
# 保持现有资产名，归档仅包含 asdf 可执行文件。
tar -czvf "$GITHUB_WORKSPACE/asdf.termux.tar.gz" asdf
# 将产物校验值写入构建日志。
sha256sum "$GITHUB_WORKSPACE/asdf.termux.tar.gz"
