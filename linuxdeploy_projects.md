# 使用 linuxdeploy 打包的项目

本文件只记录当前仓库中**构建脚本实际调用 `linuxdeploy`** 的项目。仅在 README、注释或说明文字中出现 `linuxdeploy`，但构建脚本没有实际调用的项目，不计入本清单。

| 项目 | 构建脚本 | 使用方式 |
| --- | --- | --- |
| Alacritty | `alacritty/build_alacritty_linuxdeploy.sh` | linuxdeploy |
| MediaInfo | `mediainfo/build_mediainfo_linuxdeploy.sh` | linuxdeploy |
| PeaZip | `peazip/build_peazip.sh` | linuxdeploy + Qt 插件 |
| XnConvert | `xnconvert/build_xnconvert.sh` | linuxdeploy + Qt 插件 |
| Joplin | `joplin/build_joplin.sh` | linuxdeploy + GTK 插件 |
| XnView MP | `xnviewmp/build_xnviewmp.sh` | linuxdeploy + Qt 插件 |
| Poppler Utils | `poppler-utils/build_poppler-utils.sh` | linuxdeploy |
| Remmina | `remmina/build_remmina.sh` | linuxdeploy + GTK / GStreamer 插件 |
| dconf Editor | `dconf-editor/build_dconf-editor.sh` | linuxdeploy |
| 百度网盘 | `baidunetdisk/build_baidunetdisk.sh` | linuxdeploy + GTK 插件 |
| Rainlendar2 | `rainlendar2/build_rainlendar2.sh` | linuxdeploy + GTK 插件 |
| RealVNC RVNC Connect | `realvnc-rvnc-connect/build_realvnc-rvnc-connect.sh` | linuxdeploy + GTK 插件 |

## 不计入的已核对项目

- `htop/build_htop.sh`：明确使用 quick-sharun，不使用 linuxdeploy。
- `goldendict-ng/build_goldendict-ng.sh`：只有注释提到 linuxdeploy，构建脚本没有实际调用 linuxdeploy。

> 部分项目使用 linuxdeploy 负责整理 AppDir、收集依赖或调用输入插件，最终 AppImage 仍可能由 appimagetool 单独封装；本清单判断标准是构建流程中是否实际调用 linuxdeploy。
