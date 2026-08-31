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
