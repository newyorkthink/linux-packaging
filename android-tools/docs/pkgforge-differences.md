# Android Tools 与 pkgforge-dev 打包的取舍

本文记录 [当前构建脚本](../build_android-tools.sh) 与 pkgforge-dev 上游实现的对应关系、实际采用的代码、未启用处理及其依据。本文是维护记录，不参与打包，也不授权恢复未采用的功能。

## 来源与核实范围

- 上游打包仓库：[pkgforge-dev/android-tools-AppImage](https://github.com/pkgforge-dev/android-tools-AppImage)，固定提交 `984ef55eec0461c370c728353405c36a9ce6839e`。[依赖准备](https://github.com/pkgforge-dev/android-tools-AppImage/blob/984ef55eec0461c370c728353405c36a9ce6839e/get-dependencies.sh)、[封装脚本](https://github.com/pkgforge-dev/android-tools-AppImage/blob/984ef55eec0461c370c728353405c36a9ce6839e/make-appimage.sh)、[Actions](https://github.com/pkgforge-dev/android-tools-AppImage/blob/984ef55eec0461c370c728353405c36a9ce6839e/.github/workflows/appimage.yml) 和 [PATH hook](https://github.com/pkgforge-dev/android-tools-AppImage/blob/984ef55eec0461c370c728353405c36a9ce6839e/AppDir/bin/make-symlinks-in-path.hook) 已逐项核对；当前上游 `main` 的依赖准备和封装脚本仍保留这些对应命令。
- 应用二进制来自 [Google 官方 Platform Tools ZIP](https://dl.google.com/android/repository/platform-tools-latest-linux.zip)，而不是 pkgforge-dev 编译的程序，也不是系统安装的 Arch `android-tools` 包。
- 本仓库保留上游的 `AppDir/.DirIcon`、`AppDir/android-tools.png`、`AppDir/bin/make-symlinks-in-path.hook` 和 `LICENSE`。其中 `LICENSE` 是上游打包仓库的 GPL-3.0 许可证文本，不代表 Google 二进制使用同一许可证。
- 已有的构建失败及修复结果见 [应用 README](../README.md#修复记录)，实机结果见 [运行与兼容说明](../README.md#运行与兼容说明)。固定提交用于追溯源码，不锁定实际程序版本。

## 当前取舍

| 处理 | 决定 | 对应代码 | 当前依据、用途与影响 |
| --- | --- | --- | --- |
| 构建容器与精简 | 采用精简命令，保留本仓库的依赖恢复 | `get-debloated-pkgs --add-common --prefer-nano ! mesa ! vulkan`；其后原样执行本仓库既有 `yay -S --noconfirm ...` 命令 | 上游仅将该阶段标为精简包安装，未说明排除 Mesa、Vulkan 的逐项原因。本仓库旧版采用该命令；历史记录证明精简后必须恢复 `unzip`、`patchelf` 等工具。此处仅影响 Actions 构建容器。 |
| 软件来源与解压 | 采用官方 ZIP，改用本仓库公共下载和解压入口 | `common/download/download_file.sh`、`common/archive/extract_archive.sh`；原 ZIP 地址见下 | 保留 Google 最新 Linux Platform Tools 来源及完整文件，不再在应用脚本中重复实现 `wget`、`unzip`。没有固定版本号。 |
| 目录与图标 | 保留上游独立文件，调整清理范围以免删除它们 | `AppDir/.DirIcon`、`AppDir/android-tools.png`、`AppDir/bin/make-symlinks-in-path.hook` | `.DirIcon` 用于 AppImage 图标；PNG 是同一图标资源；PATH hook 支持将 `adb`、`fastboot` 等命令链接到一个 AppImage。清理时只保留已确认的 hook。 |
| 主入口与收集 | 沿用上游入口及收集方式 | `export MAIN_BIN=adb`、`export DESKTOP=DUMMY`、`quick-sharun ./AppDir/bin/*`、`quick-sharun --make-appimage` | 主程序是 `adb`；上游以 dummy desktop 处理无图形界面的命令行程序，并收集整个已准备的工具集合。 |
| 输出名称和更新信息 | 使用本仓库现有固定资产名与 Release 信息 | `export APPNAME=android-tools`、`export OUTNAME=android-tools.AppImage`、`export UPINFO="gh-releases-zsync|${GITHUB_REPOSITORY%/*}|${GITHUB_REPOSITORY#*/}|latest|android-tools.AppImage.zsync"` | 上游使用 `Android_Tools` 和通配 zsync 文件名；本仓库统一为现有产物名。设置 `UPINFO` 只写入更新元数据，不表示启用了运行时自动更新 hook。 |
| 版本读取 | 保留动态版本来源，采用本仓库原有解析方式 | 从 `AppDir/bin/source.properties` 读取 `Pkg.Revision`；最终使用 `common/build/save_appimage_version.sh` | 上游直接将 `awk` 输出写到构建环境的 `~/version`；本仓库从同一官方属性文件读取实际版本，检查非空后保存到 `dist/version.txt`。 |
| udev 自动安装与权限变更 | 未启用 | 上游 `ADD_HOOKS`、udev 规则下载和修改用户组的命令；见下 | 上游以“add udev rules”标注操作，未解释每个权限修改的必要性。本仓库已有启动弹窗的实际记录；去除后实机 `adb` 正常。 |
| 上游测试及发布流程 | 未启用 | `quick-sharun --simple-test ./dist/*.AppImage` 和独立上游 workflow | 本仓库不把测试代码放进正式构建脚本，继续使用现有 GitHub Actions 构建与发布流程，不额外引入上游发布任务。 |

## 上游原文与本仓库对应代码

### 精简与官方二进制

上游 `get-dependencies.sh` 使用的命令：

```sh
get-debloated-pkgs --add-common --prefer-nano ! mesa ! vulkan
BINARY_SOURCE="https://dl.google.com/android/repository/platform-tools-latest-linux.zip"
wget --retry-connrefused --tries=30 "$BINARY_SOURCE" -O ./bin.zip
unzip ./bin.zip
```

本仓库逐字保留第一条精简命令，改由公共入口完成同一地址的下载与 ZIP 解压。精简后恢复基础包的命令来自本仓库已有修复记录，不冒称上游提供该补充命令。

### 封装与更新

上游 `make-appimage.sh` 的相关原文：

```sh
export DESKTOP=DUMMY
export MAIN_BIN=adb
export APPNAME=Android_Tools
quick-sharun ./AppDir/bin/*
quick-sharun --make-appimage
quick-sharun --simple-test ./dist/*.AppImage
```

其中 `DESKTOP`、`MAIN_BIN`、两条 `quick-sharun` 命令继续采用；`APPNAME` 按本仓库的已有命名保留为 `android-tools`，测试命令未启用。

### udev 自动安装（未启用）

上游命令包含：

```sh
export ADD_HOOKS="udev-installer.hook"
UDEV_RULES="https://raw.githubusercontent.com/M0Rf30/android-udev-rules/refs/heads/main/51-android.rules"
wget --retry-connrefused --tries=30 "$UDEV_RULES" -O ./AppDir/etc/udev/rules.d/51-android.rules
```

上游随后还修改 `udev-installer.hook`，加入 `adbusers` 用户组的创建与成员调整；完整原文见上述固定提交的 `make-appimage.sh`。本仓库不设置 `ADD_HOOKS`、不下载该规则，也不执行用户组修改。上游未给出这些操作全部必要性的逐项说明；本仓库在去除自动安装后已有构建成功及实机验证记录。

本页的“采用”只描述当前已存在的构建代码；静态核对不等同于本次修改后的新一次构建或实机验证。
