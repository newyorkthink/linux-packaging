# Free Download Manager AppImage

用于将 Free Download Manager Linux x86_64 版本重新封装为 AppImage。

## 用途与产物

- 打包对象：Free Download Manager（FDM），桌面下载管理器。
- 最终产物：`freedownloadmanager.AppImage`，由统一 `.github/workflows/build.yml` 中的 `build_freedownloadmanager` Job 构建并发布到仓库 `latest` Release。
- 上游来源：构建脚本通过 AUR `freedownloadmanager` 安装 FDM Linux 包，并以 `/opt/freedownloadmanager/` 中的主程序、FDM 自身运行库和翻译资源作为打包来源。
- 本目录只负责 AppImage 重打包与运行依赖部署，不修改 FDM 的业务功能。

## 技术栈

当前脚本按 Linux 原生 Qt6 桌面应用路线处理 FDM，主程序入口为 `/opt/freedownloadmanager/fdm`。

打包侧显式部署 Qt6、GTK3、GStreamer / FFmpeg、libtorrent、NSS、X11、OpenGL / Vulkan、PulseAudio / PipeWire、字体与图像渲染等运行时组件，并使用 `xdg-open` 处理宿主桌面打开操作。中文输入兼容仅显式带入 Qt6 的 IBus 与 Fcitx5 platform input context 模块。

FDM 的 `libdownloads*.so*` 下载模块属于按需加载运行库，不保证在程序启动阶段被 quick-sharun 的运行跟踪发现，因此构建脚本会从上游私有 `lib/` 目录显式收集这些模块及其 FDM 支撑库。

当前仅构建 x86_64 AppImage。

## 打包方式

- 路线：PkgForge AnyLinux 构建环境 + quick-sharun，保持仓库统一的 AnyLinux AppImage 打包方式。
- 程序来源：通过 `yay -S --noconfirm --mflags "--skipinteg" freedownloadmanager` 安装当前 AUR FDM 包；脚本不另外下载或修改 FDM 主程序。
- 程序布局：quick-sharun 接收文件参数，不会自动展开 `/opt/freedownloadmanager/` 目录。构建脚本因此显式传入主程序，以及 `libdownloads*.so*`、`liblogger.so*`、`libvmsclshared.so*`、`libquazip.so*` 等 FDM 自身运行库；这些库仍由 quick-sharun 收集依赖，不手工复制二进制或共享库。部署阶段的动态链接解析以 `/usr/lib` 为优先，再回退到 `/opt/freedownloadmanager/lib`，使 FDM 私有 SONAME 能被解析，同时继续沿用系统 Qt / OpenSSL。quick-sharun 会把标准启动入口放到 `AppDir/bin/fdm`、FDM 私有库放到 `AppDir/lib/freedownloadmanager/lib/`；FDM 运行时以 `AppDir/bin/fdm` 作为自身程序路径并从旁边的 `lib/` 搜索下载模块，因此构建脚本建立 `AppDir/bin/lib -> ../lib/freedownloadmanager/lib` 相对链接。上游 `translations/` 原样复制到 `AppDir/shared/bin/translations/`，并从 `AppDir/bin/translations` 建立相对符号链接，供标准入口与真实程序共用。
- 依赖部署：显式加入 `xdg-open`、NSS / PKCS#11 相关运行库，并启用 GTK、Qt、OpenGL、Vulkan、PipeWire 和 locale 部署；输入法仅额外安装 `fcitx5-qt`，并显式打包 Qt6 的 IBus / Fcitx5 platform input context 模块。
- desktop / 图标：使用上游 `/usr/share/applications/freedownloadmanager.desktop` 与 `/opt/freedownloadmanager/icon.png`。
- 中文环境：在 AppImage 内生成 `zh_CN.UTF-8` locale，并通过 `.env` 设置 `LANG=zh_CN.UTF-8`、`LANGUAGE=zh_CN:zh`、`LC_MESSAGES=zh_CN.UTF-8`；不修改宿主机全局 locale。
- 输入法：仅打包 Qt6 IBus / Fcitx5 platform input context，不强制设置 `QT_IM_MODULE`，由宿主已经运行的输入法会话选择实际输入法。
- 网络状态：显式打包与现有系统 Qt6 部署配套的 `networkinformation/libqnetworkmanager.so` 与 `libqglib.so` 及其依赖，供 FDM 的 `QNetworkInformation` 查询网络可达状态；不启动或修改宿主网络服务。
- AppImage 生成：由 `quick-sharun --make-appimage` 生成 `dist/freedownloadmanager.AppImage`。
- workflow：通过 `.github/workflows/build.yml` 的独立 `build_freedownloadmanager` Job 构建，沿用仓库统一 AnyLinux 构建与 `latest` Release 发布流程。

