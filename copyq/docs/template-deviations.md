# CopyQ 模板差异

本项目沿用 Arch 官方仓库二进制包和 quick-sharun 路线。公共结构、固定注释及执行顺序对照 [qt-installed.sh](../../templates/quick-sharun/qt-installed.sh) 和 [Qt 程序规范](../../anylinux_projects.md#有窗口的-qt-程序)，并参考 [OBS Studio](../../obs-studio/build_obs-studio.sh)。

| 所在阶段 | 保留或补齐的内容 | 原因与代码 |
| --- | --- | --- |
| 依赖安装 | 基础工具使用公共 `--base` 入口，应用、Qt6 输入与主题插件及原有额外依赖使用同一条公共安装命令。 | 原有 53 个不同软件包均由基础包或应用安装行覆盖，仅合并重复项；[基础包](../build_copyq.sh#L11)、[应用依赖](../build_copyq.sh#L13)。 |
| 打包元数据 | 保留 `STARTUPWMCLASS=copyq`、SVG 图标、desktop、`DEPLOY_OPENGL=1`。 | 沿用原有窗口匹配、图标与 OpenGL 部署配置；[窗口类](../build_copyq.sh#L26)、[OpenGL](../build_copyq.sh#L36)。 |
| Qt6 部署 | 使用标准 `DEPLOY_QT=1`，保留 `fcitx5-qt`、`qt6ct`、`kvantum`、`lxqt-qtplugin`。 | 按当前 Qt6 系统入口模板收集匹配的输入和主题插件；[Qt 配置](../build_copyq.sh#L38)。 |
| 依赖收集 | 原样采用上游 `quick-sharun /usr/bin/copyq /usr/lib/copyq /usr/share/copyq`。 | 同次指定主程序、功能插件和共享资源，详见 [官方处理取舍](./pkgforge-differences.md#完整收集命令)；[收集位置](../build_copyq.sh#L44)。 |
| 中文环境 | 使用 Qt 标准中文 locale 块，追加到已有 `AppDir/.env`。 | locale 数据、语言选择、应用翻译分别准备，不另写启动包装；[中文环境](../build_copyq.sh#L47)。 |
| 功能插件 | 原样保留两个包内位置的 `libitem*.so` 兼容链接循环。 | 旧脚本记录 CopyQ 16 直接从 `lib/copyq` 查找插件，而工具部署到其 `plugins/` 子目录；保留既有修复，见 [固定配置](./hardcoded.md#功能插件兼容路径)；[兼容处理](../build_copyq.sh#L58)。 |
| 翻译目录 | 原样追加 `COPYQ_TRANSLATION_PREFIX=$APPDIR/share/copyq/translations`。 | 沿用已有语言列表与翻译资源定位方式；[翻译设置](../build_copyq.sh#L68)。 |

工作区、版本读取与保存按公共标准执行：在项目目录准备 AppDir 和 dist，收集前读取实际安装版本，最终 AppImage 成功生成后保存去掉 epoch 与 pkgrel 的上游版本。原有版本发布接口保持不变。

原始基线：[9306363 的构建脚本](https://github.com/newyorkthink/linux-packaging/blob/93063635ae4471345e6f406e60079c1546a89e74/copyq/build_copyq.sh)。插件循环与翻译配置的可执行内容从该基线逐字保留，只有对应注释增加专属标识。上游未启用项见 [官方处理取舍](./pkgforge-differences.md)。
