# XnConvert AppImage

## 用途与产物

本目录把 XnConvert 官方 x86_64 DEB 重新打包为 AppImage，正式 Release 资产固定为 `xnconvert.AppImage`。

构建脚本单行调用公共校验清单下载入口；公共脚本每次读取官方 `XnConvert-CHECKSUMS.txt`，选择当前最新稳定版 `linux-x64.deb`，使用同一份官方清单中的 SHA-256 校验，并把实际版本写入 `dist/version.txt`。应用和打包工具版本都不固定。

## 技术栈与稳定基线

XnConvert 是 Qt5 应用，官方 DEB 的真实布局同时包含：

- `opt/XnConvert/XnConvert` 主程序；
- `opt/XnConvert/lib` 自带 Qt5 运行库和 Qt plugin 分类目录；
- `opt/XnConvert/Plugins` 应用自己的图片格式解码库；
- `opt/XnConvert/language` 应用翻译；
- `usr/bin/xnconvert` 官方命令入口。

`opt/XnConvert/Plugins` 不是 Qt plugin 根目录，不加入 `QT_PLUGIN_PATH`。`AddOn` 也是应用数据目录，不加入路径型 export。

## linuxdeploy 规范流程

1. 使用公共 APT、校验清单下载和工具准备入口；构建脚本对每次安装或下载只保留一条调用，不自行实现联网、版本选择、摘要校验或包管理器逻辑。
2. 单行调用 `common/linuxdeploy/initialize_appdir.sh`；公共入口在空目录执行原始普通 linuxdeploy 命令，只创建基础目录。
3. 下载并校验当前官方 DEB，把同一文件安装到 Ubuntu 构建环境供依赖扫描，并按上游原始布局解压到 AppDir。
4. 保留官方 `usr/bin/xnconvert` 入口，但把其中写死的系统 `/opt` 改为转入根 AppRun；根 AppRun 始终直接执行 `opt/XnConvert/XnConvert`，不通过 `usr/bin` 二次转发。
5. 保留已有 Qt5 翻译、XCB 平台库、Fcitx5 / IBus / Compose 输入上下文和图标部署方式。
6. 第二次执行 Qt linuxdeploy，由它把完整根 AppRun 保存为 `AppRun.wrapped`，并生成加载 Qt hook 的顶层 AppRun。
7. 第二次 linuxdeploy 后调用 `normalize_apprun_paths.sh`，只按最终 AppDir 中真实存在的目录整理 AppRun 路径型 export。新版正式成品经用户确认正常后，再固化最终 export 并删除这次调用。
8. linuxdeploy 产物只作为中间结果；正式资产由 appimagetool 使用官方 Type 2 runtime 对同一个 AppDir 重新封装。

## AppRun 路径

当前 AppRun 的候选稳定路径为：

- `PATH`：`opt/XnConvert`、`usr/bin`；
- `LD_LIBRARY_PATH`：`opt/XnConvert/lib`、`usr/lib`；
- `XDG_DATA_DIRS`：`usr/share`；
- `QT_PLUGIN_PATH`：`opt/XnConvert/lib`、`usr/plugins`；
- `QT_QPA_PLATFORM_PLUGIN_PATH`：`opt/XnConvert/lib/platforms`、`usr/plugins/platforms`；
- `QT_TRANSLATIONS_PATH`：`usr/translations`。

`usr/translations` 同时包含系统 Qt5 翻译，以及 linuxdeploy 指向 `opt/XnConvert/language` 的应用翻译链接。不要重复把 `language` 加入 `QT_TRANSLATIONS_PATH`。

## 中文输入与 XCB

Fcitx5、IBus 和 Compose 的 Qt5 输入上下文插件由 linuxdeploy 放入 `usr/plugins/platforminputcontexts`。因此 `QT_PLUGIN_PATH` 必须同时保留 `opt/XnConvert/lib` 和 `usr/plugins`，不能改成单一路径。

XnConvert 使用自带的 `opt/XnConvert/lib/platforms/libqxcb.so`，`QT_QPA_PLATFORM_PLUGIN_PATH` 和 `QT_QPA_PLATFORM=xcb` 属于已经确认的稳定基线。修改 Qt/XCB 设置时不得破坏输入法插件搜索路径，也不得让 Qt5 主程序混入 Qt6 plugin。

## AppRun 执行链

第二次 linuxdeploy 后的正确结构为：

```text
AppRun                  # linuxdeploy 生成并加载 Qt hook
AppRun.wrapped          # 构建脚本预置的完整根启动脚本
usr/bin/xnconvert       # 官方命令入口，转入根 AppRun
opt/XnConvert/XnConvert # 根 AppRun 直接执行的真实主程序
```

禁止手工创建 `AppRun.wrapped`，也不能覆盖 linuxdeploy 生成的顶层 AppRun。

## 已核对结果

2026-09-20 下载并解包当时的旧版 `latest/xnconvert.AppImage` 后确认：顶层 AppRun 正确加载 Qt hook；`AppRun.wrapped` 是普通可执行脚本；XnConvert 自带 Qt plugin、`usr/plugins` 输入上下文、翻译链接和 XCB 依赖均存在；主程序与 qxcb plugin 在最终库路径下没有 `not found`。

本次构建脚本改为仓库统一的两阶段 linuxdeploy、公共下载入口和 appimagetool + Type 2 runtime 最终封装，并删除正式脚本与 workflow 中的解包检查和 GUI smoke test。修改后已在 Ubuntu 24.04 临时环境完成一次完整构建；新成品的 AppRun 执行链、官方命令入口、三种输入上下文、翻译目录和直接动态依赖均已在仓库外解包核对通过。首次发布仍保留路径整理脚本；用户确认 Release 成品正常后，才把整理结果固化为最终 export。后续验证继续在仓库外临时目录进行，不把测试代码重新写入构建流程。

2026-09-20 进一步移除构建脚本中的 APT 权限处理、软件包安装、官方校验清单解析、最新版选择、下载地址拼装、摘要提取和版本文件写入逻辑；这些通用行为分别集中到 `common/apt/install_packages.sh` 与 `common/download/download_latest_checksum_asset.sh`。XnConvert 构建脚本只传入明确依赖、官方清单地址、资产名正则和输出位置，后续通用修复只修改公共实现。迁移后已完成一次完整构建，公共入口、两次 linuxdeploy、AppRun 路径整理和最终 Type 2 AppImage 封装均正常完成。

2026-09-20 第一次普通 linuxdeploy 进一步集中到 `common/linuxdeploy/initialize_appdir.sh`；XnConvert 构建脚本只保留一行调用。Qt5 环境、AppRun、第二次 linuxdeploy 和尚待成品确认的路径整理调用均未改变。
