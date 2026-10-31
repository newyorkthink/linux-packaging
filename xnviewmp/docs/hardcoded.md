# XnView MP 固定配置

本文件说明 [build_xnviewmp.sh](../build_xnviewmp.sh) 已获准的路径、参数及取值依据。只适用于当前应用，不作为其他程序的通用参数；完整执行代码与行号见 [模板差异](./template-deviations.md)。

## 安装包与产物

| 配置 | 取值 | 依据与用途 |
| --- | --- | --- |
| 架构 | x86_64 | 当前脚本的目标架构及官方 linux-x64.deb 资产。 |
| 官方校验清单 | https://download.xnview.com/versions/XnView_MP/XnView_MP-CHECKSUMS.txt | 由公共 --checksum 入口选择最新稳定版并校验同一安装包。 |
| 安装包文件名匹配 | `^XnView_MP-[0-9]+(\.[0-9]+)+-linux-x64\.deb$` | 限定官方清单中的 x64 DEB，不固定具体应用版本。 |
| 下载保存位置 | `$SOURCE_DIR/XnView_MP.deb` | 同一份安装包用于系统安装和 AppDir 解包。 |
| 正式资产 | `dist/xnviewmp.AppImage` | 既有发布资产名称，由公共最终封装入口生成。 |
| 版本记录 | `dist/version.txt` | 仅在正式封装成功后由既有公共入口保存。 |

## 图标与运行库

| 配置 | 取值 | 依据与用途 |
| --- | --- | --- |
| 桌面入口 | `$APPDIR/usr/share/applications/XnView.desktop` | 官方 DEB 的主桌面入口，用于修正 Icon 字段。 |
| 应用图标 | `$APPDIR/opt/XnView/xnview.png` | 官方包内 PNG，交给 linuxdeploy 的 --icon-file 部署。 |
| Icon 字段 | `xnview` | 官方入口原来使用绝对路径，公共封装检查不接受该值，因此改为图标名称。 |
| Qt 模块识别入口 | `$APPDIR/opt/XnView/lib/libQt6XcbQpa.so*` | 自带 Qt 库位于 opt 布局；按本次获准代码复制到 usr/lib，供 Qt 插件识别模块。 |
| 系统库来源 | `/usr/lib/x86_64-linux-gnu` | 当前 Ubuntu x86_64 构建环境的运行库目录。 |
| 已获准复制的库 | libpulse.so.0、libwayland-client.so.0、libwayland-cursor.so.0、libwayland-egl.so.1、libpipewire-0.3.so.0、libva.so.2、libva-drm.so.2、libva-x11.so.2 | 保留包内 Qt / MDK 等组件依赖的库，并补入 Qt 运行时动态加载所需的 PipeWire / VA-API 库。 |
| PipeWire 构建依赖 | libpipewire-0.3-0t64 | Ubuntu 24.04 中提供 libpipewire-0.3.so.0 的包；在原 APT 安装行补入，不固定软件包版本。 |
| PulseAudio 配套库 | `/usr/lib/x86_64-linux-gnu/pulseaudio/libpulsecommon-*.so` | 与补入的 PulseAudio 库一并保留其配套依赖。 |

## AppRun

| 配置 | 取值 | 依据与用途 |
| --- | --- | --- |
| 真实入口 | `$HERE/opt/XnView/XnView` | 保留官方目录布局，根 AppRun 直接执行真实程序并转交参数。 |
| 程序目录 | `$HERE/opt/XnView`、`$HERE/usr/bin` | 保留应用目录及标准程序搜索目录。 |
| 运行库目录 | `$HERE/opt/XnView/lib`、`$HERE/usr/lib` | 沿用已确认的包内库搜索路径，不替换成构建阶段的 APPDIR 设置。 |
| 共享数据目录 | `$HERE/usr/share` | 标准 AppDir 共享数据目录。 |
| Qt 插件目录 | `$HERE/opt/XnView/lib`、`$HERE/usr/plugins` | 已确认的 Qt plugin 根目录，不把应用自身 Plugins 目录混入。 |
| QML 目录 | `$HERE/opt/XnView/qml` | 保留原有 QML_IMPORT_PATH 和 QML2_IMPORT_PATH。 |
| 翻译目录 | `$HERE/usr/translations` | 保留原有 QT_TRANSLATIONS_PATH，应用自己的 language 目录由程序读取。 |
| 中文环境 | `LANG=zh_CN.UTF-8`、`LANGUAGE=zh_CN:zh` | 保留已确认的中文界面配置。 |
| 显示与输入法 | `QT_QPA_PLATFORM=xcb`、`QT_IM_MODULE=ibus`、`QT_IM_MODULES=ibus`、`IBUS_USE_PORTAL=1` | 沿用 README 记录的 IBus Portal 实测方案，不因安装 fcitx5-frontend-qt6 改动该组合。 |
| 缩放与字体 | `QT_AUTO_SCREEN_SCALE_FACTOR=1`、`QT_FONT_DPI=96` | 沿用用户确认版本的既有值，不作为所有 Qt 程序的默认要求。 |
| 视频设置 | `QT_DISABLE_HW_TEXTURES_CONVERSION=1` | 保留既有兼容设置；README 中的部分视频黑屏问题记录不因此删除。 |

## Qt 查询工具

`QMAKE=qmake6` 指向工具目录中的已获准入口，该入口清除 LD_LIBRARY_PATH 后执行 `/usr/bin/qmake6`。历史记录中系统 qmake 曾误加载应用自带 Qt，入口用于隔离系统工具。当前脚本不额外设置构建阶段的 LD_LIBRARY_PATH，也不启用 AppRun 路径整理调用。

应用版本、linuxdeploy、Qt 插件、appimagetool 和 runtime 版本继续动态取得；本文件不把历史版本写成构建锁定值。
