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
- `quick-sharun`：`https://github.com/pkgforge-dev/Anylinux-AppImages/blob/main/useful-tools/quick-sharun.sh`

## 技术栈

Modern CSV 2.x 为 C++ / Qt 6 桌面应用。官方 Linux 归档自带 Modern CSV 程序本体和 Qt 6 运行库。

当前 AppImage 目标架构为 `x86_64`，运行时固定使用 Qt XCB backend：

```text
QT_QPA_PLATFORM=xcb
```

Qt plugin 不再通过手写 `QT_PLUGIN_PATH` / `QT_QPA_PLATFORM_PLUGIN_PATH` 启动 wrapper 定位，而是使用 `quick-sharun` 生成的标准 `qt.conf` 相对路径机制。

## 打包方式

`build_moderncsv.sh` 改为使用 `quick-sharun` / `sharun` 标准 AppImage 结构，不再直接手工拼 AppDir，也不再生成 `usr/bin/moderncsv` 启动脚本：

1. 从 Modern CSV 官方 `release/` 目录动态解析最新稳定版 `ModernCSV-Linux-v<版本>.tar.gz`，不在仓库中锁定应用版本。
2. 校验下载域名、资产命名和版本格式，并记录实际下载归档的 SHA-256 到 `dist/source.sha256`。
3. 明确检查官方主运行库目录存在 `libQt6Core.so*`，同时拒绝 `libQt5*.so*`；主程序 `ldd` 也必须解析到 Qt6 且不能出现 Qt5。
4. `quick-sharun` 部署时以官方归档自带的 `lib/` 作为 Modern CSV 的 Qt6 主运行时来源，不再把 Qt5 runtime 混入最终 AppImage。
5. Ubuntu 24.04 的 Qt6 plugin 目录只作为 Qt6 plugin 来源，由 `quick-sharun` 自动收集 XCB、Compose / Fcitx5 / IBus 三个 Qt6 `platforminputcontexts` plugin 和 Qt6 OpenSSL TLS backend；构建阶段通过官方 Qt6 `lib/` 解析这些 plugin 的 Qt 依赖，避免额外混入另一套 Qt runtime。
6. `quick-sharun` 生成标准 `bin/moderncsv`、`shared/bin/moderncsv`、`bin/qt.conf`、`AppRun` 和 `lib/qt6/plugins/...` 结构；最终包中明确禁止出现旧的 `usr/bin/moderncsv` 手写 wrapper。
7. 中文 locale 和 XCB 设置只写入 sharun 的 `.env`，不再通过自制启动脚本设置 `LD_LIBRARY_PATH`、`QT_PLUGIN_PATH` 或手工 exec `/opt/moderncsv/moderncsv`。
8. 最后由 `quick-sharun --make-appimage` 生成 `dist/moderncsv.AppImage`，再重新提取并执行 Xvfb/Fcitx5 Qt6 smoke test。

官方 Release 目录当前没有随 Linux tarball 提供可动态获取的官方 SHA-256 清单，因此脚本不会把第三方 checksum 当作官方供应链校验值。构建时仍会记录实际下载文件的 SHA-256，便于后续审计。

## 中文环境与输入法

最终 AppImage 的 sharun `.env` 固定：

```text
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
QT_QPA_PLATFORM=xcb
```

`quick-sharun` 从 Qt6 plugin 树部署 `libcomposeplatforminputcontextplugin.so`、`libfcitx5platforminputcontextplugin.so`、`libibusplatforminputcontextplugin.so` 三个输入上下文 plugin。宿主系统已经运行并配置 Fcitx5 时，Modern CSV 可以使用宿主 Fcitx5 输入中文；使用 IBus 或 Qt Compose 时，对应 Qt6 输入上下文也保留在 AppImage 中。AppImage 不强制覆盖宿主的 `QT_IM_MODULE`。

这里的“中文环境”解决 UTF-8 中文 locale 和 Linux Qt 输入上下文兼容，不向 Modern CSV 注入非官方中文界面翻译；应用界面语言仍以当前上游稳定版本身提供的语言资源为准。

## 构建

在 Ubuntu 24.04 环境、当前目录中执行：

```bash
./build_moderncsv.sh
```

脚本会自动安装 `quick-sharun` 所需构建工具、Qt6 plugin、Fcitx5 Qt6 和 Xvfb 依赖，并生成：

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

