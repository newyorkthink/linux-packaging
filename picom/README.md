# Picom AppImage

## 用途与产物

本目录使用 Arch Linux 官方仓库中的 `picom` 软件包，通过 quick-sharun 生成 `picom.AppImage`。现有打包同时保留 picom / compton 辅助命令、X11 工具和 OpenGL / EGL 相关运行依赖。

正式构建由 `.github/workflows/build.yml` 的 `Build Picom` Job 完成。

## 版本元数据

构建时从当前实际安装的 Arch `picom` 包读取版本，去掉仅用于 Arch 打包排序的 epoch 与 pkgrel；最终 AppImage 成功生成后写入 `picom/dist/version.txt`。

workflow 将其上传为 `software-version-picom`，成功构建后增量写入 `latest/software_versions.json`。

## 维护说明

- 构建脚本已对齐标准模板 [arch-native.sh](../templates/quick-sharun/arch-native.sh)，统一通过 `common/` 公共脚本完成安装、工作区准备与版本读写。
- 保留 `DEPLOY_OPENGL=1`（支持 `xrender`/`glx` 后端）及原有 picom / compton / X11 辅助工具扫描范围；差异与依赖覆盖核对见 [模板差异说明](./docs/template-deviations.md)。
- 版本值来自本次实际安装的软件包，不手工写死。

## 修改记录

### 2026-11-26：按标准模板重写 `build_picom.sh`

- 核实 `pkgforge-dev` 无 `picom`/`compton` 仓库，确认沿用 Arch 官方 `extra/picom` 原生包路线。
- 按 [arch-native.sh](../templates/quick-sharun/arch-native.sh) 重写 [build_picom.sh](./build_picom.sh)，统一接入公共安装、工作区与版本脚本；保留 `DEPLOY_OPENGL=1` 作为应用专属处理，移除已核实与默认值等价的 `APPNAME` 与 `STARTUPWMCLASS`，并新增 [模板差异说明](./docs/template-deviations.md)。
- 本次仅做静态核对，提交后按仓库规则不主动监控 Actions。

### 2026-09-16：接入统一软件版本元数据

- 增加最终 AppImage 存在性构建守卫，并在成功后输出 `dist/version.txt`。
- workflow 接入 `SOFTWARE_KEY=picom` 与统一 `software_versions.json`。
- 本次仅做静态核对，提交后按仓库规则不主动监控 Actions。