## 维护原则

本项目保持 AnyLinux / quick-sharun 的标准重打包路线，不在 AppImage 中额外内嵌难以追踪的自定义运行逻辑。

- 不新增、替换或注入自定义 `AppRun`。
- 不增加额外 wrapper、启动脚本或隐藏的运行时分支。
- 不加入 `--fdm-native-host` 等本仓库自定义入口。
- 不加入自动浏览器 Native Messaging 注册逻辑。
- 此限制针对浏览器自动注册与额外启动代码，不禁止打包 FDM 显示、联网、下载协议、中文输入所必需的 Qt 插件及运行库。
- 不自动创建或修改宿主机 `~/.config/*/NativeMessagingHosts/`。
- 不自动创建 `~/.local/bin/fdm-wenativehost` 或其他宿主机 helper。
- 不在启动 AppImage 时自动修改浏览器、用户配置目录或其他宿主系统状态。
- 上游 `/opt/freedownloadmanager/` 本身已有的文件只作为上游程序与资源来源；如果其中包含 `wenativehost` 等组件，不额外为其增加注册、包装或宿主机写入逻辑。
- FDM 自身运行库必须通过 quick-sharun 的文件参数部署；不要再次把 `/opt/freedownloadmanager/` 目录当成能够自动展开的输入，也不要手工复制二进制或共享库。

保持这些边界可以让产物行为直接对应当前构建脚本，避免额外内嵌代码在后续维护中被遗忘、误判来源或产生非预期修改。

## 运行与兼容说明

- 仅支持 x86_64。
- AppImage 直接运行 FDM 主程序，不要求额外后台服务、helper 或初始化步骤。
- AppImage 自带 `zh_CN.UTF-8` locale，并优先使用简体中文消息环境；FDM 实际可显示的界面翻译仍以其上游自带语言资源为准。
- IBus / Fcitx5 输入支持只打包 Qt6 platform input context 及依赖，不启动输入法守护进程，也不覆盖宿主输入法环境变量。
- HTTP / HTTPS、BitTorrent、批量下载等 FDM 按需下载模块通过 `libdownloads*.so*` 统一显式部署，并通过 `AppDir/bin/lib` 相对链接恢复 FDM 实际运行入口所使用的模块发现路径。
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

### 2026-09-09：补齐简体中文环境与 IBus / Fcitx5 输入支持

- 目标：在保持 AnyLinux / quick-sharun 标准重打包路线不变的前提下，补齐 AppImage 的简体中文 locale 与中文输入法客户端模块。
- 修改文件：`freedownloadmanager/build_freedownloadmanager.sh`、`freedownloadmanager/README.md`。
- 修改内容：启用 `DEPLOY_LOCALE=1`，生成 AppImage 自带的 `zh_CN.UTF-8` locale；加入 `fcitx5-gtk`、`fcitx5-qt`，并将 IBus / Fcitx5 的 GTK3、Qt6 platform input context 模块作为 quick-sharun 输入；`.env` 仅设置中文 locale，不强制指定输入法类型。
- 已知结果：本次不加入自定义 `AppRun`、wrapper、Native Messaging 注册或其他宿主机写入逻辑；最终中文界面与输入效果以本次正式 GitHub Actions 构建产物的实际运行结果为准。

### 2026-09-09：移除多余 GTK3 输入法模块

