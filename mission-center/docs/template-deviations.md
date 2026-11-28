# Mission Center 模板差异说明

## 标准底稿与来源核实

- **标准模板**：[arch-native.sh](../../Templates/quick-sharun/arch-native.sh)
- **构建脚本**：[build_mission-center.sh](../build_mission-center.sh)
- **上游核实**：在 `pkgforge-dev` 组织检索 `mission-center`、`missioncenter` 均返回空；[Anylinux-AppImages#330](https://github.com/pkgforge-dev/Anylinux-AppImages/issues/330) 已关闭（因上游 `mission-center-devs/mission-center` 直接在源码仓库接入 `quick-sharun`）。Arch Linux 官方 `extra` 仓库提供原生二进制包 `mission-center` 与 `fcitx5-gtk`，适用 Arch 官方仓库原生程序系统入口路线。

## 依赖覆盖核对

对照 [install_packages.sh](../../Common/arch/install_packages.sh#L427-L440) 的 `--base` 清单与原有构建脚本：

- **`--base` 已覆盖（3 项）**：`gettext`、`patchelf`、`zsync`（及 `localedef`、`ibus` 等基础工具）。
- **在 [build_mission-center.sh](../build_mission-center.sh#L13) 显式保留（2 项）**：`"mission-center"` 与 `fcitx5-gtk`；应用不再手写 `pacman -Syu`。

## 当前启用的模板差异

| 差异项 | 所在位置 | 来源与用途说明 |
| --- | --- | --- |
| `DEPLOY_GTK=1`、`GTK_DIR=gtk-4.0`、`DEPLOY_LOCALE=1` | [build_mission-center.sh](../build_mission-center.sh#L29-L34) | 本程序专属处理：保留既有配置，显式启用 GTK4、指定 `gtk-4.0` 目录并强制部署翻译资源；与 [导出注册表](../../Docs/packaging-export-registry.md) 登记项一致。 |
| 收集主程序与 magpie 后端 | [build_mission-center.sh](../build_mission-center.sh#L40) | 按模板单行传入 `/usr/bin/missioncenter` 与 `/usr/bin/missioncenter-magpie`（同一 Arch 官方包提供）。 |
| GTK4 Fcitx5 GIO 模块缓存 | [build_mission-center.sh](../build_mission-center.sh#L42-L45) | 本仓库兼容处理：当前 `quick-sharun` 仍按 `immodules.cache` 处理 GTK 输入模块缓存（CI Job `140872258325` 日志仍报 `sed: can't read .../gtk-4.0/4.0.0/immodules.cache`），确认包内存在 `libim-fcitx5.so` 后为最终目录写入 `giomodule.cache`（`libim-fcitx5.so: gtk-im-module`）。 |
| 包内中文 locale 与 `.env` | [build_mission-center.sh](../build_mission-center.sh#L47-L55) | 使用公共中文 locale 写法在 `AppDir/lib/locale/zh_CN.utf8` 生成数据并向 `.env` 追加消息环境（`LANGUAGE=zh_CN:zh` 回退匹配上游 `zh/LC_MESSAGES/missioncenter.mo`）。 |

## 整理说明

- 移除旧脚本中的通用 `command -v`、源文件预检、`msgunfmt`、`ldd` 与 `.env` 逐行 `grep` 断言，工作区、版本读取与版本保存统一收口到 `Common/` 公共入口。
- 早期 1.1.0 试验记录（`Samueru-sama/mission-center-appimage-test`）曾手动 `unset APPDIR`；当前 Arch `1.2.0-1` 在 `quick-sharun` 下正常跟踪打包，且 [README](../README.md#2026-09-02修复-gtk4--fcitx5-中文输入) 已有实机正常显示中文界面的依据，不引入额外假设性覆盖。

## 实机验证

实机验证通过记录见 [Mission Center README](../README.md#实机验证)。
