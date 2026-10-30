# OBS Studio AppImage

## 用途与产物

本目录把 Arch Linux 仓库中的 OBS Studio 与 Browser Source 等运行组件封装为 x86_64 AppImage，稳定产物名为 `obs-studio.AppImage`。上游应用版本由构建时实际安装的 `obs-studio` 软件包动态取得。

## 技术栈与打包方式

OBS Studio 为 Qt 6 / C++ 桌面应用。安装 Arch 官方软件包后，原样复用 [pkgforge-dev 的收集命令](https://github.com/pkgforge-dev/OBS-Studio-AppImage/blob/8c17c157a498876f75b84cb0a30307aba641b396/make-appimage.sh)，同次收集系统中的 OBS 程序、模块、libobs、CEF 和 LuaJIT。当前 `/usr/lib/obs*` 包含模块与 Python 脚本模块目录；`/usr/share/obs` 由 quick-sharun 的同名数据目录扫描收集。后者是依据工具源码作出的判断，不作为新产物已验收的结论。

同时原样采用官方的 `DEPLOY_SDL=1` 和 `PATH_MAPPING_HARDCODED='libobs.so*'`，分别强制部署 SDL 相关运行库、按文件名指定 libobs 的硬编码路径处理。官方未说明这两项设置的具体原因；本次按已明确选择的官方配置接入，工具行为和影响见 [官方处理取舍](./docs/pkgforge-differences.md)。

脚本保留包内中文环境和 `DEPLOY_QT=1`，由 quick-sharun 收集已安装的 Qt 6 输入模块并生成 AppRun，不写启动包装。当前未启用 `self-updater.hook`，也不显式设置 `UPINFO`。

脚本安装 `qt6ct`、`kvantum` 和 `lxqt-qtplugin`，由 quick-sharun 收集对应的 Qt 6 主题插件。

这三个主题插件包必须保留；缺少插件时的红字属于主题支持警告，完整原文见 [Qt 主题插件说明](../docs/packaging-cases/quick-sharun.md#qt-主题插件警告)。当前结构与既有专属处理见 [模板差异](./docs/template-deviations.md)。

相关路径的用途和原始故障记录见 [OBS Studio 写死的路径](./docs/hardcoded.md)。

## 版本元数据

`build_obs-studio.sh` 在第一次 quick-sharun 之前，通过 `common/build/read_app_version.sh pacman obs-studio` 读取实际安装版本，去掉 epoch 和 pkgrel，保存到 `VERSION`。最终 AppImage 成功生成后，单行调用 `common/build/save_appimage_version.sh` 写入：

```text
dist/version.txt
```

统一 workflow 在成功构建后上传 `software-version-obs-studio`，当前 Build 再使用 `obs-studio.AppImage` 的 Release SHA-256 更新 `software_versions.json`。

## 构建与运行

正式构建入口为 `.github/workflows/build.yml`，构建脚本为：

```text
obs-studio/build_obs-studio.sh
```

最终产物发布到 `latest` Release。运行时直接执行：

```bash
./obs-studio.AppImage
```

## 变更记录

### 2026-10-30：复用官方收集命令并修正标准阶段

- 原有问题：版本读取仍位于最终封装之后，使用旧的直接读取入口；收集命令前有重复注释，模板差异文档还把旧版本位置和两行保存写法记为专属处理。
- 修正内容：版本读取移到第一次 quick-sharun 之前，统一使用公共版本入口和 `VERSION`；版本保存改为标准单行调用；应用依赖和收集命令各保留一行用途注释。
- 官方复用：原样采用 `DEPLOY_SDL=1`、`PATH_MAPPING_HARDCODED='libobs.so*'` 和完整的通配收集命令，包括官方原有的参数、制表符、空格、续行和顺序。三个代码块的注释以“复用官方代码：”标明来源。
- CEF 更正：此前“`/usr/lib/cef` 已经不存在”的判断只查看了 `obs-studio` 本身的文件列表，遗漏了独立的 `cef` 依赖包。当前 `cef` 包实际提供该目录及其数据资源；2026-10-28 记录中的这项判断已被本次核实取代，原始记录仍保留。
- 修改文件：`obs-studio/build_obs-studio.sh`、`obs-studio/README.md`、`obs-studio/docs/template-deviations.md`、`obs-studio/docs/pkgforge-differences.md`、`obs-studio/docs/hardcoded.md`、`docs/packaging-classification.md`、`docs/packaging-export-registry.md`、`anylinux_projects.md`。
- 验证边界：提交前核对 Bash 语法、官方代码原文、相对链接、注释、版本阶段和完整 diff；这些检查不替代新产物的构建或实机验收。未启用自更新 hook，未显式设置 UPINFO，未加入官方测试步骤。

### 2026-10-28：按标准写法重写构建脚本

- 构建失败是因为脚本把已经不存在的 `/usr/lib/obs-plugins` 交给 `quick-sharun`，原文是 `'/usr/lib/obs-plugins' is NOT present!`。OBS 33.0.0 的模块在 `/usr/lib/obs-modules`。
- 删掉安装后和打包后的一串存在性检查、自定义启动包装，以及已经不存在的 `obs-studio-plugin-browser`、`/usr/lib/cef`。
- 安装改走 `common/arch/install_packages.sh`。中文环境按规范写 `.env`，不再设置 `LC_ALL`，也不再默认写入 Yami 主题。


### 2026-09-16：接入统一软件版本元数据

- 修改文件：`.github/workflows/build.yml`、本 README。
- 复用既有 `dist/version.txt`，不修改 OBS Studio 构建脚本、运行时逻辑和 Release 资产名。
- 成功构建后由统一汇总流程增量更新 `software_versions.json`；提交后不主动监控 Actions，实际新记录以下一次成功构建为准。

### 2026-09-23：补齐 OBS 独立 Job 的 yay 引导

- 故障现象：OBS Studio 独立 Job 进入构建脚本后报告 Arch 构建环境缺少 `yay`，统一基础包入口无法执行。
- 根因：该独立 Job 使用 AnyLinux v2 准备容器，但没有像同类特例 Job 一样先为 root 构建流程安装 `yay`。
- 修改文件：`.github/workflows/build.yml`、本 README。
- 修复内容：在 OBS Studio 构建步骤之前复用现有的 `yay-bin` 引导步骤；不额外安装 `jq`、`github-cli` 或其他基础包，后续仍由构建脚本调用统一 Arch 基础包入口。
- 已知结果：workflow 结构与同类 Arch 特例 Job 对齐；实际构建结果以下一次 Actions 为准。
