# OBS Studio 官方处理取舍

本页记录本次选择原样复用的 pkgforge-dev 代码、保留的本仓库标准步骤，以及明确未启用的官方内容。官方原始理由与依据源码分析得到的作用分别说明，不把代码存在当作所有程序均应采用的依据。

## 来源

- 官方仓库：`pkgforge-dev/OBS-Studio-AppImage`。
- 固定源码：[`make-appimage.sh`，commit `8c17c157a498876f75b84cb0a30307aba641b396`](https://github.com/pkgforge-dev/OBS-Studio-AppImage/blob/8c17c157a498876f75b84cb0a30307aba641b396/make-appimage.sh)。
- 同一快照的依赖与构建环境：[`get-dependencies.sh`](https://github.com/pkgforge-dev/OBS-Studio-AppImage/blob/8c17c157a498876f75b84cb0a30307aba641b396/get-dependencies.sh)、[`.github/workflows/appimage.yml`](https://github.com/pkgforge-dev/OBS-Studio-AppImage/blob/8c17c157a498876f75b84cb0a30307aba641b396/.github/workflows/appimage.yml)。
- 工具行为：[`quick-sharun.sh`，commit `862becf483277b2d2576cbc3fec6284489efd4ea`](https://github.com/pkgforge-dev/Anylinux-AppImages/blob/862becf483277b2d2576cbc3fec6284489efd4ea/useful-tools/quick-sharun.sh)。

官方未逐项说明本次采用的两项 export 和各个收集参数的原始原因。以下作用说明来自工具源码、官方软件包文件列表及本仓库已有故障记录，不冒充官方作者解释，也不作为新产物已验收的结论。

## 采用与未采用

| 处理 | 决定 | 对应代码 | 当前依据、用途与影响 |
| --- | --- | --- | --- |
| 安装应用和运行依赖 | 保留标准公共入口；官方直接包管理器命令未启用。 | [安装代码](#标准安装与版本步骤)，[基础包入口](../build_obs-studio.sh#L11)、[应用安装](../build_obs-studio.sh#L13)。 | 安装基础包及现有精确依赖，保留 Qt 6 输入与主题插件；不复制官方的系统升级和瘦身包安装流程。 |
| OpenGL、PipeWire、Python 部署 | 保留现有三项配置，与官方取值相同。 | `export DEPLOY_OPENGL=1`、`export DEPLOY_PIPEWIRE=1`、`export DEPLOY_PYTHON=1`；[OpenGL](../build_obs-studio.sh#L30)、[PipeWire](../build_obs-studio.sh#L32)、[Python](../build_obs-studio.sh#L34)。 | 保留既有部署范围，本次不改写原有命令。 |
| Qt 部署 | 保留本仓库现有配置。 | `export DEPLOY_QT=1`，[构建位置](../build_obs-studio.sh#L36)。 | 当前程序使用 Qt 6，保留原有输入模块和主题插件收集方式。 |
| SDL 部署 | 采用，原样复用官方代码。 | [部署代码](#部署配置)，[构建位置](../build_obs-studio.sh#L38)。 | 强制启用 SDL 部署分支；官方未说明原因，本次按明确选定的官方配置接入，不声称此前已发生 SDL 缺失故障。 |
| 指定 libobs 路径处理 | 采用，原样复用官方代码。 | [部署代码](#部署配置)，[构建位置](../build_obs-studio.sh#L40)。 | 按文件名指定 libobs 的硬编码路径处理；官方未说明原因，范围与副作用见下节。 |
| 完整程序与运行资源收集 | 采用，原样复用官方代码。 | 本页 [完整收集命令](#收集命令)，[构建位置](../build_obs-studio.sh#L46)。 | 同次收集 OBS 程序、模块、libobs、CEF 和 LuaJIT；当前 `/usr/lib/obs*` 覆盖模块与脚本模块，CEF 来自独立依赖包。 |
| OBS 共享数据目录 | 采用工具的标准数据目录扫描。 | 由同一次收集命令执行，[构建位置](../build_obs-studio.sh#L46)；工具中的 `_deploy_datadirs` 默认启用。 | 工具按程序名扫描数据目录，当前包提供 `/usr/share/obs`。这是源码层面的覆盖判断，不代表已经核对新产物。 |
| 版本读取与保存 | 官方直接解析版本命令未启用，使用本仓库标准入口。 | [版本代码](#标准安装与版本步骤)，[读取](../build_obs-studio.sh#L43)、[保存](../build_obs-studio.sh#L67)。 | 依赖收集前读取实际安装版本，去掉 epoch 和 pkgrel；最终产物成功生成后单行保存版本。 |
| 最终封装 | 保留标准步骤，与官方命令相同。 | `quick-sharun --make-appimage`，[构建位置](../build_obs-studio.sh#L64)。 | 由工具封装最终 AppImage，不自写 AppRun。 |
| 显式 APPNAME | 未启用官方命令。 | 未启用 `export APPNAME=OBS_Studio`。 | 保留当前 ICON、DESKTOP、OUTPATH、OUTNAME 配置，不额外改变名称。 |
| 显式 DEPLOY_LOCALE | 未启用官方命令。 | 未启用 `export DEPLOY_LOCALE=1`；现有中文环境位于 [构建脚本](../build_obs-studio.sh#L54)。 | 工具默认部署 locale，包内中文 locale 与 .env 沿用原有实现。 |
| self-updater 与 UPINFO | 未启用自更新 hook，未显式设置更新信息。 | 未启用，原文见 [未启用的官方原文](#未启用的官方原文)。 | 按本次选择不加入自更新配置；工具在 CI 中可能推断 UPINFO，这不会自动加入 self-updater hook。 |
| 上游测试步骤 | 未启用。 | 未启用 `quick-sharun --test ./dist/*.AppImage`。 | 正式构建不新增测试步骤；本次检查限于获准的提交前静态核对。 |

## 部署配置

本次选定的官方原文如下；在当前构建脚本中分别位于 [SDL 配置](../build_obs-studio.sh#L38) 与 [libobs 配置](../build_obs-studio.sh#L40)，用途注释与规范表一致。

```bash
# 复用官方代码：部署 SDL 运行库。
export DEPLOY_SDL=1
# 复用官方代码：映射指定库中的硬编码系统路径。
export PATH_MAPPING_HARDCODED='libobs.so*'
```

`DEPLOY_SDL=1` 强制进入工具的 SDL 部署分支，收集构建环境中已有的 SDL、udev、USB 和窗口装饰相关库，并启用对应通用依赖处理。检测到 SDL 库时工具也可自动启用部署。该开关不负责另行安装 SDL 软件包，也不证明此前存在 SDL 缺失故障。

`PATH_MAPPING_HARDCODED='libobs.so*'` 按文件名匹配包内库。工具尝试将匹配库中的 `/usr/bin`、`/usr/lib`、`/usr/share` 改写为生成的临时路径，并由工具生成的 hook 建立指向包内目录的链接。因此它影响包内二进制和运行时临时目录链接，不只是一般环境设置；本仓库不手写替代补丁或 hook。

当前工具也有自动路径检查。本次显式配置来自明确选定的官方实现，不把自动检查存在写成该开关永远无用，也不把官方设置了写成已经实测证明当前必须设置。

## 收集命令

以下为官方完整原文，在 [构建脚本](../build_obs-studio.sh#L46) 中逐字保留，包括参数、制表符、空格、续行和顺序。

```bash
# 复用官方代码：收集程序及其运行依赖。
quick-sharun \
	/usr/bin/obs*    \
	/usr/lib/obs*    \
	/usr/lib/libobs* \
	/usr/lib/cef     \
	/usr/lib/libluajit*.so*
```

Arch 官方 `obs-studio` 依赖 `cef` 和 `luajit`。当前 `cef` 包提供 `/usr/lib/cef`，包含 `libcef.so`、`icudtl.dat`、语言包等资源；不能只查看 `obs-studio` 自己的文件列表就判断该目录不存在。

当前包文件列表：[OBS Studio](https://archlinux.org/packages/extra/x86_64/obs-studio/files/)、[CEF](https://archlinux.org/packages/extra/x86_64/cef/files/)。原有路径故障和 Python 脚本模块错误原文继续保存在 [路径记录](./hardcoded.md)。

## 标准安装与版本步骤

以下是本仓库的标准集成代码，不冒称官方原命令；各段按实际构建阶段分别执行。

安装入口：

```bash
# 打包工具。GTK、输入法不要塞进这一行。
"$SCRIPT_DIR/../common/arch/install_packages.sh" --base
# 安装官方软件包及运行依赖。
"$SCRIPT_DIR/../common/arch/install_packages.sh" obs-studio fcitx5-qt qt6ct kvantum lxqt-qtplugin
```

第一次 quick-sharun 之前读取版本：

```bash
# 读取本次打包使用的版本。
VERSION="$("$SCRIPT_DIR/../common/build/read_app_version.sh" pacman obs-studio)"
```

依赖收集和现有中文环境处理完成后封装：

```bash
# 把 AppDir 打成 AppImage。
quick-sharun --make-appimage
```

最终 AppImage 成功生成后保存版本：

```bash
# 打包成功后用公共脚本记下版本。
"$SCRIPT_DIR/../common/build/save_appimage_version.sh" dist/obs-studio.AppImage "$VERSION" dist/version.txt
```

## 未启用的官方原文

下列代码仅保存来源和取舍依据，不在当前构建脚本执行：

```bash
VERSION=$(pacman -Q obs-studio | awk '{print $2; exit}') # example command to get version of application here
export ADD_HOOKS="self-updater.hook"
export UPINFO="gh-releases-zsync|${GITHUB_REPOSITORY%/*}|${GITHUB_REPOSITORY#*/}|latest|*$ARCH.AppImage.zsync"
export APPNAME=OBS_Studio
export DEPLOY_LOCALE=1
quick-sharun --test ./dist/*.AppImage
```

UPINFO 是 AppImage 的更新来源元数据，用于指明 GitHub Release 和对应的 zsync 资源；它不是应用版本读取接口，也不等同于启用 self-updater hook。本次不显式设置它。

## 验证边界

本次按官方固定源码核对原文，并检查本仓库的 Bash 语法、代码位置、固定注释、链接和完整 diff。新产物的构建、包内实际资源与运行功能不由这些静态核对证明；已有故障历史和当前运行状态以 [README](../README.md) 为准。
