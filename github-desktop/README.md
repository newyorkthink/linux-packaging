# GitHub Desktop AppImage

本目录用于把 GitHub 官方 `desktop/desktop` 最新稳定源码构建为 x86_64 Linux AppImage。

## 强制规则：永远禁止第三方 GitHub Desktop

本项目 **永远只允许使用 GitHub 官方 `desktop/desktop` 仓库源码作为 GitHub Desktop 的构建来源**。

以下内容全部永久禁止作为源码、依赖来源、构建输入、二进制来源、替代实现或打包基础：

- 任何第三方 GitHub Desktop fork；
- `shiftkey/desktop` 以及其任何分支、Release、二进制或派生包；
- 任何社区版 GitHub Desktop；
- 任何第三方 AppImage、DEB、RPM、AUR 包、Flatpak、Snap 或其他预编译包；
- 任何从第三方 Linux GitHub Desktop 成品中提取、复制、重打包或复用的文件；
- 任何“官方没有 Linux 成品，所以临时改用第三方版本”的替代方案。

即使 GitHub 官方暂时没有 Linux 二进制发行版，也 **不得回退、切换或借用任何第三方实现**。如果未来官方源码结构变化导致 Linux 构建失败，只允许基于当时最新的 GitHub 官方 `desktop/desktop` 源码继续适配和修复；宁可构建失败，也不能换成第三方版本。

构建输入只使用 GitHub 官方 `desktop/desktop` 源码及该官方仓库自己声明的依赖和子模块，不下载、复制或重新封装任何第三方 GitHub Desktop Linux 成品。

## 构建流程

1. 从 GitHub 官方 `desktop/desktop` Release API 读取最新稳定 `release-X.Y.Z` tag，并只拉取该官方源码及其声明的子模块。
2. 严格使用该 tag 的 `.node-version` 和官方 `yarn.lock` 安装依赖，再执行官方 `yarn build:prod` 生成 `dist/desktop-linux-x64`。
3. Linux 只补官方源码在 Linux 运行时确实缺失的必要适配，不替换 GitHub Desktop 的业务实现，也不引入第三方 GitHub Desktop 代码。
4. AppImage 使用自建 `AppRun` 直接启动官方源码构建出的 `desktop`，完整保留 Electron 目录相对布局；同时设置稳定的 `CHROME_DESKTOP` 和 XDG 协议入口，避免 AppImage 临时挂载路径破坏登录回调。
5. AppRun 为 GitHub Desktop 配置独立 Fontconfig 缓存目录，避免宿主系统存在“缓存由更高版本 Fontconfig 生成”时把 Electron 启动卡住。
6. AppImage 固定使用 AppImage 官方 `type2-runtime` 的稳定版本 `20251108`，并校验官方 SHA256，不自动跟随 continuous runtime。
7. AnyLinux 构建容器先验证官方源码目录和 AppImage 解包运行路径；发布后再由独立 Ubuntu 宿主 Job **直接执行 `./github-desktop.AppImage`**，必须检测到可见 `GitHub Desktop` 窗口，并且不得出现不兼容 Fontconfig 缓存警告，否则整个 Workflow 失败。
8. 最终只输出一个发布文件：`dist/github-desktop.AppImage`，继续由现有 `build-anylinux` Action 发布到 `latest` Release。

GitHub 官方目前仍未提供正式 Linux 二进制发行包；这里生成的是**仅基于 GitHub 官方源码自行构建的非官方 Linux AppImage**，不是任何第三方社区版的重新打包。
