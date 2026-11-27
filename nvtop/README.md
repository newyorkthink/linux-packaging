# nvtop AppImage

## 用途与产物

本目录使用 Arch Linux 官方仓库中的 `nvtop` 软件包，通过 quick-sharun 生成 `nvtop.AppImage`。正式构建由 `.github/workflows/build.yml` 的 `Build nvtop` Job 完成。

## 版本元数据

构建时从当前实际安装的 Arch `nvtop` 包读取版本，去掉仅用于 Arch 打包排序的 epoch 与 pkgrel；最终 AppImage 成功生成后写入 `nvtop/dist/version.txt`。

workflow 将其上传为 `software-version-nvtop`，成功构建后增量写入 `latest/software_versions.json`。

## 维护说明

- 构建脚本已对齐标准模板 [arch-native.sh](../Templates/quick-sharun/arch-native.sh)，统一通过 `common/arch/install_packages.sh`、`common/build/prepare_x86_64_workspace.sh`、`common/build/read_app_version.sh` 和 `common/build/save_appimage_version.sh` 执行安装、工作区清理与版本处理。
- 保持原有 quick-sharun 打包方式及全部运行依赖覆盖（`--base` 未覆盖的 `ncurses`、`systemd-libs`、`systemd`、`gtest` 显式保留在应用安装行）。
- 版本值来自本次实际安装的软件包，不手工写死。
- 版本元数据接入不改变最终资产名 `nvtop.AppImage`。

## 修改记录

### 2026-11-26：按标准模板重写 `build_nvtop.sh`

- 核实 `pkgforge-dev` 无 `nvtop` 仓库，确认沿用 Arch 官方 `extra/nvtop` 原生包路线。
- 按 [arch-native.sh](../Templates/quick-sharun/arch-native.sh) 重写 [build_nvtop.sh](./build_nvtop.sh)，去除脚本内直接 `yay`/`pacman -Q`/`rm -rf` 写法，统一接入公共安装、工作区与版本脚本；无模板外专属差异。
- 本次仅做静态核对，提交后按仓库规则不主动监控 Actions。

### 2026-09-16：接入统一软件版本元数据

- 增加最终 AppImage 存在性构建守卫，并在成功后输出 `dist/version.txt`。
- workflow 接入 `SOFTWARE_KEY=nvtop` 与统一 `software_versions.json`。
- 本次仅做静态核对，提交后按仓库规则不主动监控 Actions。

## 实机验证

### 2026-11-27：用户实机验证通过

用户已确认 nvtop `3.4.0` 实机验证通过。

| 实测项目 | 通过结果 |
| --- | --- |
| Linux 实机获取与校验 | `nvtop.AppImage`（`3.4.0`）下载完成并通过 SHA-256 校验。 |
| 终端启动与多卡监控 | 正常启动并识别双显卡设备，实时显示显卡占用与显存曲线及图形进程列表。 |
