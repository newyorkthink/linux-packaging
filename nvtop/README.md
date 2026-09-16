# nvtop AppImage

## 用途与产物

本目录使用 Arch Linux 官方仓库中的 `nvtop` 软件包，通过 quick-sharun 生成 `nvtop.AppImage`。正式构建由 `.github/workflows/build.yml` 的 `Build nvtop` Job 完成。

## 版本元数据

构建时从当前实际安装的 Arch `nvtop` 包读取版本，去掉仅用于 Arch 打包排序的 epoch 与 pkgrel；最终 AppImage 成功生成后写入 `nvtop/dist/version.txt`。

workflow 将其上传为 `software-version-nvtop`，成功构建后增量写入 `latest/software_versions.json`。

## 维护说明

- 保持现有 quick-sharun 打包方式及依赖集合。
- 版本值来自本次实际安装的软件包，不手工写死。
- 版本元数据接入不改变最终资产名 `nvtop.AppImage`。

## 修改记录

### 2026-09-16：接入统一软件版本元数据

- 增加最终 AppImage 存在性构建守卫，并在成功后输出 `dist/version.txt`。
- workflow 接入 `SOFTWARE_KEY=nvtop` 与统一 `software_versions.json`。
- 本次仅做静态核对，提交后按仓库规则不主动监控 Actions。
