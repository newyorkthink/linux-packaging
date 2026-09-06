# Chromium AppImage

用于构建 Chromium 官方程序的 Linux x86_64 AppImage。

## 用途与产物

- 打包对象：Chromium（开源项目本体，非 Google Chrome）。
- 最终产物：`chromium.AppImage`，由 `build.yml` 中的 `build_chromium` Job 构建并发布到仓库 `latest` Release。
- 上游来源：Chromium 项目本身不提供官方通用 Linux 二进制发行版；使用 Arch `[extra]` 官方仓库的 `chromium` 包（该包直接基于 Google `chromium-browser-official` 官方源码构建）作为上游二进制来源。

## 技术栈

Chromium / Blink，GTK3 原生界面组件。依赖由 `pacman`/`yay` 按 `chromium` 包的真实依赖关系自动解析安装，未手工列运行库清单。

## 打包方式

- 路线：quick-sharun（Arch Linux 环境）。
- 版本：不锁定，每次构建安装仓库当前 `chromium`，通过 `chromium --version` 动态取实际版本号，写入 `~/version` 并追加到 desktop 文件的 `X-AppImage-Version`。
- desktop / 图标：直接复制官方包安装的 `/usr/share/applications/chromium.desktop` 与 hicolor/pixmaps 中的官方图标，不自制、不改品牌。
- 主程序与资源：Arch 的 `/usr/bin/chromium` 是启动器，真正的 Chromium 主程序及 `resources.pak`、`icudtl.dat`、`locales/`、`chrome-sandbox`、ANGLE / SwiftShader 运行文件都位于 `/usr/lib/chromium/`。构建时把该目录完整复制到 `AppDir/bin/`，再交给 quick-sharun 部署，避免只打包启动器而遗漏真正的浏览器程序和资源。
- Qt6 shim：Arch Chromium 包自带 `libqt6_shim.so`，同时把 `qt6-base` 声明为可选的 Qt 支持依赖。由于构建会把 `AppDir/bin/*` 整体交给 quick-sharun，脚本显式安装官方 Arch `qt6-base`，让该上游 shim 的 `libQt6Core.so.6`、`libQt6Gui.so.6`、`libQt6Widgets.so.6` 依赖可解析；quick-sharun 检测到 `libQt6Core` 后会自动启用 Qt6 部署。
- 动态依赖探测：显式设置 `STRACE_BINARY=chromium` 与 `STRACE_FLAGS='about:blank --no-sandbox'`，让 quick-sharun 在构建阶段针对真正的 Chromium 主二进制收集动态加载依赖。
- AppImage runtime：设置 `URUNTIME_PRELOAD=1`，沿用 PkgForge Chrome-AppImage 对 Chromium/Chrome 多进程程序的处理，让 uruntime 保持 AppImage 挂载点，避免运行期间挂载点被提前回收。
- 中文界面：quick-sharun 部署完成后向 `AppDir/.env` 写入 `LANGUAGE=zh-CN`。Chromium Linux 使用 `LANGUAGE` / `LC_*` / `LANG` 环境变量选择 UI locale，因此直接执行 AppImage 和 desktop 启动都会默认使用简体中文，同时不修改宿主机 locale。
- 中文输入法：额外装 `ibus`、`fcitx5-gtk`，把两者的 GTK3 immodule 一并打包，同时兼顾 IBus 与 Fcitx5。

## 运行与兼容说明

- 仅支持 x86_64。
- 未自定义 AppRun，未强制指定 Ozone 平台；X11/Wayland 行为保持 Chromium 上游默认逻辑。
- AppImage 默认把 Chromium 主界面设为简体中文；仅设置 AppImage 内的 `LANGUAGE=zh-CN`，不覆盖宿主机 `LANG`、`LC_ALL` 或其他程序的语言环境。
- sandbox 保持 Chromium 自身行为；不集成会通过 `pkexec` 持久修改宿主 `sysctl` 的 `fix-namespaces.hook`。目标系统若限制非特权 user namespace，应由宿主系统按其自身安全策略处理；`--no-sandbox` 仅作为明确的故障诊断参数，不作为默认运行方式。
- Fcitx5 中文输入已经在实际 AppImage 中确认可用；IBus 打包逻辑保留，但尚未单独进行实机验证。

## 修复记录

### 2026-09-06：修复 AppImage 启动立即退出

- 故障现象：已构建的 `chromium.AppImage` 在真实 Linux 环境中执行 `./chromium.AppImage --no-sandbox` 后立即退出，无法正常打开浏览器。
- 根因：原脚本对 `/usr/bin/chromium` 使用 `readlink -f` 并据此推导程序目录；但 Arch 的 `/usr/bin/chromium` 是启动器而非 Chromium 主 ELF，真正程序与资源位于 `/usr/lib/chromium/`。因此构建输入只包含启动器，没有完整带入真正的 Chromium 主程序、资源和 locales。
- 修改文件：`chromium/build_chromium.sh`、`chromium/README.md`。
- 修复内容：改为显式使用 `/usr/lib/chromium/`，完整复制到 `AppDir/bin/` 后交给 quick-sharun；同时指定 `STRACE_BINARY=chromium` 与 `STRACE_FLAGS='about:blank --no-sandbox'`，确保动态依赖探测针对真实主程序执行；保留原有 IBus / Fcitx5 GTK3 输入法模块打包逻辑。
- 已知结果：脚本已完成静态语法检查；尚未重新构建新的 AppImage，因此启动结果需要以下一次真实构建和实机运行反馈为准。

