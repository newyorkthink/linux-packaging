# Claude Desktop AppImage

本目录将 Anthropic 官方 Claude Desktop Linux 包重新封装为 x86_64 `claude-desktop.AppImage`，用于 Claude 桌面聊天、Claude Code 和上游提供的 Cowork 入口。账号、订阅和功能权限继续遵循上游规则。

## 上游来源与技术栈

- 应用来源：[Anthropic 官方下载](https://claude.com/download)。
- 安装入口：[AUR claude-desktop](https://aur.archlinux.org/packages/claude-desktop)，其 PKGBUILD 从 `downloads.claude.ai` 下载官方 DEB 并校验 SHA-256。
- 技术栈：Electron / Chromium、官方 `resources/app.asar`、Node 原生模块，以及 Cowork Linux helper 等随包组件。
- 目标架构：x86_64；构建环境使用仓库统一的 Arch Linux 容器。
- 应用版本由每次构建时的 AUR 元数据决定，构建后通过 `pacman -Q claude-desktop` 读取，包含 Arch 包修订号；脚本不固定应用版本。AUR 更新可能晚于官方 stable 仓库。
- Linux 版当前属于上游 beta 支持范围，软件包使用官方 stable 发布通道。

## 打包流程

脚本：`build_claude-desktop.sh`。

1. 使用仓库规定的最小基础工具列表，单独安装 `claude-desktop`，让包管理器根据 AUR 的真实依赖关系准备运行库。
2. 从安装结果读取版本、desktop 文件和 `/usr/bin/claude-desktop` 的实际目标；使用官方图标及桌面菜单，不生成替代图标。
3. 直接执行 `quick-sharun /usr/bin/claude-desktop`，由 quick-sharun / sharun 收集依赖并生成 `AppRun`、`AppRun.sh` 和主程序启动入口。
4. 标准入口是指向 `/usr/lib/claude-desktop/claude-desktop` 的 ELF 软链接。依赖收集完成后，补入与主程序相邻的官方 `resources`、`locales`、PAK、ICU、V8、共享库及其他应用资源，保持内部相对布局；不覆盖已经生成的主程序入口。
5. 在真实 ELF 所在的 `shared/bin` 中为尚不存在的资源入口建立相对链接，兼容应用从启动入口和实际可执行文件目录定位资源的方式。
6. 保留上游 copyright；使用 `NO_STRIP=1` 保留 Electron 二进制，使用 `STRACE_MODE=0` 禁止依赖收集阶段启动应用。
7. 执行 `quick-sharun --make-appimage`，生成 `dist/claude-desktop.AppImage`；公共 action 将该文件发布到 `latest` Release。

针对已经反馈的 Fcitx 中文输入失效，安装应用后单独补装 `fcitx5-gtk`。保留原有 quick-sharun 命令，由其 GTK3 部署逻辑自动收集 `im-fcitx5.so`、`libFcitx5GClient.so` 的实际依赖及 `immodules.cache`，并处理模块缓存中的路径。

资源复制发生在依赖部署之后，官方 `app.asar` 保持原样。本目录没有自行添加授权补丁、后台服务或启动时安装依赖的逻辑。

## 工作流与更新

- 正式入口：`.github/workflows/build.yml` 中独立的 `Build Claude Desktop` Job。
- 复用 `.github/actions/build-anylinux` 和既有 Arch 构建环境。
- 支持本目录变更触发、每日定时构建，以及 `workflow_dispatch` 选择 `claude-desktop/build_claude-desktop.sh`。
- 发布资产名固定为 `claude-desktop.AppImage`，只更新本应用对应资产。
- AppImage 的版本更新通过下载新的 Release 产物完成；上游 Linux 应用不提供应用内自动更新。

## 运行与兼容说明

在 Linux 终端中，进入下载文件所在目录后执行：

```bash
# 为下载的 AppImage 添加执行权限。
chmod +x ./claude-desktop.AppImage

# 以普通用户启动 Claude Desktop。
./claude-desktop.AppImage
```

- 官方 Linux 支持范围为 Ubuntu / Debian；AppImage 的其他目标环境兼容性需以真实运行反馈为准。
- 保留 Chromium 用户命名空间沙箱，不携带仅适用于系统安装的 setuid `chrome-sandbox`，也不添加 `--no-sandbox`。宿主必须允许普通用户使用相应用户命名空间。
- 登录、浏览器回调、桌面门户和凭据保存依赖宿主桌面会话及其正常服务。官方 desktop 保留 `claude://` 协议声明；本脚本不在启动时自动注册协议或修改宿主配置。
- Fcitx 中文输入使用包内 GTK3 前端连接宿主已经运行的 Fcitx5 会话，继承宿主输入法配置；本 AppImage 不启动输入法守护进程、不覆盖输入法环境变量，也不修改系统输入法设置。
- Cowork 需要宿主提供 QEMU、UEFI 固件、KVM，以及当前用户对 `/dev/kvm` 和 `/dev/vhost-vsock` 的访问权限。构建容器安装这些依赖不等于目标主机已经具备相应组件或权限；本 AppImage 不自动安装宿主依赖、加载内核模块或更改用户组。
- Cowork 的虚拟化要求和当前 Linux 功能范围以 [Anthropic 官方说明](https://code.claude.com/docs/en/desktop-linux) 为准；未经过真实登录及任务运行，不能把正式打包成功等同于全部功能已经验证。

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
