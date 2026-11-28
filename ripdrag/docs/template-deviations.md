# Ripdrag 模板差异

Ripdrag 采用 crates.io 安装并使用 quick-sharun 封装。现有 [Arch 原生模板](../../Templates/quick-sharun/arch-native.sh) 按 Arch 软件包安装程序，再用 pacman 读取版本。Ripdrag 需要从 Cargo 暂存目录扫描程序并读取同一二进制的版本，因此将来源和资源部署保留为应用专属处理。公共阶段沿用模板的调用、注释和空行。[上游安装说明](https://github.com/nik012003/ripdrag#installation)

上游最新正式 Release 未上传 Linux x86_64 二进制。Arch 上游说明列出的 `ripdrag-git` 配方也是从源码编译，现有流程继续使用上游推荐的稳定版 Cargo 安装方式。[上游 Release](https://github.com/nik012003/ripdrag/releases/latest) · [AUR 源码配方](https://github.com/archlinux/aur/blob/ripdrag-git/PKGBUILD)

| 构建阶段 | 专属处理与依据 |
| --- | --- |
| Cargo 安装与版本 | 通过公共 Cargo 入口以 `--locked` 安装至本项目 `source/`。`source/bin/ripdrag` 同时用于版本读取和 quick-sharun 扫描。AppImage 固定命名为 `ripdrag.AppImage`，实际版本按标准收尾写入 `dist/version.txt`。 |
| 桌面资源 | 引用仓库已有的 `resources/ripdrag.desktop` 和 `resources/ripdrag.svg`，沿用 desktop 校验，两份资源从原有构建脚本提取。 |
| 依赖部署 | 保留 `MAIN_BIN=ripdrag` 和 GTK4、GdkPixbuf、Glycin 的部署开关，沿用当前应用的运行依赖。 |
| 运行主题 | 第一轮 quick-sharun 扫描后，将原有 `00-ripdrag-dark-theme.hook` 复制到 `AppDir/bin/`，再执行最终封装。 |

构建产物及验证状态见[应用说明](../README.md)。
