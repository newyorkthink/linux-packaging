# Rofi AppImage

## 用途与产物

本目录使用 Arch Linux 官方仓库中的 `rofi` 与现有 `rofi-emoji` 依赖，通过 quick-sharun 生成 `rofi.AppImage`。现有产物同时包含 `rofi-sensible-terminal` 与 `rofi-theme-selector`。

正式构建由 `.github/workflows/build.yml` 的 `Build Rofi` Job 完成。

## 版本元数据

构建时从当前实际安装的 Arch `rofi` 包读取版本，去掉仅用于 Arch 打包排序的 epoch 与 pkgrel；最终 AppImage 成功生成后写入 `rofi/dist/version.txt`。

workflow 将其上传为 `software-version-rofi`，成功构建后增量写入 `latest/software_versions.json`。

## 维护说明

- 构建脚本已对齐标准模板 [arch-native.sh](../templates/quick-sharun/arch-native.sh)，统一通过 `common/` 公共脚本完成安装、工作区准备与版本读写。
- 保留 `STARTUPWMCLASS="rofi"`、`DEPLOY_OPENGL=1`、原有 `rofi-emoji` 依赖及 3 个 Rofi 辅助程序入口；并从 [pkgforge-dev/rofi-AppImage](https://github.com/pkgforge-dev/rofi-AppImage)（固定提交 `84953049a6ef24a02b722e4072c6dbc3e8d4fca9`）原样复用独立运行 hook [rofi-datadir.src.hook](./rofi-datadir.src.hook)（官方未说明原因，按源码用于补充 `XDG_DATA_DIRS` 并在首次运行时复制包内内置主题）。
- 上游 `URUNTIME_PRELOAD=1`、源码编译、`get-debloated-pkgs` 及 `self-updater.hook`/`UPINFO` 当前未启用；完整采用与未采用记录见 [上游打包差异](./docs/pkgforge-differences.md) 与 [模板差异说明](./docs/template-deviations.md)。
- 版本值来自本次实际安装的软件包，不手工写死，版本元数据接入不改变最终资产名 `rofi.AppImage`。

## 修改记录

### 2026-11-26：按标准模板重写 `build_rofi.sh` 并复用上游主题 hook

- 核实 `pkgforge-dev/rofi-AppImage` 最新固定提交 `84953049a6ef24a02b722e4072c6dbc3e8d4fca9` 及 Arch 官方 `extra/rofi` 原生包来源。
- 按 [arch-native.sh](../templates/quick-sharun/arch-native.sh) 重写 [build_rofi.sh](./build_rofi.sh)，统一接入公共安装、工作区与版本脚本；保留 `STARTUPWMCLASS="rofi"` 与 `DEPLOY_OPENGL=1`，新增原样复用的 [rofi-datadir.src.hook](./rofi-datadir.src.hook)，并补充 [上游打包差异](./docs/pkgforge-differences.md) 与 [模板差异说明](./docs/template-deviations.md)。
- 本次仅做静态核对，提交后按仓库规则不主动监控 Actions。

### 2026-09-16：接入统一软件版本元数据

- 增加最终 AppImage 存在性构建守卫，并在成功后输出 `dist/version.txt`。
- workflow 接入 `SOFTWARE_KEY=rofi` 与统一 `software_versions.json`。
- 本次仅做静态核对，提交后按仓库规则不主动监控 Actions。
