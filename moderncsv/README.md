# Modern CSV AppImage

## 用途与产物

本目录将 Modern CSV 官方 Linux 稳定版重新封装为 AppImage，稳定产物名为：

```text
moderncsv.AppImage
```

Modern CSV 是 CSV / TSV / DSV 等表格文本文件的编辑器和查看器。本项目只处理 Linux AppImage 封装、Qt 运行环境和中文输入兼容，不修改 Modern CSV 的授权机制或应用功能。

上游来源：

- 官方网站：`https://www.moderncsv.com/`
- 官方 Linux Release 目录：`https://www.moderncsv.com/release/`
- AUR `moderncsv-bin` 仅作为官方归档布局、`/opt/moderncsv` 安装方式和 XCB 启动要求的参考，不作为二进制来源。

## 技术栈

Modern CSV 2.x 为 C++ / Qt 6 桌面应用。官方 Linux 归档自带 Modern CSV 程序本体、Qt 6 运行库、Qt platform plugins、desktop 文件和 hicolor 图标资源。

当前 AppImage 目标架构为 `x86_64`。Modern CSV Linux 版按上游现有打包要求使用 Qt XCB backend，因此启动 wrapper 固定：

```text
QT_QPA_PLATFORM=xcb
```

## 打包方式

`build_moderncsv.sh` 采用直接 AppDir + `appimagetool` 的方式，不重新编译 Modern CSV：

1. 从 Modern CSV 官方 `release/` 目录动态解析最新稳定版 `ModernCSV-Linux-v<版本>.tar.gz`，不在仓库中锁定应用版本。
2. 校验下载域名、资产命名和版本格式，并记录实际下载归档的 SHA-256 到 `dist/source.sha256`。
3. 完整保留官方归档内容到 `AppDir/opt/moderncsv`，不重排或裁剪上游程序本体。
4. 根据官方归档中的 `libQt6Core.so*` 和 `libqxcb.so` 自动定位 Qt 6 library / plugin 目录。
5. 从 Ubuntu 24.04 补入 Qt XCB plugin 所需的 XCB helper 运行库，包括 `libxcb-xinerama`、`libxcb-icccm`、`libxcb-image`、`libxcb-keysyms`、`libxcb-render-util`、`libxcb-xkb`、`libxkbcommon-x11` 等，避免最终 AppImage 依赖构建机恰好已经安装这些库。
6. 从 Ubuntu 24.04 的 Fcitx5 Qt6 组件中加入 `libfcitx5platforminputcontextplugin.so`，并补充其必要的 Fcitx5 运行库；不会用系统 Qt 6 覆盖 Modern CSV 自带 Qt 6。
7. 生成 AppImage wrapper、desktop 和顶层图标；上游 desktop 若把应用版本写入 Desktop Entry 的 `Version` 字段，会规范化为 Desktop Entry 规范版本 `1.0`，再通过官方 `appimagetool` 封装为 `dist/moderncsv.AppImage`。

官方 Release 目录当前没有随 Linux tarball 提供可动态获取的官方 SHA-256 清单，因此脚本不会把第三方 AUR checksum 当作官方供应链校验值。构建时仍会记录实际下载文件的 SHA-256，便于后续审计。

## 中文环境与输入法

AppImage wrapper 固定以下中文 UTF-8 环境：

```text
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
```

同时 AppImage 内包含 Fcitx5 Qt6 platform input context plugin。宿主系统已经运行并配置 Fcitx5 时，Modern CSV 可以使用宿主 Fcitx5 输入中文；wrapper 不强制覆盖宿主的 `QT_IM_MODULE`，因此已有输入法环境变量仍会原样继承。

这里的“中文环境”主要解决 UTF-8 中文 locale 和 Fcitx5 中文输入。它不会给 Modern CSV 稳定版注入非官方中文界面翻译；应用界面语言仍以当前上游稳定版本身提供的语言资源为准。

## 构建

在 Ubuntu 24.04 环境、当前目录中执行：

```bash
./build_moderncsv.sh
```

脚本会自动安装构建封装、Qt XCB helper 和 Fcitx5 Qt6 输入模块所需的软件包，并生成：

```text
dist/moderncsv.AppImage
dist/version.txt
dist/source.sha256
```

正式 CI 入口为仓库统一 `.github/workflows/build.yml`，可通过 `moderncsv/build_moderncsv.sh` 单独选择构建，也会参与 `all` 和每日统一构建。

