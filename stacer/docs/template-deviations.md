# Stacer 模板差异说明

## 标准底稿与来源核实

- **标准模板**：[qt-installed.sh](../../Templates/quick-sharun/qt-installed.sh)
- **构建脚本**：[build_stacer.sh](../build_stacer.sh)
- **上游核实**：在 `pkgforge-dev` 组织检索 `stacer` 返回空，无官方打包仓库；Arch 官方仓库无 `stacer`，采用 AUR `stacer`（从 `QuentiumYT/Stacer` 官方稳定源码按当前 Arch Qt6 编译）。上游 Ubuntu 22.04（jammy）AppImage 随包携带 glibc 2.35。实机记录中的 `GLIBC_2.38` 缺失出现在该 AppImage 继承其他 AppImage 的库搜索路径时，本仓库沿用 AUR 打包路线。 [Stacer 修复记录](../README.md#修复记录)

## 依赖覆盖核对

对照 [install_packages.sh](../../common/arch/install_packages.sh#L357-L370) 的 `--base` 清单与 [qt-installed.sh](../../Templates/quick-sharun/qt-installed.sh#L13) 内置 Qt6 依赖，原脚本依赖完整覆盖如下：

- **`--base` 已覆盖（23 项）**：`base-devel`、`git`、`wget`、`curl`、`jq`、`binutils`、`patchelf`、`file`、`coreutils`、`findutils`、`grep`、`sed`、`gawk`、`tar`、`gzip`、`xz`、`unzip`、`rsync`、`util-linux`、`appstream-glib`、`desktop-file-utils`、`zsync`、`ca-certificates`。
- **模板固定安装（4 项，[build_stacer.sh](../build_stacer.sh#L13)）**：`fcitx5-qt`、`qt6ct`、`kvantum`、`lxqt-qtplugin`（覆盖原脚本 `fcitx5-qt` 并补齐仓库要求的 Qt6 主题插件）。

## 当前启用的模板差异

| 差异项 | 所在位置 | 原因与影响 |
| --- | --- | --- |
| `export STARTUPWMCLASS="stacer"` | [build_stacer.sh](../build_stacer.sh#L21-L22) | 保留原脚本窗口类设置，使窗口与 desktop 中的 `StartupWMClass` 对应。 |
| 显式收集 `/usr/share/stacer` 并链接翻译目录 | [build_stacer.sh](../build_stacer.sh#L38)、[build_stacer.sh](../build_stacer.sh#L50-L60) | 上游查找翻译的回退路径为 `applicationDirPath()/translations`；打包阶段一并收集 `/usr/share/stacer`，校验 `AppDir/share/stacer/translations` 存在后软链接至 `AppDir/bin/translations`（及存在时的 `AppDir/shared/bin/translations`），缺失时中止构建。 |

## 实机验证

实机验证通过记录见 [Stacer README](../README.md#实机验证)。
