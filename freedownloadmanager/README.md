# Free Download Manager AppImage

用于将 Free Download Manager Linux x86_64 版本重新封装为 AppImage。

## 用途与产物

- 打包对象：Free Download Manager（FDM），桌面下载管理器。
- 最终产物：`freedownloadmanager.AppImage`，由统一 `.github/workflows/build.yml` 中的 `build_freedownloadmanager` Job 构建并发布到仓库 `latest` Release。
- 上游来源：构建脚本通过 AUR `freedownloadmanager` 安装 FDM Linux 包，并保留其 `/opt/freedownloadmanager/` 程序目录作为主要打包输入。
- 本目录只负责 AppImage 重打包与运行依赖部署，不修改 FDM 的业务功能。

## 技术栈

当前脚本按 Linux 原生桌面应用路线处理 FDM，主程序入口为 `/opt/freedownloadmanager/fdm`。

打包侧显式部署 Qt6、GTK3、GStreamer / FFmpeg、libtorrent、NSS、X11、OpenGL / Vulkan、PulseAudio / PipeWire、字体与图像渲染等运行时组件，并使用 `xdg-open` 处理宿主桌面打开操作。

当前仅构建 x86_64 AppImage。

## 打包方式

- 路线：PkgForge AnyLinux 构建环境 + quick-sharun，保持仓库统一的 AnyLinux AppImage 打包方式。
- 程序来源：通过 `yay -S --noconfirm --mflags "--skipinteg" freedownloadmanager` 安装当前 AUR FDM 包；脚本不另外下载或修改 FDM 主程序。
- 程序布局：以 `/opt/freedownloadmanager/fdm` 和完整 `/opt/freedownloadmanager/` 作为 quick-sharun 输入，保留上游程序目录及资源。
- 依赖部署：显式加入 `xdg-open`、NSS / PKCS#11 相关运行库，并启用 GTK、Qt、OpenGL、Vulkan 和 PipeWire 部署。
- desktop / 图标：使用上游 `/usr/share/applications/freedownloadmanager.desktop` 与 `/opt/freedownloadmanager/icon.png`。
- AppImage 生成：由 `quick-sharun --make-appimage` 生成 `dist/freedownloadmanager.AppImage`。
- workflow：通过 `.github/workflows/build.yml` 的独立 `build_freedownloadmanager` Job 构建，沿用仓库统一 AnyLinux 构建与 `latest` Release 发布流程。

## 维护原则

本项目保持 AnyLinux / quick-sharun 的标准重打包路线，不在 AppImage 中额外内嵌难以追踪的自定义运行逻辑。

- 不新增、替换或注入自定义 `AppRun`。
- 不增加额外 wrapper、启动脚本或隐藏的运行时分支。
- 不加入 `--fdm-native-host` 等本仓库自定义入口。
- 不加入自动浏览器 Native Messaging 注册逻辑。
- 不自动创建或修改宿主机 `~/.config/*/NativeMessagingHosts/`。
- 不自动创建 `~/.local/bin/fdm-wenativehost` 或其他宿主机 helper。
- 不在启动 AppImage 时自动修改浏览器、用户配置目录或其他宿主系统状态。
- 上游 `/opt/freedownloadmanager/` 本身已有的文件按原样打包；如果其中包含 `wenativehost` 等上游组件，只视为上游文件，不额外为其增加注册、包装或宿主机写入逻辑。

保持这些边界可以让产物行为直接对应当前构建脚本，避免额外内嵌代码在后续维护中被遗忘、误判来源或产生非预期修改。

## 运行与兼容说明

- 仅支持 x86_64。
- AppImage 直接运行 FDM 主程序，不要求额外后台服务、helper 或初始化步骤。
- 当前构建脚本不会主动向浏览器 Native Messaging 目录写入配置，也不会创建宿主机 `fdm-wenativehost` 包装脚本。
- 将上游 `wenativehost` 等文件包含在 `/opt/freedownloadmanager/` 内，不等同于自动注册浏览器集成；只有额外的注册 / 启动逻辑才会产生宿主机配置写入，本目录明确不加入此类逻辑。

### 直接运行

在 Linux 终端中进入 AppImage 所在目录后执行：

```bash
# 启动 Free Download Manager。
./freedownloadmanager.AppImage
```

## 变更记录

### 2026-08-20：迁入 Free Download Manager AppImage 构建

- 目标：将 Free Download Manager 接入仓库统一 AppImage 构建流程。
- 修改文件：`freedownloadmanager/build_freedownloadmanager.sh` 及对应统一 workflow 接入。
- 实现：通过 AUR 安装 FDM Linux 包，以 `/opt/freedownloadmanager/fdm` 和完整 `/opt/freedownloadmanager/` 为主要输入，使用 AnyLinux / quick-sharun 收集依赖并生成 `freedownloadmanager.AppImage`。
- 已知结果：当前仓库历史中该构建脚本由 commit `fe7f34cb674d58e18fa673918c92ce7d468152ef` 迁入；本条只记录可从现有脚本和提交历史确认的构建路线，不补写无法确认的旧版 AppImage 内嵌逻辑来源。

### 2026-09-09：补齐 README 与内嵌逻辑维护边界

- 目标：补齐应用目录 README，并明确后续继续保持 AnyLinux / quick-sharun 标准重打包方式。
- 修改文件：`freedownloadmanager/README.md`。
- 内容：明确禁止在本项目中额外注入自定义 `AppRun`、wrapper、浏览器 Native Messaging 自动注册、宿主机配置写入或 `--fdm-native-host` 等额外入口；上游 `/opt/freedownloadmanager/` 文件仍按原样打包。
- 已知结果：本次仅补充文档维护规则，不修改 `build_freedownloadmanager.sh`，不改变现有 AppImage 构建与运行行为。