## 运行

在 AppImage 所在目录执行：

```bash
./moderncsv.AppImage
```

正常使用中文输入时，宿主 Fcitx5 需要已经启动并具有可用的中文输入法配置。

## 验证

构建脚本会执行以下检查：

- 官方 tarball 能正常解包，且包含 `moderncsv`、`moderncsv.desktop` 和 hicolor 图标。
- 官方程序仍为 Qt 6，并能找到 XCB platform plugin；如果技术栈发生变化则直接停止，避免错误混用输入法插件。
- 打包后的 desktop 通过 `desktop-file-validate`，并确认 `Version=1.0`。
- Modern CSV 主程序、Fcitx5 Qt6 plugin 和 Qt XCB platform plugin 的 `ldd` 均不存在 `not found`。
- 对 `libqxcb.so` 实际使用的 XCB helper 逐项检查解析路径；相关依赖必须来自当前 AppDir / 最终 AppImage，不能借用构建机 `/usr/lib` 或 `/lib` 让 CI 误通过。
- 最终 AppImage 能重新提取，程序本体、wrapper、中文 locale 环境变量、desktop 规范版本、Fcitx5 plugin 和关键 XCB helper 均真实存在。
- 最终封装后的主程序、Fcitx5 plugin 和 `libqxcb.so` 再次执行动态库与依赖来源检查。
- GitHub Actions 使用 Xvfb 启动最终 AppImage，并显式设置 `QT_IM_MODULE=fcitx` 检查 Fcitx5 Qt6 plugin 能被 Qt 发现，同时拒绝 Qt platform plugin、共享库、崩溃等启动错误。

## 变更记录

### 2026-09-02：首次加入 Modern CSV AppImage 与中文输入环境

- 新增 `moderncsv/build_moderncsv.sh` 和本 README。
- 上游改为直接读取 Modern CSV 官方稳定版 Release，不锁定应用版本；AUR 仅用于核对 Linux 包布局与 XCB 启动方式。
- 保留官方 Qt 6 运行时，并加入 Fcitx5 Qt6 输入法 plugin、`zh_CN.UTF-8` / `zh_CN:zh` 环境。
- 增加 tarball、desktop、Qt6/XCB、Fcitx5 plugin、ELF/动态库和最终 AppImage 提取检查。
- 接入仓库统一 `build.yml`，由 Ubuntu 24.04 Job 执行构建和 Xvfb/Fcitx5 smoke test。

### 2026-09-02：修复上游 desktop `Version` 字段不符合 Desktop Entry 规范

- 首次 CI 在 `desktop-file-validate` 处失败，上游 `moderncsv.desktop` 使用 `Version=2.4.3`。
- 根因是 Desktop Entry 的 `Version` 表示规范版本，不是 Modern CSV 应用版本；`2.4.3` 不是该字段可识别的规范版本。
- `build_moderncsv.sh` 只对 AppImage 内复制出的 desktop 文件将该字段规范化为 `Version=1.0`，不修改 Modern CSV 程序版本，也不改动保留在 `/opt/moderncsv` 下的上游原始文件。
- 增加打包前 desktop 校验和最终 AppImage 内 `Version=1.0` 检查，避免同类问题再次进入产物。

### 2026-09-02：修复 Linux 实机无法加载 Qt XCB platform plugin

- Linux 实机运行已发布的 `moderncsv.AppImage` 时出现 `Could not load the Qt platform plugin "xcb" ... even though it was found`，应用在 Qt 初始化阶段直接退出。
- 根因是原构建只检查 Modern CSV 主程序和 Fcitx5 Qt6 plugin，没有检查 `libqxcb.so` 自身依赖；Ubuntu CI runner 已安装 XCB helper，因此旧 smoke test 会借用构建机运行库并误判为可用。
- `build_moderncsv.sh` 现在将 Qt XCB 常用 helper 运行库一并加入 `AppDir/usr/lib`，覆盖 `libxcb-xinerama`、`libxcb-icccm`、`libxcb-image`、`libxcb-keysyms`、`libxcb-render-util`、`libxcb-xkb`、`libxkbcommon-x11` 等依赖链。
- 新增 `libqxcb.so` 的构建前和最终 AppImage 双重 `ldd` 检查，并要求其实际使用的 XCB helper 必须解析到 AppImage 内部路径，禁止继续借用 CI 宿主库通过验证。
