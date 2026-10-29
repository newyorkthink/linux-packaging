# ChatGPT / Codex AppImage

本目录将 OpenAI 官方 ChatGPT Linux x64 `.deb` 重新封装为 `chatgpt.AppImage`。官方桌面应用同时包含 ChatGPT、Codex、Code Mode Host、插件和 Computer Use 运行组件。

## 构建来源

- [OpenAI Codex 页面](https://openai.com/zh-Hans-CN/codex/)
- [OpenAI 官方 Linux 安装说明](https://learn.chatgpt.com/docs/linux/linux-app)
- [OpenAI Codex 沙盒说明](https://learn.chatgpt.com/docs/sandboxing)
- OpenAI 官方 stable APT 仓库：`https://persistent.oaistatic.com/codex-app-prod/linux/deb`

构建先通过公共入口安装已核实的 AUR `chatgpt-desktop` 及依赖，再由公共 AUR 下载入口读取当前 `.SRCINFO`，独立下载其中声明的 OpenAI 官方 x86_64 DEB，并按 SHA-256 校验。版本读取本次 DEB 内的 `resources/linux-package-metadata.json`，不锁定应用版本，也不在应用脚本解析 APT 元数据。

当前 AUR 来源：[PKGBUILD](https://github.com/archlinux/aur/blob/fac212f2e43f029d6c5b336c82d1ebf68da77949/PKGBUILD)、[.SRCINFO](https://github.com/archlinux/aur/blob/fac212f2e43f029d6c5b336c82d1ebf68da77949/.SRCINFO)。参考的同应用 pkgforge 打包：[准备脚本](https://github.com/pkgforge-dev/ChatGPT-Desktop-AppImage/blob/0e52cadeafc0229ea9a55415a70a2abc00d0bf07/get-dependencies.sh)、[封装脚本](https://github.com/pkgforge-dev/ChatGPT-Desktop-AppImage/blob/0e52cadeafc0229ea9a55415a70a2abc00d0bf07/make-appimage.sh)。

## 打包说明

- 按直接下载标准执行：初始化、安装、清理目录、三行公共下载、公共解包、完整复制程序、元数据、版本读取、依赖收集、中文环境、最终封装及单行版本保存。
- 完整复制官方 `/usr/lib/chatgpt/` 到 `AppDir/bin/`；主 desktop 和图标分别读取系统安装的 `/usr/share/applications/chatgpt.desktop`、`/usr/share/pixmaps/chatgpt.png`。
- 原样采用 pkgforge 的 Qt shim 删除及全目录收集命令。删除范围限于 `AppDir/bin/libqt*_shim.so`；其必要性判断、Qt 依赖影响和 Plasma 验证边界见 [官方处理记录](docs/pkgforge-differences.md)。
- 保留宿主 bwrap 优先级和 `--no-sandbox --disable-setuid-sandbox`，通过两个运行时 hook 接入标准 AppRun，不再另写 `AppRun.sh`。这些参数只针对 Electron/Chromium，不关闭 Codex 自身的命令沙箱。
- GTK 输入模块交给 quick-sharun 收集；包内按标准生成中文 locale。官方完整程序目录中的 Codex、Code Mode Host、插件及 Computer Use 资源随目录复制，产品功能是否开放仍由上游决定。
- 取消旧的内联 APT 下载解析、ELF 数组筛选、手工库搜索路径、禁用 Electron 自动部署的开关，以及解包产物、哈希一致性、Codex 沙盒和 Xvfb 冒烟自测。采用工具默认部署后，不再沿用旧脚本的“部署后核心文件摘要与源完全一致”保证。
- 本次未修改工作流或其他应用。旧 CI 沙盒及图形测试结果继续作为历史记录保留，不写成这份新脚本已经重新完成了这些验证。

详细配置见 [模板差异与代码位置](docs/template-deviations.md)、[固定配置依据](docs/hardcoded.md)、[官方处理的采用与不采用](docs/pkgforge-differences.md)。

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

旧构建流程曾在 CI 执行真实 Codex 沙盒检查，见下方修复历史。本次标准化稿不再内嵌这些自测；本次只沿用已有的运行时 PATH 处理，不声称新稿已重新通过沙盒或图形验收。

终端用户仍需在宿主 Linux 发行版安装 `bubblewrap`。`--no-sandbox` 和 `--disable-setuid-sandbox` 只处理 Electron/Chromium 的启动限制，并不会关闭或替代 Codex 自己的命令沙盒。

OpenAI 当前将 Linux 桌面版标记为预览版，并正式支持指定版本的 Ubuntu、Debian 和 Fedora。这里生成的 AppImage 是本仓库的便携重打包产物，不是 OpenAI 官方发布格式。

虽然官方 Linux 包内含相关运行资源，但 OpenAI 当前文档明确说明 Computer Use 尚未在 Linux 预览版开放；本项目不会绕过该产品限制。

## 2026-10-30：按标准骨架整理打包

- 下载、安装、解包和版本读写统一使用既有公共入口；主程序目录、系统图标和主 desktop 直接使用已核实的包布局。
- 只直接复用 pkgforge 的 `rm -f ./AppDir/bin/libqt*_shim.so` 与 `quick-sharun ./AppDir/bin/*`，命令逐字保留。官方 Qt 主题适配说明仍有 Plasma 待测试项，不声称删除对所有桌面均无影响。
- 保留原有宿主 bwrap PATH 和两个 Electron 启动参数，改由标准 AppRun 的 hook 执行；构建期不新增 APPDIR、SOURCE_DIR 或 APP_ROOT 目录包装变量。
- 清理旧脚本的下载解析、循环筛选、手工库路径、额外部署开关、产物自检和冒烟测试。下方历史故障记录原样保留。
- 复用聊天草稿已经完成的 Bash / hook 语法检查结果；本次仅核对获批文本、完整 diff、代码行号及文档。没有重复安装、构建、测试或实机运行。

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
