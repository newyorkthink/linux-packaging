# Newsboat AppImage

## 用途与产物

本目录使用 Arch Linux 官方仓库中的 `newsboat` 软件包，通过 quick-sharun 将 `newsboat` 与 `podboat` 封装为 `newsboat.AppImage`，并使用本目录维护的 `newsboat.desktop`。

正式构建由 `.github/workflows/build.yml` 的 `Build Newsboat` Job 完成。本项目采用 [Arch 原生程序系统入口标准](../anylinux_projects.md#arch-官方仓库原生程序系统入口标准)，是同一 Arch 官方包提供两个终端入口时的基础参考。正式产物目录为 `newsboat/dist/`。

## 版本元数据

构建时通过 `read_app_version.sh pacman newsboat` 读取当前安装版本，去掉 epoch 和 pkgrel。封装成功后通过 `save_appimage_version.sh` 检查产物并写入 `newsboat/dist/version.txt`。

workflow 将其上传为 `software-version-newsboat`，成功构建后增量写入 `latest/software_versions.json`。

## 维护说明

- 不改变现有 Newsboat / Podboat 打包范围。
- 应用清单设置 `run_from_root` 为 `"false"`，`artifact_dir` 为 `newsboat/dist`。
- [模板差异](./docs/template-deviations.md)逐项对应脚本注释、入口和模板差异。[固定配置依据](./docs/hardcoded.md)记录依赖、桌面资源和产物路径。
- 版本值来自本次实际安装的软件包，不手工写死。

## 实机验证

**Newsboat r2.45 启动与订阅列表显示实测通过。** 用户实测确认程序能读取已有配置、订阅和文章缓存，终端列表中的中文标题正常显示。

## 修改记录

### 2026-09-16：接入统一软件版本元数据

- 增加最终 AppImage 存在性构建守卫，并在成功后输出 `dist/version.txt`。
- workflow 接入 `SOFTWARE_KEY=newsboat` 与统一 `software_versions.json`。
- 本次仅做静态核对，提交后按仓库规则不主动监控 Actions。

### 对齐 Arch 原生程序系统入口标准

- 通用注释和阶段顺序逐字沿用原生入口模板，保留 `newsboat`、`podboat`、原有依赖和仓库自带的 desktop。
- 版本读取和保存改用公共入口，应用清单与脚本输出目录同步调整。此处记录脚本与清单的静态核对。