### 2026-09-06：补充 Chromium 多进程 AppImage 挂载保持

- 修改原因：横向核对 PkgForge `Chrome-AppImage` 后确认，其 quick-sharun 构建明确设置 `URUNTIME_PRELOAD=1`，用于要求 uruntime 持续保持 AppImage 挂载点；Chromium 与 Chrome 使用相同的多进程浏览器运行模型，应保留这一 runtime 处理。
- 修改文件：`chromium/build_chromium.sh`、`chromium/README.md`。
- 修改内容：仅新增 `URUNTIME_PRELOAD=1`；保留已经确认正确的 `./AppDir/bin/*` quick-sharun 输入和 `/usr/lib/chromium/` AppDir 布局，不复制 Chrome 专用的运行时下载逻辑、`ar` / `tar` / `xz` 依赖或测试步骤。
- 安全边界：未加入 PkgForge 的 `fix-namespaces.hook`。该 hook 会通过提权写入 `/etc/sysctl.d/20-fix-namespaces.conf` 并全局关闭 `kernel.apparmor_restrict_unprivileged_userns`，不符合本仓库最小宿主修改原则。
- 已知结果：修改后的构建脚本已完成 Bash 静态语法检查；尚未重新构建 AppImage，实际启动结果以后续真实构建与实机反馈为准。

### 2026-09-06：修复 libqt6_shim.so 缺少 Qt6 依赖导致构建中止

- 故障现象：GitHub Actions `Build Chromium` 在 quick-sharun 开始部署时报告 `libQt6Core.so.6`、`libQt6Gui.so.6`、`libQt6Widgets.so.6` 均为 `not found`，随后以 `./AppDir/bin/libqt6_shim.so is missing libraries! Aborting...` 退出。
- 根因：Arch Chromium 包包含 `libqt6_shim.so`，但把 `qt6-base` 作为可选依赖，因此单独安装 `chromium` 不会拉入 Qt6；当前脚本又按既定布局把 `AppDir/bin/*` 整体交给 quick-sharun，导致 quick-sharun 在检查该上游 shim 时发现其直接 ELF 依赖缺失并主动终止。
- 修改文件：`chromium/build_chromium.sh`、`chromium/README.md`。
- 修复内容：在原有 Chromium / 输入法安装命令中加入官方 Arch `qt6-base`，保留 `libqt6_shim.so` 和 `./AppDir/bin/*` 既有打包方式，不删除上游库，也不额外硬编码 `DEPLOY_QT=1`；quick-sharun 会在检测到 `libQt6Core` 后自动选择 Qt6 部署。
- 参考依据：PkgForge `Chrome-AppImage` 使用的 `get-debloated-pkgs --add-common` 明确包含 `qt6-base-mini`，说明其 Chrome 打包同样为 Qt6 shim 准备 Qt6 运行库；本仓库按来源优先级使用 Arch 官方 `qt6-base`。
- 已知结果：修复后的 `build_chromium.sh` 已完成 Bash 静态语法检查；尚未重新运行 GitHub Actions，构建与最终 AppImage 启动结果以后续真实运行反馈为准。

### 2026-09-06：修复中文输入正常但 Chromium UI 仍为英文

- 故障现象：实际 AppImage 已能正常启动，Fcitx5 中文输入候选框工作正常，但 Chromium 菜单、新标签页等主界面仍显示英文。
- 根因：`locales/zh-CN.pak` 已随 `/usr/lib/chromium/` 正确打包，但 Chromium Linux 不以 `--lang` 作为主界面语言选择依据，而是读取 `LANGUAGE`、`LC_ALL`、`LC_MESSAGES`、`LANG`。AppImage 之前继承宿主机英文 locale，因此最终选择英文 UI。
- 修改文件：`chromium/build_chromium.sh`、`chromium/README.md`。
- 修复内容：在 quick-sharun 完成 AppDir 部署后向 `AppDir/.env` 写入 `LANGUAGE=zh-CN`，由 sharun 在 AppImage 运行时注入该环境变量；不修改 desktop `Exec`，不添加 Linux 上不可靠的 `--lang=zh-CN`，也不覆盖宿主机 `LANG` / `LC_ALL`。
- 已知结果：Fcitx5 中文输入已由实际 AppImage 确认可用；新增中文 UI 设置已完成脚本静态语法检查，需下一次构建后确认界面显示结果。
