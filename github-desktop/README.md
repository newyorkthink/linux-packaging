# GitHub Desktop AppImage

本目录用于把 GitHub 官方 `desktop/desktop` 最新稳定源码构建为 x86_64 Linux AppImage。

构建输入只使用 GitHub 官方 `desktop/desktop` 源码；不下载、复制或重新封装任何第三方 GitHub Desktop Linux 成品。

构建流程：

1. 从 GitHub 官方 `desktop/desktop` Release API 读取最新稳定 `release-X.Y.Z` tag，并只拉取该官方源码及其声明的子模块。
2. 严格使用该 tag 的 `.node-version` 和官方 `yarn.lock` 安装依赖，再执行官方 `yarn build:prod` 生成 `dist/desktop-linux-x64`。
3. Linux 只补一处官方源码缺失的协议参数处理：让冷启动和 `second-instance` 能从 argv 接收 `x-github-*://` 回调；不修改 GitHub Desktop 业务逻辑。
4. AppImage 使用自建 `AppRun` 直接启动官方构建出的 `desktop`，完整保留 Electron 目录相对布局；同时设置稳定的 `CHROME_DESKTOP` 和 XDG 协议入口，避免 AppImage 临时挂载路径破坏登录回调。
5. 先对官方源码构建目录做一次真实 GUI 窗口烟测，再对最终 AppImage 做第二次烟测；两次都必须检测到可见 `GitHub Desktop` 窗口，否则停止发布。
6. 最终只输出一个发布文件：`dist/github-desktop.AppImage`，继续由现有 `build-anylinux` Action 发布到 `latest` Release。

GitHub 官方目前仍未提供正式 Linux 二进制发行包；这里生成的是**基于 GitHub 官方源码自行构建的非官方 Linux AppImage**。
