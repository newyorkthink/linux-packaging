# Sunshine AppImage

## 用途与产物

本目录固定使用 Sunshine 官方 GitHub Release `v2025.924.154138` 中的 `sunshine.pkg.tar.zst`，并使用 quick-sharun 打包为 `sunshine.AppImage`。当前不会自动跟随 AUR `sunshine-bin` 或上游 latest；后续需要切换版本时再人工调整固定版本。

## 技术栈

Sunshine 是原生 C / C++ 图形与流媒体应用。当前构建直接使用安装后的 `/usr/bin/sunshine`，同时准备 PipeWire、PulseAudio、VA-API、Vulkan、CUDA、X11、Wayland portal 等运行时依赖。

## 打包方式

- 构建环境：GitHub Actions 的 Arch Linux 容器。
- 上游包：Sunshine 官方 GitHub Release `v2025.924.154138` 的 `sunshine.pkg.tar.zst`。
- 包校验：SHA-256 `2d7be01ffde6fb346c86f102edb5158b513db5f194c0481cd5e782cadafd9c3c`。
- 打包工具：quick-sharun。
- 主程序：`/usr/bin/sunshine`。
- desktop：`/usr/share/applications/dev.lizardbyte.app.Sunshine.desktop`。
- icon：`/usr/share/icons/hicolor/scalable/apps/dev.lizardbyte.app.Sunshine.svg`。
- 最终产物：`dist/sunshine.AppImage`。

## 版本元数据

构建时从本次实际安装的 `sunshine` 包读取版本，去掉 Arch epoch 与 pkgrel 后写入 `dist/version.txt`。workflow 使用 `SOFTWARE_KEY=sunshine` 接入统一版本清单。

## NVIDIA 本地更新注意事项

Sunshine 新版可能随上游 CUDA 构建环境提升最低 NVIDIA 驱动要求；驱动版本低于当前 Sunshine 打包时所用 CUDA 的最低兼容线时，NVENC 初始化会失败。当前构建固定为 Sunshine `2025.924.154138`，不会自动更新到新版；需要调整兼容基线时再人工更新固定版本。

## 变更记录

### 2026-09-17：固定 Sunshine 2025.924.154138 官方包

- 现象：需要暂时保持 Sunshine `2025.924.154138`，避免后续构建自动跟随新版本改变 NVIDIA 驱动兼容要求。
- 根因：原构建通过 AUR `sunshine-bin` 获取当前版本，AUR 更新后会自动改变实际打包的 Sunshine 版本。
- 修改文件：`sunshine/build_sunshine.sh`、`sunshine/README.md`。
- 处理：改为直接下载 Sunshine 官方 GitHub Release `v2025.924.154138` 的 `sunshine.pkg.tar.zst`，按官方 Release digest 校验 SHA-256 后安装，并确认安装版本仍为 `2025.924.154138`；不经过私有归档仓库，也不使用 AUR `sunshine-bin` 选择版本。
- 已知结果：官方固定包的文件大小与 SHA-256 已通过 GitHub Release 元数据核对；脚本已完成仓库外 Bash 语法检查。Actions 构建和 Linux 实机运行尚未验证。

### 2026-09-17：补充 NVIDIA 本地更新兼容说明

- 现象：部分 NVIDIA 环境升级 Sunshine 后可能出现 NVENC 初始化失败。
- 根因：新版 Sunshine 使用的 CUDA 版本可能要求更高的 NVIDIA 驱动。
- 修改文件：`sunshine/README.md`。
- 处理：明确仓库继续跟随最新 Sunshine，不在构建脚本中锁旧版本；旧驱动兼容由用户自行保留旧 AppImage。
- 已知结果：仅文档说明变更，不涉及构建脚本或 AppImage 内容。