- 原因：FDM 当前 Linux 主界面走 Qt6 输入栈，GTK3 的 `im-ibus.so` / `im-fcitx5.so` 不属于其实际输入法入口，继续显式打包只会增加无关组件。
- 修改文件：`freedownloadmanager/build_freedownloadmanager.sh`、`freedownloadmanager/README.md`。
- 修改内容：删除 `fcitx5-gtk` 依赖，并移除 GTK3 `im-ibus.so` / `im-fcitx5.so` quick-sharun 输入；保留 Qt6 的 IBus / Fcitx5 platform input context、中文 locale 和现有 AnyLinux / quick-sharun 路线。
- 已知结果：本次仅收窄输入法打包范围，不加入自定义 `AppRun`、Native Messaging 或其他额外运行逻辑。

### 2026-09-09：补齐 FDM 翻译资源与网络状态后端

- 故障：发布产物不能显示 FDM 中文界面，并出现 `No Internet connection` 提示。
- 根因与证据：对比旧版与故障产物，旧版包含 72 个 `fdm_*.qm`，故障产物为 0；quick-sharun 的目录参数不会自动展开，未复制 FDM 的非 ELF 翻译资源，Qt 通用翻译与中文 locale 不能替代它们。故障产物也缺少 `networkinformation` 后端，而 FDM 二进制包含 `QNetworkInformation::loadBackendByFeatures(Reachability)` 调用。
- 修改文件：`freedownloadmanager/build_freedownloadmanager.sh`、`freedownloadmanager/README.md`。
- 修复内容：原样保留上游完整翻译目录，并用相对链接适配标准 sharun 入口；显式带入现有 Qt6 对应的 NetworkManager / GLib 网络状态插件及依赖。保留现有 Qt 部署，不因产物同时包含两个 Qt 版本就未经验证整体替换运行时。
- 维护边界：不新增或替换自定义 `AppRun`、wrapper、浏览器自动注册、宿主 helper 或测试代码；不修改宿主网络、代理、DNS 或输入法设置。
- 已知结果：实际运行已确认中文界面、中文输入和网络状态显示恢复正常。

### 2026-09-09：补齐 FDM 按需下载模块

- 故障：中文、输入法和网络状态恢复后，QQ 官方 HTTPS 直链和 GitHub Release HTTPS 直链仍被 FDM 判定为“`不支持的链接`”。
- 根因：quick-sharun 接收文件参数，不会自动展开 `/opt/freedownloadmanager/` 目录；原脚本把该目录作为参数并不能把整个私有运行库目录带入。FDM 的 `libdownloadswww.so*`、`libdownloadsbt.so*`、`libdownloadsbatch.so*` 等下载模块又是按需加载，正常启动阶段不会全部触发，因此未被自动跟踪收集。
- 核对范围：旧版工作产物的 FDM 私有 `lib/` 中，除 Qt6 库外，应用运行库由 `libdownloads*.so*`、`liblogger.so*`、`libvmsclshared.so*`、`libquazip.so*` 组成；本次统一显式收集这些系列，而不是只单独补 `libdownloadswww.so`。
- 修改文件：`freedownloadmanager/build_freedownloadmanager.sh`、`freedownloadmanager/README.md`。
- 修复内容：移除无效的目录参数，构建时动态枚举上述 FDM 私有运行库并统一作为 quick-sharun 文件输入，由 quick-sharun 继续负责依赖解析和部署；中文翻译、Qt6 输入模块、网络状态后端及 locale 修复保持不变。
- 维护边界：不手工复制二进制 / 共享库，不加入自定义 `AppRun`、Native Messaging、wrapper 或宿主机配置写入。
- 已知结果：构建脚本层面已消除按需下载模块的漏包来源；最终 HTTPS / BitTorrent / 批量下载行为仍以本次 GitHub Actions 新产物实际运行验证为准。

### 2026-09-09：修正 FDM 私有库解析路径

