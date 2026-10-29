# Claude Desktop AppImage

本目录将 AUR 指向的 Anthropic 官方 Linux DEB 封装为 x86_64 `claude-desktop.AppImage`，用于 Claude 桌面应用。账号、订阅和功能权限继续遵循软件官方规则。

## 上游来源与技术栈

- 软件来源：[Anthropic 官方下载](https://claude.com/download)、[官方 Linux 说明](https://code.claude.com/docs/en/desktop-linux)。
- 安装及 DEB 来源元数据：[AUR claude-desktop](https://aur.archlinux.org/packages/claude-desktop)。构建时从当前 `.SRCINFO` 获取架构专用 HTTPS DEB 和 SHA-256，不固定应用版本。
- AUR 更新可能晚于官方 stable 仓库。
- Linux 版当前属于上游 beta 支持范围，软件包使用官方 stable 发布通道。
- 技术栈：Electron / Chromium、官方 `resources/app.asar`、Node 原生模块及随包资源。
- 目标架构：Linux x86_64；实际构建由仓库现有 Arch Linux 环境完成。
- pkgforge 参考：[Claude-Desktop-AppImage](https://github.com/pkgforge-dev/Claude-Desktop-AppImage)。本次已核实其专属处理，但用户明确要求暂不加入；原文、用途与状态见 [差异记录](docs/pkgforge-differences.md)。

## 打包流程

脚本为 `build_claude-desktop.sh`，严格采用 [Electron 直接下载基础模板](../anylinux_projects.md#直接下载安装包的标准模板) 的 69 行结构、通用注释及空行；只替换允许变化的应用参数。

1. 先通过公共入口安装统一基础包，再安装 `claude-desktop fcitx5-gtk dpkg`。原脚本列出的 23 个基础包均已由 `--base` 覆盖，应用依赖仍由 AUR 包及明确追加项准备。
2. 清理本应用的 AppDir、dist、旧 DEB 和解包目录。公共 `common/aur/download_deb_source.sh` 独立解析当前 AUR 来源并下载，通过 SHA-256 校验后写入 `claude-desktop.deb`；不从系统程序目录复制最终程序。
3. 通过公共解包入口提取 DEB，把 `claude-desktop-unpacked/usr/lib/claude-desktop/` 整个程序目录原样放入 `AppDir/bin`。系统安装结果仅用于依赖、图标、desktop 及既定版本来源。
4. 设置模板规定的打包元数据，对完整程序目录执行 `quick-sharun AppDir/bin/*`。不再单独部署 ELF 后补资源或手工建立资源链接。
5. 按模板在第一次 quick-sharun 后生成包内 `zh_CN.UTF-8`，通过 `.env` 使用包内 locale。GTK3 输入模块由 quick-sharun 从已安装依赖收集。
6. 生成最终 AppImage，成功后单行调用公共保存入口，写入 `dist/version.txt`。

| 配置 | 当前值 |
| --- | --- |
| AUR 软件包 | `claude-desktop` |
| DEB 下载参数 | `claude-desktop x86_64 claude-desktop.deb` |
| DEB 程序目录 | `usr/lib/claude-desktop/` |
| 应用名与主程序 | `APPNAME=Claude`、`MAIN_BIN=claude-desktop` |
| StartupWMClass | `com.anthropic.Claude` |
| 图标 | `/usr/share/icons/hicolor/256x256/apps/claude-desktop.png` |
| 桌面入口 | `/usr/share/applications/com.anthropic.Claude.desktop` |
| 最终资产 | `dist/claude-desktop.AppImage` |

上述主程序、图标、desktop 和 StartupWMClass 已依据本次读取的 AUR 来源及下载的官方 DEB 确认，具体依据见 [固定配置说明](docs/hardcoded.md)。

## 版本元数据

在模板原有位置，通过公共入口读取已安装的 AUR 包版本，去掉 epoch 和 Arch pkgrel：

```bash
# 读取本次打包使用的版本。
VERSION="$("$SCRIPT_DIR/../common/build/read_app_version.sh" pacman claude-desktop)"
```

最终 AppImage 生成成功后，按单行公共调用保存同一个版本：

```bash
# 打包成功后用公共脚本记下版本。
"$SCRIPT_DIR/../common/build/save_appimage_version.sh" dist/claude-desktop.AppImage "$VERSION" dist/version.txt
```

下载 helper 只负责取得并校验 DEB，不写版本文件；版本来源继续由应用脚本的公共版本调用决定。

## 工作流与更新

- 正式入口：`.github/workflows/build.yml` 的标准 Arch matrix，复用 `.github/actions/build-anylinux`。
- 清单 key 为 `claude_desktop`，版本清单 key 为 `claude-desktop`，发布资产名为 `claude-desktop.AppImage`。
- 完成自身构建与发布后，当前 Job 立即更新自己的 `software_versions.json` 条目。
- 本次不修改 workflow、清单、发布机制或其他应用。正常 push 按现有路径选择构建，不添加 CI skip 标记。
- 本构建脚本不主动配置 pkgforge 的 self-updater；更新当前 AppImage 使用本仓库后续发布的产物。

## 运行与兼容说明

在 Linux 终端中，进入下载文件所在目录后执行：

```bash
# 为下载的 AppImage 添加执行权限。
chmod +x ./claude-desktop.AppImage

# 以普通用户启动 Claude Desktop。
./claude-desktop.AppImage
```

- 官方 Linux 支持范围为 Ubuntu / Debian；AppImage 的其他目标环境兼容性需以真实运行反馈为准。
- 当前应用脚本完整复制 DEB 内程序目录，包括 `chrome-sandbox`，不手工追加禁用沙盒参数，也不创建自定义 AppRun。最终依赖部署和启动入口由 quick-sharun / sharun 负责。
- 图形会话、输入法守护进程、桌面门户和凭据服务仍由目标 Linux 会话提供；脚本不在用户系统安装或启动这些服务。
- 官方 desktop 的协议声明及 Desktop Actions 保留，由 quick-sharun 处理桌面集成；脚本不手工改写这些条目。
- AUR 应用包在 CI 系统安装时可能按其依赖关系带入 QEMU、固件等组件；这与是否将这些组件主动部署进 AppImage 是两回事。本次没有加入 pkgforge 的 QEMU / 固件复制、NSPR hook 或三条 asar 修改。
- Cowork 需要宿主提供 QEMU、UEFI 固件、KVM，以及当前用户对 `/dev/kvm` 和 `/dev/vhost-vsock` 的访问权限。构建容器安装这些依赖不等于目标主机已经具备相应组件或权限；本 AppImage 不自动安装宿主依赖、加载内核模块或更改用户组。
- 当前基础方案的构建或启动不能代替登录、中文输入、Claude Code 和 Cowork 的真实功能验证。

## 配置说明文档

- [固定配置说明](docs/hardcoded.md)：记录参数、路径、文件名的来源及已有故障依据。
- [模板参数与差异](docs/template-deviations.md)：记录本次实际采用的模板参数及未启用处理的入口。
- [暂不采用的 pkgforge 专属处理](docs/pkgforge-differences.md)：保存官方源码快照、作用、未采用决定及后续重新核实要求。

## 变更记录

### 2026-09-05：首次接入

- 原因：仓库尚未包含 Claude Desktop 的正式 AppImage 构建入口。
- 文件：新增 `claude-desktop/build_claude-desktop.sh`、本 README，并接入 `.github/workflows/build.yml`。
- 内容：参考现有 Electron 项目及仓库最小打包规范，从 AUR 对应的官方包构建，补齐标准 ELF 入口不会自动携带的应用资源，复用统一发布流程。
- 已确认依据：AUR PKGBUILD、官方 DEB 的包元数据与目录布局、quick-sharun 依赖和资源处理代码；运行结果以对应正式 Actions 日志及后续真实使用反馈为准。
- 本次属于首次接入，不记为已有运行故障修复，也不添加测试代码、测试 Job 或独立测试 workflow。

### 2026-09-05：补齐 Fcitx5 GTK3 输入模块

- 现象：Linux 实机反馈应用已经正常启动，但无法输入中文。
- 根因：原构建仅安装应用声明的依赖，没有安装 `fcitx5-gtk`；首次正式构建日志中只部署了 GTK3 自带输入模块，没有 `im-fcitx5.so`。自包含的 GTK3 运行环境因此缺少 Fcitx5 前端。
- 文件：`claude-desktop/build_claude-desktop.sh`、本 README。
- 修复：在应用安装后增加独立的 `fcitx5-gtk` 安装命令，由既有 GTK3 部署流程收集输入法模块、客户端运行库和模块缓存；原有打包命令、资源布局、沙箱和启动逻辑保持不变。
- 已确认依据：[首次正式构建成功记录](https://github.com/newyorkthink/linux-packaging/actions/runs/33958367807)、[Arch 官方包文件列表](https://archlinux.org/packages/extra/x86_64/fcitx5-gtk/files/)及 [quick-sharun 的 GTK 部署实现](https://github.com/pkgforge-dev/Anylinux-AppImages/blob/main/useful-tools/quick-sharun.sh)。新增依赖用于补齐已定位的打包缺项，中文输入的实机效果仍需新产物运行反馈确认。

### 2026-09-15：适配 AUR 启动入口改为 launcher

- 现象：正式 Actions 构建在安装 `claude-desktop 1.52386.6-2` 和 `fcitx5-gtk` 后立即报“Claude Desktop 的上游安装布局已改变”，未进入 quick-sharun 打包阶段。
- 根因：AUR `claude-desktop` 的 `pkgrel=2` 将 `/usr/bin/claude-desktop` 从指向官方 Electron ELF 的软链接替换为 shell launcher；原脚本继续对该路径执行 `readlink -f`，因此误把 `/usr/bin` 判断为应用根目录。官方 ELF 与 `resources/app.asar` 仍位于 `/usr/lib/claude-desktop/`。
- 文件：`claude-desktop/build_claude-desktop.sh`、本 README。
- 修复：应用根目录直接按官方包实际 payload 使用 `/usr/lib/claude-desktop`，新增 `APP_EXEC` 指向真实 Electron ELF，并将既有 quick-sharun 输入从 AUR launcher 改为该 ELF；资源复制、Fcitx5 GTK3、沙箱和 workflow 保持不变。
- 已确认依据：[失败构建记录](https://github.com/newyorkthink/linux-packaging/actions/runs/34930833025/job/104268847458) 与 AUR 同步仓库提交 `01a8c397953735dd6543effd0bb002b60c30d6cf`；该上游提交明确新增 launcher，同时官方包 payload 继续位于 `/usr/lib/claude-desktop`。本次修改已完成静态核对，新的正式构建结果以后续 Actions 为准。

### 2026-10-29：按基础模板改为系统安装与独立下载两个阶段

- 原因：用户明确要求应用脚本逐字逐行套用基础模板，先安装应用及依赖，再独立下载现成 DEB；本次明确暂不加入 pkgforge-dev 的专属处理。
- 文件：`build_claude-desktop.sh`、本 README、`docs/hardcoded.md`、`docs/template-deviations.md`、`docs/pkgforge-differences.md`，以及新公共下载入口和相应通用说明。
- 调整：使用已批准的 69 行脚本，公共 AUR 入口解析当前 DEB 来源和 SHA-256，公共解包入口提取后把完整程序目录放入 `AppDir/bin`；统一读取和保存版本，补入模板规定的中文 locale。
- 被替代的旧实现：单独部署 Electron ELF 后再复制资源、给 `shared/bin` 建立资源链接，以及旧脚本额外的 `NO_STRIP`、`STRACE_MODE` 和单独版权复制命令。当前仅保留基础模板，不再把这些旧代码描述为现有流程；上面的真实故障和修复历史完整保留。
- 官方差异：仅在 [pkgforge 差异记录](docs/pkgforge-differences.md) 保存已读源码快照、作用和本次未采用的决定，不把其 hook 或补丁接入构建。后续拟加入时必须核实官方当前是否仍保留且适用。
- 验证边界：提交前检查模板的 69 行、通用注释和空行位置、公共入口的调用与失败处理、文档链接和完整差异。此记录不代表新 AppImage 的登录、中文输入、Claude Code 或 Cowork 已经实机验收。
