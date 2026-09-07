# asdf（Termux）

## 用途与产物

- 上游：[asdf-vm/asdf](https://github.com/asdf-vm/asdf)，通过插件管理项目所需的语言及工具版本。
- 技术栈：Go、urfave/cli；插件及 hook 通过 Bash 执行，插件仓库由 Git 管理。
- 目标：Android ARM64（Termux aarch64），`GOOS=android GOARCH=arm64 CGO_ENABLED=0`。
- 产物：`latest` Release 中的 `asdf.termux.tar.gz`，归档内为单个 `asdf` 可执行文件。
- 运行依赖：正常的 Termux `sh`、`bash`、`git` 环境，以及所选插件实际需要的工具；手机不需要安装 Go。

## 打包方式

- 入口：`.github/workflows/termux.yml` 的 `build-asdf` 独立 Job，使用 `actions/setup-go` 提供的稳定版 Go。
- 手动构建选择 `asdf`；每日构建全部工具；main 分支 push 按工具目录改动选择 Job，单纯 Markdown 文档改动不触发构建。
- `build.sh` 保持原有上游默认分支来源，每次在独立 Actions 临时目录获取源码，不固定应用版本。
- `cmd_termux_compat.go` 复制到上游 `cmd/asdf/termux_compat_android.go`，由 `init` 在命令行解析前归一化 linker 参数。
- `execute_termux_compat.go` 复制到上游 `internal/execute/termux_compat_android.go`；同时接入 `internal/execute/execute.go` 的 Bash 子进程和 `internal/exec/exec.go` 的进程替换入口。
- 补丁只替换已核对的入口，匹配失败即终止构建；保留上游版本信息，构建日志记录上游提交、打包提交和归档 SHA-256。
- 仅打包可执行文件，不打包插件、语言运行时或个人配置，不修改 shell 配置和 PATH。

## 运行与兼容说明

在 Termux 终端执行，以下以新产物的 `asdf` 已安装至 PATH 为前提。

```bash
# 查看 asdf 版本
asdf version
```

```bash
# 添加 Python 插件，沿用本次故障中的原命令
asdf plugin add python
```

- 仅在实际进程入口是 `linker64` 时移除多出的首个参数；不硬编码安装路径，正常直接启动时保持原参数。
- linker 模式下由系统 linker 启动 PATH 中的 Termux `sh`，再通过 `exec "$@"` 调用上游 Bash 或目标程序；应保留正常 Termux 环境及其 `LD_PRELOAD` 设置。
- `asdf exec`、shim 和插件扩展复用同一执行链，并保留进程替换及上游传入环境的语义。
- 本次修复针对 asdf 主程序的启动与执行链；插件自身及其下载、编译的语言运行时是否支持 Android，仍取决于对应插件和上游项目，不能由 asdf 主程序修复推定。

## 修复记录

### 2026-09-07：接入 Termux 参数与完整执行链适配

- 现象：`asdf plugin add python` 报 `invalid command provided: <asdf可执行文件路径>`，随后输出帮助信息。
- 根因：linker 启动使无 CGO Go 的参数偏移；原 `build.sh` 只下载上游并构建，没有复制仓库中的两个兼容文件。原参数修正函数未被调用且绑定固定路径，原子进程 helper 只是转发 `exec.Command`。此外，上游 `internal/exec/exec.go` 还有供 shim / exec / 插件扩展使用的直接 `syscall.Exec` 入口。
- 修改文件：`build.sh`、`cmd_termux_compat.go`、`execute_termux_compat.go`、新增本 README。
- 修复内容：接入参数初始化和两类执行入口，采用 smug 已实测的 linker / Termux shell 思路，并将 Linux PIE 目标改为 Android ARM64，使用 Go 的 Android 系统调用兼容分支。
- 已知结果：按当前上游源码核对入口、参数、环境、包依赖、补丁匹配、Bash / Go 语法及 workflow 产物路径；尚未取得本次 asdf 产物的 Actions 构建和手机实测结果，不能将 smug 的成功结论直接视为 asdf 已通过。

依据：[asdf 执行入口](https://github.com/asdf-vm/asdf/blob/master/internal/exec/exec.go)、[Termux linker 执行链](https://github.com/termux/termux-exec-package/blob/master/site/pages/en/projects/docs/technical/index.md)、[Go Android 系统调用分支](https://github.com/golang/go/blob/master/src/syscall/syscall_linux.go)。
