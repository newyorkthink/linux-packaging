# GitHub Desktop AppImage

本目录用于把 GitHub 官方 `desktop/desktop` 最新稳定源码构建为 x86_64 Linux AppImage。

当前实现已经完成正式 Linux AppImage 构建、Release 发布、Ubuntu 24.04 宿主直接启动验证，以及 Kali/滚动发行版常见 Fontconfig 缓存兼容处理。

## 当前状态

- 上游源码：只使用 GitHub 官方 `desktop/desktop` 最新稳定 `release-X.Y.Z` tag。
- 构建基线：Ubuntu 22.04，降低 Linux 原生模块 ABI 要求。
- 发布文件：`latest` Release 中的 `github-desktop.AppImage`。
- 发布后验证：独立 Ubuntu 24.04 Job 从 `latest` Release 重新下载 AppImage，再直接执行并要求出现可见的 `GitHub Desktop` 窗口。
- 2026-08-28 实测：当前 `latest` 在全新用户数据目录下首次出现可见窗口约 11 秒；首次启动后会复用已经生成的 Electron 用户数据和 GitHub Desktop 专用 Fontconfig 缓存。

## Linux 用户数据与配置目录

GitHub Desktop 没有在 AppImage 旁边建立便携配置目录，正常使用 Electron 的 Linux 用户数据目录。

默认路径如下：

| 类型 | 默认路径 | 说明 |
| --- | --- | --- |
| GitHub Desktop 主用户数据 | `~/.config/GitHub Desktop/` | 正常配置目录；如果设置了 `XDG_CONFIG_HOME`，则位于 `$XDG_CONFIG_HOME/GitHub Desktop/` |
| GitHub Desktop 专用 Fontconfig 缓存 | `~/.cache/github-desktop/fontconfig/` | 首次启动生成；如果设置了 `XDG_CACHE_HOME`，则位于 `$XDG_CACHE_HOME/github-desktop/fontconfig/` |
| Desktop / URL 协议入口 | `~/.local/share/applications/github-desktop.desktop` | AppImage 启动时维护，用于 GitHub 登录回调等 URL Scheme |

`~/.config/GitHub Desktop/` 中看到下面这些目录或文件属于 Electron/Chromium 正常用户数据，不是打包残留：

- `blob_storage`
- `Cache`
- `Code Cache`
- `Crashpad`
- `DawnGraphiteCache`
- `DawnWebGPUCache`
- `Dictionaries`
- `GPUCache`
- `IndexedDB`
- `Local Storage`
- `Session Storage`
- `Shared Dictionary`
- `WebStorage`
- `Cookies`
- `Local State`
- `Network Persistent State`
- `Preferences`
- `TransportSecurity`
- `Trust Tokens`
- `logs`
- `window-state.json`

因此 `~/.config/GitHub Desktop/` 整个目录保持现状即可，不需要手工拆分、迁移或清理。

## 首次启动为什么比后续启动慢

当前 AppImage 有意隔离 Fontconfig 缓存：

```text
~/.cache/github-desktop/fontconfig/
```

原因是滚动发行版、Fontconfig 升降级或宿主残留缓存可能出现“缓存由更高版本 Fontconfig 生成”的冲突。GitHub Desktop 使用的 Electron 如果直接读取这类宿主缓存，可能在启动阶段长时间卡住。

因此首次启动时需要完成两类一次性初始化：

1. Electron/Chromium 创建 `~/.config/GitHub Desktop/` 下的用户数据、缓存和本地存储结构。
2. Fontconfig 为当前宿主字体生成 GitHub Desktop 自己的缓存。

当前 Release 的独立 Ubuntu 24.04 全新 profile 实测首次可见窗口约 11 秒。这个时间包含真实 AppImage 直启和上述首次初始化；不是构建目录或解包目录的模拟测试。

为了保持兼容性，当前实现**不改回宿主全局 Fontconfig 缓存，也不为了缩短一次性的首启时间删除隔离逻辑**。正常使用时不要反复删除 `~/.cache/github-desktop/fontconfig/` 或 `~/.config/GitHub Desktop/`，否则会重新产生首次初始化开销。

## IBus 提示

终端偶尔出现：

```text
IBUS-WARNING **: desktop has no capability of surrounding-text feature
```

这是 Electron/Chromium 与 IBus 输入法能力协商产生的 warning。当前实现不会为了隐藏这条日志去禁用 IBus、修改 `GTK_IM_MODULE` 或重定向程序错误输出，避免影响正常中文输入。

如果中文输入本身正常，这条 warning 不需要处理。

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
4. 对官方 `printenvz` 和 `desktop-trampoline` 的 Linux `_FORTIFY_SOURCE` / `-Werror` 冲突只做最小兼容补丁，仍保留上游要求的 `FORTIFY=1`。
5. AppImage 使用自建 `AppRun` 直接启动官方源码构建出的 `desktop`，完整保留 Electron 目录相对布局；同时维护稳定的 `CHROME_DESKTOP` 和 XDG 协议入口，避免 AppImage 临时挂载路径破坏登录回调。
6. GitHub Desktop 使用独立 Fontconfig 缓存目录，避免宿主系统不同版本缓存导致 Electron 启动异常。
7. Linux 原生 `.node` 模块使用 Ubuntu 22.04 依赖作为兼容基线，只打包所需非基础动态库；GLib/GIO/GObject 和 glibc 继续使用宿主系统版本，避免同 SONAME ABI 混装。
8. AppImage 固定使用 AppImage 官方 `type2-runtime` 稳定版本 `20251108`，并校验官方 SHA256，不自动跟随 continuous runtime。
9. 构建机先验证官方源码目录和最终 AppImage 解包运行路径；发布后独立 Ubuntu 24.04 Job 再从 `latest` Release 下载正式资产并直接执行，必须检测到可见窗口，且不得出现已知的不兼容 Fontconfig 缓存警告。
10. 最终发布文件保持为 `github-desktop.AppImage`，由独立 GitHub Desktop workflow 上传到仓库 `latest` Release。

GitHub 官方目前仍未提供正式 Linux 二进制发行包；这里生成的是**仅基于 GitHub 官方源码自行构建的非官方 Linux AppImage**，不是任何第三方社区版的重新打包。
