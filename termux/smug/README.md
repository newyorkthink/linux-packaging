# smug（Termux）

## 用途与产物

- 上游：[ivaaaan/smug](https://github.com/ivaaaan/smug)，使用 YAML 创建 tmux 会话、窗口和面板。
- 技术栈：Go、pflag、yaml.v3；目标为 Android ARM64（Termux aarch64）。
- 产物：`latest` Release 中的 `smug.termux.tar.gz`，归档内为单个 `smug` 可执行文件。
- 运行依赖：Termux 的 `sh`、`tmux`，以及配置中实际调用的程序；不需要手机安装 Go。

## 打包方式

- 入口：`.github/workflows/termux.yml` 的 `build-smug` Job；手动构建时选择 `smug`，每日全量构建保持不变。
- push 仅接受 main；按工具目录的实际改动选择对应 Job，修改 workflow 时构建全部，仅修改 Markdown 文档时不触发构建。
- `build.sh` 在 Actions 临时目录下载上游默认分支，保持原有动态源码来源；`actions/setup-go` 提供稳定版 Go。
- `termux_compat_android.go` 修复 Android linker 启动时的参数偏移，并适配子进程执行；构建脚本将上游命令入口接入该适配。
- 保持 `GOOS=android GOARCH=arm64 CGO_ENABLED=0`，由 Go 的 Android 分支生成可执行文件，不再切换到 Linux 目标。
- 帮助信息包含上游与打包仓库的短提交号，便于辨别实际安装的构建；构建日志记录归档 SHA-256。
- 配置、shell alias、tmux 设置均由使用者管理，不打包或覆盖个人配置。

## 已验证基准

- 基准提交：[`ff920a0`](https://github.com/newyorkthink/linux-packaging/commit/ff920a02a4cbe999ca551764a92b45f30b92796c)。用户于 2026-09-06 确认有效，项目名启动及现有启动别名能够加载配置并进入 tmux 会话，窗口已正常创建。
- `build.sh` 的 Android 编译方式和 `termux_compat_android.go` 的参数 / 子进程适配视为稳定基线；后续只针对有实际证据的新问题修改，不因整理文档或 workflow 重写。
- 这是已验证实现的基准记录，不锁定上游版本，也不代表其他工具、设备或所有命令形式均已验证。

## 运行与兼容说明

在 Termux 终端执行。以下以 `smug` 已安装至 PATH 为前提，配置路径须替换为实际路径。

```bash
# 查看当前安装版本与打包提交号
smug --help
```

```bash
# 明确指定配置文件并启动会话
smug start -f "<配置文件路径>"
```

- 通过项目名启动时，上游查找 `~/.config/smug/<项目名>.yml` 或 `.yaml`；项目名来自文件名，不是 YAML 的 `session` 值。
- 指定文件时保留上面的 `start -f` 完整写法；实测仅使用 `smug -f ...` 会触发上游 `ParseOptions` 的空切片越界。本次记录用法边界，不改动已验证的运行实现。
- 未指定项目名或 `-f` 时，上游可使用 `SMUG_SESSION_CONFIG_PATH`，否则查找当前目录的 `.smug.yml`。
- YAML 的 `$HOME` 等环境变量由上游配置解析器展开，沿用原有格式。
- 配置钩子的 shell 改为从 PATH 查找 `sh`，不再要求 Android 存在 `/bin/sh`。
- 实际通过 `linker64` 启动时，先归一化 Go 参数，再由 linker 启动 Termux shell 执行子命令，使其经过 Termux 的 libc / termux-exec 执行链；需保留正常 Termux 环境及其 `LD_PRELOAD` 设置。
- 正常直接启动时不删除参数，也不额外使用 linker。不会因为项目路径以 `smug` 结尾而误删参数。

## 修复记录

### 2026-09-06：修复 Termux 参数与配置命令执行链

- 现象：运行时出现 `config not found for project <可执行文件路径>`；历史 Linux 目标产物还出现 TLS 对齐报错及 `SIGSYS` 反馈。
- 根因：无 CGO 的 Go 读取原始参数，Termux linker 启动会额外插入可执行文件路径；原补丁只根据路径和 `smug` 后缀猜测。上游配置钩子固定使用 `/bin/sh`，且 Go 的直接 `execve` 不经过 Termux 的 libc 拦截，单改参数不足以完成整个启动流程。
- 修改文件：`build.sh`、新增 `termux_compat_android.go`、新增本 README。
- 修复内容：按实际进程入口识别 linker 模式，统一修正参数及 tmux / shell / 编辑器 / git 的子进程入口；保留 Android 编译目标，源码入口变化时明确终止构建。
- 提交时结果：已核对上游源码、Termux 官方执行链说明、Go Android 系统调用分支和上传配置结构，并进行仓库外静态检查。当时尚无修复后的手机端运行反馈；后续实测结果见“已验证基准”。
- 历史提交：`156e687` 切换 Linux PIE，`e0f6fe7` 增加参数过滤及 ELF cleaner，`a2d20e8` 恢复 Android 目标；上述历史构建成功不等于手机端功能已验证。

### 2026-09-06：记录实测基线并收窄 push 构建范围

- 现象：用户确认 `ff920a0` 产物可用；原 Termux workflow 的 push 未限定分支，任意工具或文档变动都会同时构建 smug 与 asdf。
- 修改文件：`.github/workflows/termux.yml`、`AGENTS.md`、本 README。
- 调整内容：参照现有 RunImage / AppImage 的 main 分支及变更筛选，保留手动选择、每日构建、独立 Job 和原有发布步骤；补充稳定基线及 `start -f` 用法边界。
- 已知结果：构建脚本和 Android 适配文件与 `ff920a0` 完全一致；workflow 完成 YAML、内嵌 Bash 和路径 / 依赖静态核对，本次使用 `[skip ci]` 提交，Actions 由用户运行。

依据：[Termux linker 执行链与已知限制](https://github.com/termux/termux-exec-package/blob/master/site/pages/en/projects/docs/technical/index.md)、[Go Faccessat 的 Android 分支](https://github.com/golang/go/blob/master/src/syscall/syscall_linux.go)、[smug 配置说明](https://github.com/ivaaaan/smug#configuration)。