- 故障：Actions 在处理 `libdownloadsbatch.so` 时报告 `libvmsclshared.so.6 => not found`，构建直接退出。
- 根因：`libvmsclshared.so.6` 实际存在于 `/opt/freedownloadmanager/lib/`，但 quick-sharun 调用 `ldd` 时默认动态链接搜索路径看不到同目录的 FDM 私有 SONAME；同时上一版脚本误写了不存在的 `libquazip1-qt6.so*` 名称，当前上游实际为 `libquazip.so*`。
- 修复内容：将 FDM 私有库目录纳入部署阶段动态链接搜索路径，并保持 `/usr/lib` 优先，避免无意切换到 FDM 自带的另一套 Qt / OpenSSL；同时修正 `libquazip.so*` 匹配。
- 完整性检查：在 quick-sharun 前对主程序和全部显式收集的 FDM 私有运行库执行 `ldd` 预检，只要仍存在 `=> not found` 就立即失败并打印完整解析结果，不再生成已知残缺的 AppImage。
- 维护边界：继续使用标准 AnyLinux / quick-sharun；不新增自定义 `AppRun`、Native Messaging、wrapper、浏览器注册或宿主机配置写入。

### 2026-09-09：恢复 FDM 下载模块的运行时相对目录

- 故障：新产物已经包含 `libdownloadswww.so*` 等 FDM 下载模块，但普通 HTTPS 直链仍被判定为“`不支持的链接`”。
- 根因与证据：解包实际发布产物后确认，真实 FDM 主程序位于 `AppDir/shared/bin/fdm`，而下载模块被 quick-sharun 部署到 `AppDir/lib/freedownloadmanager/lib/`。FDM 主程序自身 RUNPATH 包含 `$ORIGIN/lib`，并使用应用目录定位按需模块；旧版正常产物则保持 `fdm` 与 `lib/` 直接相邻。因此“模块已经打包”并不等于“FDM 能按原路径发现模块”。
- 修改文件：`freedownloadmanager/build_freedownloadmanager.sh`、`freedownloadmanager/README.md`。
- 修复内容：在真实主程序目录建立 `AppDir/shared/bin/lib -> ../../lib/freedownloadmanager/lib` 相对符号链接，恢复上游 `fdm + lib/` 的目录关系，同时继续由 quick-sharun 管理实际库文件与依赖。
- 维护边界：不复制私有库，不新增或替换自定义 `AppRun`，不加入 Native Messaging、wrapper、浏览器注册或宿主机配置写入。
- 对应提交：`f399fcc28ba2f41c836df9e22a4faba60940d60c`。
- 已知结果：修复已进入正式构建流程；最终 HTTPS、BitTorrent 与批量下载行为以新产物实际运行结果为准。

### 2026-09-09：修正 FDM 实际启动入口的模块搜索路径

- 故障：上一版已建立 `AppDir/shared/bin/lib`，但真实运行时普通 HTTPS 直链仍被判定为“`不支持的链接`”。
- 根因与证据：解包并运行实际发布产物后，FDM 自身日志明确显示命令行入口是 `AppDir/bin/fdm`，并固定把 `AppDir/bin/lib` 作为内置下载模块搜索目录；上一版链接建在 `AppDir/shared/bin/lib`，因此搜索目录仍为空，模块没有被注册。
- 修改文件：`freedownloadmanager/build_freedownloadmanager.sh`、`freedownloadmanager/README.md`。
- 修复内容：将模块链接改为 `AppDir/bin/lib -> ../lib/freedownloadmanager/lib`。在仓库外对同一发布产物按该目录关系运行后，FDM 日志已确认 `libdownloadswww.so` 等模块均为 `YES`，并显示 `loaded modules pack (): count: 7`；传入 HTTPS 直链后已经进入实际网络下载阶段，而不再停在“链接不支持”的判断阶段。
- 维护边界：继续使用标准 AnyLinux / quick-sharun；不新增自定义 `AppRun`、Native Messaging、wrapper、浏览器注册、宿主机写入或测试代码。
- 对应代码提交：`3a95799ad40a1064be8fea499b7f98c41a16eec0`。