- 官方 tarball 能正常解包，并包含 `moderncsv`、`moderncsv.desktop`、Qt6 主运行库和图标。
- 官方主运行库目录与主程序依赖均为 Qt6；检测到任何 `libQt5*.so*` 或主程序解析到 Qt5 时直接停止。
- Qt6 XCB、Compose / Fcitx5 / IBus 三个输入上下文 plugin 和 OpenSSL TLS plugin 在进入 `quick-sharun` 前均执行 `ldd` 检查，不能出现 `not found` 或 Qt5 依赖解析。
- `quick-sharun` AppDir 必须存在 `bin/moderncsv`、`shared/bin/moderncsv`、`bin/qt.conf`、Qt6 XCB、Compose / Fcitx5 / IBus 输入上下文和 TLS plugin，并明确不存在 `usr/bin/moderncsv`。
- sharun `.env` 只保留中文 locale、`LANGUAGE` 和 XCB 设置；若出现 `QT_PLUGIN_PATH` 则直接失败，Qt plugin 必须由 `qt.conf` 定位。
- 最终 AppImage 重新提取后再次检查标准 sharun 目录、Qt6 runtime/plugin、三个输入上下文 plugin 的存在性和动态依赖、中文 `.env`、desktop 和 Qt5 排除条件。
- 最终 AppImage 使用 Xvfb + `QT_IM_MODULE=fcitx` + `QT_DEBUG_PLUGINS=1` 实际启动；日志若出现 Qt5/Qt6 plugin 不兼容、Qt platform plugin 加载失败、输入上下文 plugin 加载失败、TLS backend 缺失、动态库错误或崩溃则构建失败。

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
- `build_moderncsv.sh` 只对 AppImage 内复制出的 desktop 文件将该字段规范化为 `Version=1.0`，不修改 Modern CSV 程序版本。

### 2026-09-02：修复 Linux 实机无法加载 Qt XCB platform plugin

- Linux 实机运行已发布的 `moderncsv.AppImage` 时出现 `Could not load the Qt platform plugin "xcb" ... even though it was found`，应用在 Qt 初始化阶段直接退出。
- 根因是原构建只检查 Modern CSV 主程序和 Fcitx5 Qt6 plugin，没有检查 `libqxcb.so` 自身依赖；Ubuntu CI runner 已安装 XCB helper，因此旧 smoke test 会借用构建机运行库并误判为可用。
- `build_moderncsv.sh` 现在将 Qt XCB 常用 helper 运行库一并加入 `AppDir/usr/lib`，并新增构建前和最终 AppImage 双重 `ldd` / 依赖来源检查。

### 2026-09-02：修复 Qt5 遗留 plugin 污染与 Qt6 TLS backend 缺失

- Linux 实机已能正常打开 Modern CSV，但终端持续出现 `Plugin uses incompatible Qt library (5.12.0)`，说明 Qt6 仍在扫描官方归档中的 Qt 5.12 遗留 plugin。
- 同时出现 `No functional TLS backend was found`、`No TLS backend is available` 和 `TLS initialization failed`，说明 AppImage 没有提供 Qt6 Network 所需的 OpenSSL TLS backend。
- 现在只从官方 plugin 目录保留已经验证可用的 Qt6 `libqxcb.so`，并改用独立 `usr/plugins` 作为干净 Qt6 plugin 根目录，Fcitx5、XCB 和 TLS plugin 分目录放置。
- 加入 `libqopensslbackend.so`、`libssl.so.3` 和 `libcrypto.so.3`，并对 TLS plugin 执行构建前和最终 AppImage 双重 `ldd` 检查。
- 构建脚本新增 Xvfb 实际启动验证；如果日志再次出现 Qt5/Qt6 plugin 不兼容或 TLS backend 缺失，CI 会直接失败，不再发布该产物。

### 2026-09-02：改用 quick-sharun，移除手写 Modern CSV 启动 wrapper

- 重新检查官方 Linux 归档后，当前应用技术栈继续明确按 Qt6 处理；新打包流程禁止把 Qt5 runtime 混入 AppImage。
- 打包主流程从“直接 AppDir + `appimagetool` + 手工复制 Qt plugin/运行库”切换为 `quick-sharun` / `sharun`。
- 删除 `usr/bin/moderncsv` 手写 launcher 设计；最终入口改为 quick-sharun 标准 `bin/moderncsv` / `shared/bin/moderncsv` / `AppRun`。
- Qt plugin 改由 quick-sharun 的 Qt6 部署逻辑统一收集，并使用生成的 `bin/qt.conf` 定位；不再设置 `QT_PLUGIN_PATH` / `QT_QPA_PLATFORM_PLUGIN_PATH`。
- Fcitx5 继续使用 Qt6 platform input context plugin，TLS 继续使用 Qt6 OpenSSL backend；中文 locale 与 XCB 设置移入 sharun `.env`。
- 新增结构检查：最终 AppImage 必须不存在 `usr/bin/moderncsv` 和 `libQt5*.so*`，并必须存在 Qt6 XCB、Fcitx5、TLS plugin 与 `bin/qt.conf`。
- 静态检查包括 `bash -n`；实际构建仍由统一 CI 的 Ubuntu 24.04 Job 执行，并由脚本内和 workflow 的 Xvfb/Fcitx5 smoke test 验证最终产物。

### 2026-09-02：补齐 Qt6 platforminputcontexts 输入上下文插件

- 保持现有 quick-sharun / sharun Qt6 打包路线不变，不回退到 linuxdeploy，也不恢复手写 `AppRun` / `usr/bin/moderncsv` wrapper。
- 构建前必须同时找到并检查 `libcomposeplatforminputcontextplugin.so`、`libfcitx5platforminputcontextplugin.so`、`libibusplatforminputcontextplugin.so` 三个 Qt6 输入上下文 plugin；任意一个缺失、存在 `not found` 或解析到 Qt5 都直接失败。
- quick-sharun 构建后的 AppDir 和最终 AppImage 都必须实际包含上述三个 plugin；最终提取后再次对三个 plugin 执行 `ldd`，防止构建机上存在但成品遗漏依赖。
