# GitHub Desktop AppImage

本目录用于发布 x86_64 Linux GitHub Desktop AppImage。

GitHub 官方 `desktop/desktop` README 明确说明 Linux 不受官方支持，并将 Linux 用户指向社区维护发行版。因此这里不再直接编译官方源码；此前直接编译虽然进程可以存活，但实际可能无法创建 GUI 窗口。

构建流程：

1. 从 `shiftkey/desktop` 的最新正式 Release 自动读取 Linux release tag。
2. 只选择 `GitHubDesktop-linux-x86_64-*.AppImage` 及其官方 `.sha256` 文件。
3. 下载后先严格校验 SHA256，校验失败立即停止，不发布错误产物。
4. 保持现有仓库发布名 `dist/github-desktop.AppImage`，继续由现有 `build-anylinux` Action 发布到 `latest` Release。
5. 在 Xvfb 中启动 AppImage，并使用 `xdotool` 检测实际可见的 `GitHub Desktop` 窗口；只有真正创建 GUI 窗口才视为通过。

当前 Linux 发行来源是 GitHub 官方 README 指向的 `shiftkey/desktop` Linux 社区维护版，不是 GitHub 官方 Linux 二进制。
