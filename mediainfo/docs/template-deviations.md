# MediaInfo 专属差异

本目录是 CLI / 无框架插件类型标准参考。Ubuntu 仓库来源的同版本解包使用公共入口；以下桌面资源处理只说明当前 MediaInfo 包的需要，不作为其他 CLI 程序的默认步骤。

| 位置 | 处理及原因 | 代码或依据 |
| --- | --- | --- |
| 应用来源 | 安装 Ubuntu 仓库的 `mediainfo`，再下载已安装的同一版本 DEB 解包到 AppDir。版本号由公共入口返回。 | [APT 解包入口](../build_mediainfo_linuxdeploy.sh#L32) |
| 官方 SVG | CLI 包没有自带图标，下载官方 SVG 供桌面入口和封装使用。 | [图标准备](../build_mediainfo_linuxdeploy.sh#L36) |
| desktop | 检查包内入口；缺失时生成 `Terminal=true` 的入口，唯一时复用，多个时明确失败，再将选定入口放入 AppDir。 | [桌面入口处理](../build_mediainfo_linuxdeploy.sh#L39) |
| SVG 转换依赖 | `librsvg2-bin` 提供公共最终封装所需的转换工具；保留原 SVG，不把转换程序额外复制进 AppDir。 | [appimagetool 图标说明](../../docs/appimagetool-icon-compatibility.md) |
| AppRun | 保留三个基础搜索目录，直接启动 `usr/bin/mediainfo`，不启用 GTK / Qt 插件。 | [完整 AppRun](../build_mediainfo_linuxdeploy.sh#L65) |

## 专属注释原文

以下原文只随当前包的桌面资源处理使用，不加入公共注释表：

- `# MediaInfo CLI 包没有自带图标，下载官方 SVG 到 AppDir，供桌面入口和最终封装使用。`
- `# 检查 MediaInfo CLI 包中的桌面入口，仅在缺失时生成支持终端运行的入口。`
- `# 将选定的桌面入口放入 AppDir。`

缺包故障及验证范围见 [README](../README.md#修复--变更记录)。APT 同版本解包注释属于公共用途，已收录到固定注释表。
