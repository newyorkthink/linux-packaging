# ChatGPT / Codex AppImage

本目录将 OpenAI 官方 ChatGPT Linux x64 `.deb` 重新封装为 `chatgpt.AppImage`。官方桌面应用同时包含 ChatGPT、Codex、Code Mode Host、插件和 Computer Use 运行组件。

## 构建来源

- [OpenAI Codex 页面](https://openai.com/zh-Hans-CN/codex/)
- [OpenAI 官方 Linux 安装说明](https://learn.chatgpt.com/docs/linux/linux-app)
- [OpenAI Codex 沙盒说明](https://learn.chatgpt.com/docs/sandboxing)
- OpenAI 官方 stable APT 仓库：`https://persistent.oaistatic.com/codex-app-prod/linux/deb`

构建脚本动态读取官方 `Packages` 元数据，下载当前 `amd64` 稳定包，并使用其中的文件大小和 SHA-256 校验下载内容；不会写死应用版本。

## 打包说明

- 完整保留官方 `/usr/lib/chatgpt` 运行目录、desktop、图标和 copyright 文件。
- 不执行 deb 的 `postinst`、`prerm` 或 `postrm`，不向宿主系统写入 APT 源、密钥或 AppArmor 配置。
- AppImage 无法使用官方 deb 针对固定安装路径提供的 AppArmor userns 规则，因此便携入口使用 `--no-sandbox --disable-setuid-sandbox` 启动 Electron/Chromium；这两个参数只针对 Electron/Chromium，不代表禁用 Codex 命令沙盒。
- ChatGPT AppImage 的 Codex 命令沙盒依赖宿主发行版安装的 `bubblewrap`。启动入口会把 `/usr/bin` 和 `/bin` 放在 PATH 最前，确保优先使用宿主 `/usr/bin/bwrap`；AppImage 内部工具目录保留在 PATH 末尾，只作为后备，不会删除或替换宿主 `bwrap`。
- 构建后会检查最终 AppImage 的关键资源、动态库和官方 Codex 二进制摘要，并使用最终 AppImage 内的 `resources/codex` 执行 `codex sandbox /usr/bin/true`，随后在隔离 HOME、D-Bus 与 Xvfb 中执行图形启动测试。
- GitHub Actions 的 ChatGPT Job 单独以 `--privileged` 启动临时 Arch Linux 构建容器，仅用于允许嵌套 `bubblewrap` 在 CI 中创建 namespace 并执行上述真实 Codex 沙盒测试；该 CI 权限不会进入 AppImage，也不改变终端用户运行时的权限模型。

## Codex / bubblewrap PATH 陷阱

这是 ChatGPT AppImage 重打包时需要特别注意的一个坑：Codex 在 Linux 上会使用 `PATH` 中找到的第一个 `bwrap`。如果 AppImage 启动入口把自身工具目录放在系统目录前面，例如：

```bash
export PATH="$APPDIR/bin${PATH:+:$PATH}"
```

那么 Codex 可能优先调用 AppImage 内由打包工具带入的 `bwrap`，而不是宿主发行版通过软件包安装的 `/usr/bin/bwrap`。实际出现过的故障为：

```text
bwrap: unknown cap: --proc
```

该问题与 Codex 配置、工作目录权限或 Electron 的 `--no-sandbox` 无关，本质是 `bwrap` 的 PATH 优先级错误。同一个官方 Codex 二进制在优先使用宿主 `/usr/bin/bwrap` 后即可正常执行沙盒命令。

本仓库已经固定为：

```bash
export PATH="/usr/bin:/bin${PATH:+:$PATH}:$APPDIR/bin"
```

因此运行时优先级为 `/usr/bin` → `/bin` → 原宿主 PATH → AppImage 内工具目录。宿主 `/usr/bin/bwrap` 始终优先；AppImage 内的 `bwrap` 不删除，只作为后备。

最终 AppImage 的构建验证会直接使用其中的官方 `resources/codex` 执行：

```text
codex sandbox /usr/bin/true
```

该测试必须以退出码 `0` 完成；任何 `bwrap` 错误都会使构建失败。当前 CI 已通过这项真实 Codex 沙盒测试，避免仅靠 ChatGPT 图形界面冒烟测试而漏掉 Codex 命令沙盒问题。

终端用户仍需在宿主 Linux 发行版安装 `bubblewrap`。`--no-sandbox` 和 `--disable-setuid-sandbox` 只处理 Electron/Chromium 的启动限制，并不会关闭或替代 Codex 自己的命令沙盒。

OpenAI 当前将 Linux 桌面版标记为预览版，并正式支持指定版本的 Ubuntu、Debian 和 Fedora。这里生成的 AppImage 是本仓库的便携重打包产物，不是 OpenAI 官方发布格式。

虽然官方 Linux 包内含相关运行资源，但 OpenAI 当前文档明确说明 Computer Use 尚未在 Linux 预览版开放；本项目不会绕过该产品限制。

## 修复记录

本节用于持续记录 ChatGPT AppImage 的实际修复。后续每次修复都在这里追加新记录，不覆盖、删除或改写已有修复记录。每条至少写明日期、故障现象、根因、修改文件、具体修复内容和对应提交；单纯文档整理不作为运行故障修复记录。

### 2026-09-01 — 修复当前 Electron 冒烟测试失败

- 提交：`78b3cd277292b7d60c5b5c4ec30fbab77e1b0f57`
- 故障现象：ChatGPT AppImage 已完成构建，Codex 沙盒测试也以退出码 `0` 通过，但图形冒烟测试最终失败。日志明确出现 `GPU access not allowed`，随后测试结束阶段又出现 D-Bus 断开触发的 `FATAL`。
- 根因：冒烟测试额外传入 `--disable-gpu`，而当前 OpenAI ChatGPT Linux 桌面应用内部同时禁用了软件光栅回退，因此应用直接拒绝这种完整禁用 GPU 的启动方式；同时原来的 `timeout 40s xvfb-run -a dbus-run-session -- ...` 会先结束外层测试进程，再释放 D-Bus / Xvfb，会把正常 teardown 阶段的总线断开表现成致命错误。
- 修改文件：`chatgpt/build_chatgpt.sh`
- 修复内容：删除冒烟测试中的 `--disable-gpu`，让 Xvfb 环境下保留 Electron 自身的软件渲染回退；同时把 `timeout 40s` 移到 `xvfb-run -a dbus-run-session --` 内部，确保先终止 ChatGPT，再释放 D-Bus 会话和虚拟显示。
- 保留内容：没有改应用版本获取方式，没有锁版本，没有移除既有的 Codex `bubblewrap` 沙盒验证，也没有放宽原有共享库、ELF、sandbox 和启动致命错误检查。

### 2026-08-31 — 修复 Codex `bubblewrap` PATH 优先级

- 提交：`f7534deb1583cf8c27ced9b86280d9a69f9e8a2a`
- 故障现象：ChatGPT 主界面能够启动，但 Codex Linux 命令沙盒执行时出现 `bwrap: unknown cap: --proc`。
- 根因：AppImage 启动入口原先把 `$APPDIR/bin` 放在 PATH 最前，Codex 会优先调用 AppImage 内由打包工具带入的 `bwrap`，而不是宿主系统安装的 `/usr/bin/bwrap`。
- 修改文件：`chatgpt/build_chatgpt.sh`、`chatgpt/README.md`
- 修复内容：将启动 PATH 固定为 `/usr/bin:/bin` 优先、AppImage 内工具目录最后；构建时显式要求 `/usr/bin/bwrap` 存在；并在最终 AppImage 验证阶段直接运行 `resources/codex sandbox /usr/bin/true`，任何 `bwrap` 错误或非零退出码都会使构建失败。

### 2026-08-31 — 修复 CI 中 Codex 沙盒权限不足

- 提交：`e93c922606e3d5569185bc27c4ccdce06fa8ee2b`
- 故障现象：新增真实 Codex `bubblewrap` 沙盒测试后，GitHub Actions 的默认 Arch Linux 容器无法完成嵌套 namespace 沙盒验证。
- 根因：这是 CI 构建容器权限限制，不是最终 AppImage 运行时权限问题；默认容器缺少执行这项嵌套 `bubblewrap` 测试所需的 namespace 能力。
- 修改文件：`.github/workflows/build.yml`、`chatgpt/README.md`
- 修复内容：仅 ChatGPT Job 使用 `ghcr.io/pkgforge-dev/archlinux:latest` 并增加 `options: --privileged`，用于 CI 中执行真实 Codex 沙盒验证；该权限只属于临时构建容器，不会写入 AppImage，也不会改变终端用户运行时权限模型。
