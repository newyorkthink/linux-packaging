# GitHub Desktop AppImage

本目录用于把 GitHub 官方 `desktop/desktop` 最新稳定源码构建为 x86_64 Linux AppImage。

构建流程：

1. 从 GitHub 官方 Release API 读取最新稳定 `release-X.Y.Z` tag。
2. 按官方 `.node-version` 下载对应 Node.js，并使用 Yarn Classic 安装锁定依赖。
3. 调用官方 `yarn build:prod` 生成 Linux Electron 目录。
4. 仅补 Linux 可执行文件名、PNG 图标和 AppImage 封装层；不替换 GitHub Desktop 应用代码。
5. 使用 Xvfb 做启动烟测，通过后输出 `dist/github-desktop.AppImage`。

GitHub 官方目前没有正式支持的 Linux Desktop 发行包；本目录生成的是基于官方开源源码的非官方 Linux 打包产物。
