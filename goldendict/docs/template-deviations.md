# GoldenDict 专属差异

公共分区、通用注释和执行阶段按 [linuxdeploy 规范](../../linuxdeploy_projects.md) 与 [固定注释标准](../../docs/linuxdeploy-comments.md) 整理，对照 [XnView MP](../../xnviewmp/build_xnviewmp.sh)、[Remmina](../../remmina/build_remmina.sh) 和 [MediaInfo](../../mediainfo/build_mediainfo_linuxdeploy.sh)。

现有 Qt 模板面向官网校验清单中的 DEB；本程序使用 Ubuntu 24.04 仓库的原版 GoldenDict，并同时需要 Qt5 与 GStreamer。来源、完整 DEB 版本号和已经确认的专属处理按下表保留，不改成 GoldenDict-ng，不为套用模板更换软件来源。

| 位置 | 专属处理及原因 | 代码或依据 |
| --- | --- | --- |
| 应用来源与版本 | 安装 Ubuntu 官方 `goldendict` 后，保留原 `dpkg-query` 的完整版本号，再精确下载同版本 DEB。公共 `extract_installed_package.sh` 会去掉 epoch / revision，因此这里保留原版本读取和解包命令。 | [版本读取](../build_goldendict.sh#L22)、[同版本解包](../build_goldendict.sh#L43)；[版本约定](../README.md#来源与打包) |
| 工具准备 | 使用公共入口的 `qt,gstreamer` 组合，一次准备工具及两个官方插件并加载环境；不再单独下载 GStreamer 源码、复制插件或重复加载环境。官方 GStreamer 脚本的 Git blob 校验由公共入口负责。 | [工具准备](../build_goldendict.sh#L27)；[公共实现](../../common/linuxdeploy/prepare_linuxdeploy_tools.sh) |
| Qt 查询与扫描 | 保留 Qt5 的 `QMAKE` 和 `QT_SELECT`。QMAKE 在资源准备前设置，供输入插件目录查询和后续 Qt 部署共用；不复制其他应用的 Qt6 配置或额外 QML 路径。 | [Qt5 设置](../build_goldendict.sh#L30)、[插件目录查询](../build_goldendict.sh#L63)；[扫描工具故障](../README.md#验证记录) |
| 资源回退路径 | 保留官方 DEB 的完整目录布局，以及程序旁的 `locale`、`help` 符号链接，不改写主程序二进制。 | [资源路径](../build_goldendict.sh#L48)；[原始实现](https://github.com/newyorkthink/linux-packaging/blob/1646da1929c78009f1935fbd7e725dd39e31a2e9/goldendict/build_goldendict.sh) |
| 中文资源与输入 | 保留文泉驿字体、Qt 中文翻译及同一套 Qt5 compose / IBus / Fcitx5 输入插件。locale 改由现有公共入口生成，源名称、字符集和输出目录仍与原命令一致；输入法服务和选择沿用宿主会话。 | [字体和目录](../build_goldendict.sh#L54)、[locale 生成](../build_goldendict.sh#L60)、[Qt 输入插件](../build_goldendict.sh#L66) |
| 字体配置 | 保留系统 fontconfig 配置与包内中文字体搜索路径；AppRun 使用当前包内配置，不修改宿主字体配置。 | [字体配置](../build_goldendict.sh#L72) |
| AppRun | 完整入口继续内联；所有原可执行命令、参数和顺序保持一致，包括 `set -e`、原目录定位方式、`GCONV_PATH` 清理、目录描述符 9、三个基础搜索路径、Qt 路径及中文环境。AppRun 的 `set -e` 只说明命令失败退出，不套用“引用未定义变量或管道失败退出”的严格模式注释。 | [完整入口](../build_goldendict.sh#L84)；[正文与发音实测](../README.md#验证记录) |
| 桌面入口与图标 | 保留原 linuxdeploy 整行及 `org.goldendict.GoldenDict.desktop`、`goldendict.png` 参数，同时启用 Qt / GStreamer；只把中间 AppImage 放入 source，最终仍由官方 appimagetool 与明确的 Type 2 runtime 封装。 | [依赖部署](../build_goldendict.sh#L132)、[最终封装](../build_goldendict.sh#L143) |
| libao 发音修复 | 第二次 linuxdeploy 完成后，复制 PulseAudio / ALSA 输出模块及 `libpulse-simple.so.0`、`libasound.so.2`，随后将官方 libao 的宿主模块路径等长重定位到 `/proc/self/fd/9/usr/lib/ao/plugins-4`。原命令逐字迁入 patches，参数和先后顺序不变，不自行编译 libao，也不修改词典或播放器选择。 | [调用位置](../build_goldendict.sh#L137)、[修复实现](../patches/prepare_libao_runtime.sh#L10)；[原始实现](https://github.com/newyorkthink/linux-packaging/blob/1646da1929c78009f1935fbd7e725dd39e31a2e9/goldendict/build_goldendict.sh)、[失败与实机通过记录](../README.md#验证记录) |
| 最终路径整理 | 保留已有公共路径整理调用，位置仍在 libao 修复之后、最终封装之前；只整理入口已经声明的搜索路径，按实际产物处理 AppRun 或 AppRun.wrapped，不手工创建 hook。 | [路径整理](../build_goldendict.sh#L140)；[公共实现](../../common/linuxdeploy/normalize_apprun_paths.sh) |

## 旧版与构建入口

[build_goldendict_old.sh](../build_goldendict_old.sh) 与整理前的正式脚本逐字节一致，仅供查阅。正式入口仍是 `goldendict/build_goldendict.sh`；旧版不登记到应用清单，不从主脚本调用，也不作为产物来源。现有 workflow 的 `build_*_old.sh` 排除规则和 Plan 的未登记脚本过滤继续生效。

`patches/prepare_libao_runtime.sh <AppDir>` 只在现有 AppDir 中执行原 libao 处理，不安装软件、不下载工具、不重新解包或封装 AppImage。该入口在依赖部署后执行，与准备阶段的 Qt 输入插件、翻译和中文资源处理分开。

## 上游参考核对

2026-11-06 查阅 [上游打包参考索引](../../docs/upstream-packaging-index.md) 并在 pkgforge-dev 中检索 GoldenDict。结果只有 [GoldenDict-ng-AppImage](https://github.com/pkgforge-dev/GoldenDict-ng-AppImage)，它对应独立维护的 GoldenDict-ng，不作为本目录原版 GoldenDict 的同名打包实现。本次没有引入其应用专属代码；本程序的资源、正文与发音处理继续以本目录已有实现和实机记录为依据。

本次整理的逐项检查记录见 [README](../README.md#验证记录)。
