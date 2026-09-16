# Sunshine AppImage

## 用途与产物

本目录将 Arch/AUR 当前 `sunshine-bin` 打包为 `sunshine.AppImage`。

## 技术栈与打包方式

Sunshine 为原生串流主机程序。构建脚本安装 Sunshine 及音视频、VA-API、Vulkan、PipeWire、X11 等运行依赖，通过 quick-sharun 生成 AppImage。

## 版本元数据

构建时从本次实际安装的 `sunshine-bin` 包读取版本，去掉 Arch epoch 与 pkgrel 后写入 `dist/version.txt`。workflow 使用 `SOFTWARE_KEY=sunshine` 接入统一版本清单。

## 运行

```bash
./sunshine.AppImage
```

## 变更记录

### 2026-09-16：接入统一软件版本元数据

仅增加版本元数据，不改变现有 Sunshine 运行依赖、硬件加速或 quick-sharun 打包范围。
