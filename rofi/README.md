# Rofi AppImage

## 用途与产物

本目录使用 Arch Linux 官方仓库中的 `rofi` 与现有 `rofi-emoji` 依赖，通过 quick-sharun 生成 `rofi.AppImage`。现有产物同时包含 `rofi-sensible-terminal` 与 `rofi-theme-selector`。

正式构建由 `.github/workflows/build.yml` 的 `Build Rofi` Job 完成。

## 版本元数据

构建时从当前实际安装的 Arch `rofi` 包读取版本，去掉仅用于 Arch 打包排序的 epoch 与 pkgrel；最终 AppImage 成功生成后写入 `rofi/dist/version.txt`。

workflow 将其上传为 `software-version-rofi`，成功构建后增量写入 `latest/software_versions.json`。

## 维护说明

- 保持现有 `DEPLOY_OPENGL=1`、Rofi 辅助程序和 quick-sharun 打包方式。
- 版本值来自本次实际安装的软件包，不手工写死。
- 版本元数据接入不改变最终资产名 `rofi.AppImage`。

## 修改记录

### 2026-09-16：接入统一软件版本元数据

- 增加最终 AppImage 存在性构建守卫，并在成功后输出 `dist/version.txt`。
- workflow 接入 `SOFTWARE_KEY=rofi` 与统一 `software_versions.json`。
- 本次仅做静态核对，提交后按仓库规则不主动监控 Actions。
