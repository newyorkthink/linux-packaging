# XnView MP 模板差异

## 当前依据与范围

唯一完整模板仍为 [Joplin](../../joplin/build_joplin.sh)，执行规则见 [linuxdeploy 规范](../../linuxdeploy_projects.md)，注释原文见 [固定注释标准](../../docs/linuxdeploy-comments.md)。本文件只记录 XnView MP 已获准的差异，不是供其他应用复制的模板。

本次写入版本为 [build_xnviewmp.sh](../build_xnviewmp.sh) 的 129 行、40 行空行、89 行非空行；相对 Joplin 的 85 行、29 行空行增加 44 行，其中增加 11 行空行。通用脚本头、工作区、工具准备、初始化、公共安装包入口、AppRun 基础结构、第二次 linuxdeploy 和最终封装的位置保持原有顺序。

## 差异位置与原因

| 所在位置 | 相对 Joplin 的差异 | 原因及边界 |
| --- | --- | --- |
| [构建依赖，第 17 行](../build_xnviewmp.sh#L17) | 使用已确认的 Qt6、媒体、Wayland 和 XCB 依赖清单，保留 fcitx5-frontend-qt6，并补入 libpipewire-0.3-0t64。 | 依赖参数按 XnView MP 实际需要及本次授权保留，不照抄 Joplin 的 GTK / Electron 依赖。安装软件包不改变 AppRun 的 IBus Portal 配置。 |
| [工具准备，第 22 行](../build_xnviewmp.sh#L22) | 插件参数使用 qt。 | 当前应用使用 Qt6，通用调用结构和注释保持不变。 |
| [安装包准备，第 32 行](../build_xnviewmp.sh#L32) | 公共 DEB 入口使用 --checksum 和 XnView 官方清单。 | 官方来源不采用 GitHub Release 资产模板，下载、校验、安装和解包仍由同一公共入口处理。 |
| [桌面资源与运行库，第 36 行](../build_xnviewmp.sh#L36) | 使用本节下列完整代码，替代不适用的 Joplin 主题和 NSS 收集步骤。 | 官方 desktop 的绝对图标路径被公共封装检查拒绝；Qt 库位于 opt 布局，需按已获准代码供插件识别；包内组件依赖 PulseAudio / Wayland 系统库，运行日志还显示 Qt 动态加载 PipeWire / VA-API 失败。 |
| [AppRun，第 57 行](../build_xnviewmp.sh#L57) | 使用下列完整 AppRun，保留中文、Qt 路径、缩放、输入法、视频和字体设置。 | 沿用已确认的应用配置，不把 Qt 设置标成 XnView 独有功能，不套用 Joplin 的 GTK schema / GIO 配置。 |
| [核心打包，第 106 行](../build_xnviewmp.sh#L106) | 使用下列 qmake6 入口和完整 linuxdeploy 命令。 | 历史记录中系统 qmake 曾误加载应用自带 Qt；保留工具隔离入口，向 linuxdeploy 指定包内图标。本次不增加构建阶段的 LD_LIBRARY_PATH。 |

下列代码与本次获准脚本逐字一致。代码中的固定路径仅描述当前应用，不作为其他程序的参数示例。

## 桌面资源和运行库

[失败日志](https://github.com/newyorkthink/linux-packaging/actions/runs/41175873664/job/124463228278) 显示 Qt 插件未识别到模块。官方 DEB 的 Qt 库位于 opt/XnView/lib；此次按用户确认的代码复制自带 XCB 平台库，不改为手工指定 EXTRA_QT_MODULES。

桌面入口的图标修正用于通过公共封装检查。运行库列表保留原有 PulseAudio 和 Wayland 库，并按本次日志补入 PipeWire、VA-API 库；不扩大为旧版整组运行库复制。

```bash
# 指定 XnView MP 官方安装包中的桌面入口和图标路径，供图标修正及 linuxdeploy 图标部署使用。
DESKTOP_FILE="$APPDIR/usr/share/applications/XnView.desktop"
ICON_FILE="$APPDIR/opt/XnView/xnview.png"

# XnView MP 官方桌面入口使用绝对图标路径，需改为图标名称才能通过公共封装检查。
sed -i 's|^Icon=.*|Icon=xnview|' "$DESKTOP_FILE"

# 复制应用自带的 Qt XCB 平台库，供 Qt 插件识别模块。
cp -a "$APPDIR/opt/XnView/lib"/libQt6XcbQpa.so* "$APPDIR/usr/lib/"

# XnView MP 的包内组件依赖 PulseAudio、Wayland，Qt 多媒体还会动态加载 PipeWire 和 VA-API，因此一并补入对应运行库。
for runtime_lib in libpulse.so.0 libwayland-client.so.0 libwayland-cursor.so.0 libwayland-egl.so.1 libpipewire-0.3.so.0 libva.so.2 libva-drm.so.2 libva-x11.so.2; do
  # 复制当前运行库及其版本文件。
  cp -a "/usr/lib/x86_64-linux-gnu/${runtime_lib}"* "$APPDIR/usr/lib/"
done

# 为 XnView MP 补入的 PulseAudio 库还依赖 libpulsecommon，因此同时复制该配套库。
cp -a /usr/lib/x86_64-linux-gnu/pulseaudio/libpulsecommon-*.so "$APPDIR/usr/lib/"
```

Ubuntu 24.04 的 PipeWire 运行库由 [libpipewire-0.3-0t64](https://packages.ubuntu.com/noble/amd64/libpipewire-0.3-0t64) 提供。Qt 通过 [运行时符号解析](https://github.com/qt/qtmultimedia/blob/v6.8.3/src/multimedia/qsymbolsresolveutils.cpp) 加载相应库；本次将 PipeWire 库和已获准的 VA-API 相关库补入 AppDir 的 usr/lib，交由后续 linuxdeploy 收集可解析的动态依赖。本次只补齐打包收集，不处理 QMutex 内部同步警告，也不宣称已修复部分视频黑屏。

## 完整 AppRun

输入法继续使用已实测的 IBus Portal 组合；视频设置的保留不等于确认已修复部分视频黑屏。既有详细记录见 [README](../README.md)。

```bash
# 在 AppDir 根目录创建完整的 AppRun 启动脚本。
cat > "$APPDIR/AppRun" <<'APPRUN'
#!/usr/bin/env bash

# 启用严格模式，在命令执行失败、引用未定义变量或管道执行失败时退出。
set -Eeuo pipefail

# 获取脚本所在目录的绝对路径。
HERE="$(dirname "$(readlink -f "${0}")")"

# 设置简体中文界面环境。
export LANG=zh_CN.UTF-8
export LANGUAGE=zh_CN:zh

# 设置程序、运行库和共享数据的搜索路径。
export PATH="$HERE/opt/XnView:$HERE/usr/bin${PATH:+:$PATH}"
export LD_LIBRARY_PATH="$HERE/opt/XnView/lib:$HERE/usr/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export XDG_DATA_DIRS="$HERE/usr/share${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"

# Qt 运行环境：指定插件、QML 模块和翻译资源的搜索目录。
export QT_PLUGIN_PATH="$HERE/opt/XnView/lib:$HERE/usr/plugins${QT_PLUGIN_PATH:+:$QT_PLUGIN_PATH}"
export QML_IMPORT_PATH="$HERE/opt/XnView/qml${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}"
export QML2_IMPORT_PATH="$HERE/opt/XnView/qml${QML2_IMPORT_PATH:+:$QML2_IMPORT_PATH}"
export QT_TRANSLATIONS_PATH="$HERE/usr/translations${QT_TRANSLATIONS_PATH:+:$QT_TRANSLATIONS_PATH}"

# 设置界面自动缩放。
export QT_AUTO_SCREEN_SCALE_FACTOR=1

# 使用 XCB 后端，并通过包内 IBus 插件和 IBus Portal 接入 Fcitx5。
export QT_QPA_PLATFORM=xcb
export QT_IM_MODULE=ibus
export QT_IM_MODULES=ibus
export IBUS_USE_PORTAL=1

# 禁用多媒体硬件纹理转换。
export QT_DISABLE_HW_TEXTURES_CONVERSION=1

# 设置界面字体 DPI。
export QT_FONT_DPI=96

# 启动包内程序，并保留传入的命令行参数。
exec "$HERE/opt/XnView/XnView" "$@"
APPRUN

# 为启动脚本添加执行权限。
chmod +x "$APPDIR/AppRun"
```

## 核心打包

系统 qmake 误加载包内 Qt 的历史依据见 README 中的隔离记录。此处保留用户确认的完整代码，不另行加入构建库路径，也不改动 linuxdeploy 命令中的其他参数。

```bash
# 创建独立的 Qt 查询工具入口，避免应用自带运行库影响系统工具。
cat > "$TOOLS_DIR/qmake6" <<'EOF_QMAKE'
#!/usr/bin/env bash

# 清除运行库搜索路径。
unset LD_LIBRARY_PATH

# 启动系统工具，并保留传入的命令行参数。
exec /usr/bin/qmake6 "$@"
EOF_QMAKE

# 为工具入口添加执行权限。
chmod +x "$TOOLS_DIR/qmake6"

# 指定 Qt 查询工具。
export QMAKE=qmake6

# 再次运行 linuxdeploy，部署运行资源并生成中间 AppImage。
export ARCH=x86_64; linuxdeploy --appdir AppDir --icon-file "$ICON_FILE" --plugin qt --output appimage
```

## 本次决定与验证范围

本次按用户确认的完整脚本和四条注释写入；不使用 Docker，不调用 normalize_apprun_paths.sh，不改写已确认的 AppRun 可执行内容，不修改 Joplin、公共脚本或 workflow。

主脚本、AppRun 和 qmake6 入口均通过 Bash 语法检查；同时检查固定注释、调用路径、引号、执行顺序和完整 diff。未在宿主环境安装依赖、运行应用或试打包，不以语法检查代替本次 Actions 构建结果。

固定路径与参数的取值依据见 [固定配置](./hardcoded.md)。
