# Newsboat AppImage

## 用途与产物

本目录使用 Arch Linux 官方仓库中的 `newsboat` 软件包，通过 quick-sharun 将 `newsboat` 与 `podboat` 封装为 `newsboat.AppImage`，并使用本目录维护的 `newsboat.desktop`。

正式构建由 `.github/workflows/build.yml` 的 `Build Newsboat` Job 完成。该项目保持现有从仓库根目录运行的方式，产物目录为根目录 `dist/`。

## 版本元数据

构建时从当前实际安装的 Arch `newsboat` 包读取版本，去掉仅用于 Arch 打包排序的 epoch 与 pkgrel；最终 AppImage 成功生成后写入根目录 `dist/version.txt`。

workflow 将其上传为 `software-version-newsboat`，成功构建后增量写入 `latest/software_versions.json`。

## 维护说明

- 不改变现有 Newsboat / Podboat 打包范围。
- 保持 `RUN_FROM_ROOT=true` 与根目录 `dist/` 的既有路径约定。
- 版本值来自本次实际安装的软件包，不手工写死。

## 修改记录

### 2026-09-16：接入统一软件版本元数据

- 增加最终 AppImage 存在性构建守卫，并在成功后输出 `dist/version.txt`。
- workflow 接入 `SOFTWARE_KEY=newsboat` 与统一 `software_versions.json`。
- 本次仅做静态核对，提交后按仓库规则不主动监控 Actions。
