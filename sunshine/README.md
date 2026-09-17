# Sunshine AppImage

## 用途与产物

本目录将 Arch/AUR 当前 `sunshine-bin` 打包为 `sunshine.AppImage`。

## 技术栈与打包方式

Sunshine 为原生串流主机程序。构建脚本安装 Sunshine 及音视频、VA-API、Vulkan、PipeWire、X11 等运行依赖，通过 quick-sharun 生成 AppImage。

## 版本元数据

构建时从本次实际安装的 `sunshine-bin` 包读取版本，去掉 Arch epoch 与 pkgrel 后写入 `dist/version.txt`。workflow 使用 `SOFTWARE_KEY=sunshine` 接入统一版本清单。

## NVIDIA 本地更新注意事项

Sunshine 新版 Linux 构建会随上游 CUDA / NVENC 依赖提高 NVIDIA 驱动最低要求。若本地主机的 NVIDIA 驱动低于上游当前要求，可能出现 NVENC 编码器初始化失败，导致 Sunshine 无法正常串流。

因此，仓库构建与 Release 可以继续跟随上游最新版本；NVIDIA 本地主机不要仅因检测到新版本就自动更新 Sunshine。更新前必须先核对当前 NVIDIA 驱动是否满足该版本的 CUDA / NVENC 要求；不满足时继续保留已验证可用的 Sunshine 版本，避免 `software_update update all` 将 Sunshine 更新到不兼容版本。

此说明只约束本地实际使用版本，不改变本目录继续构建和发布上游最新 Sunshine 的逻辑。

## 运行

```bash
./sunshine.AppImage
```

## 变更记录

### 2026-09-17：补充 NVIDIA 本地更新兼容性说明

仓库继续构建上游最新版本；NVIDIA 本地主机更新 Sunshine 前必须先核对当前驱动是否满足该版本的 CUDA / NVENC 要求，不满足时保留已验证可用版本，避免自动更新到不兼容版本。

### 2026-09-16：接入统一软件版本元数据

仅增加版本元数据，不改变现有 Sunshine 运行依赖、硬件加速或 quick-sharun 打包范围。
