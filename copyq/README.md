# CopyQ AppImage

## 用途与产物

本目录将 Arch Linux 当前稳定 CopyQ 打包为 `dist/copyq.AppImage`。

## 技术栈与打包方式

CopyQ 为 Qt6 剪贴板管理器。构建脚本安装 CopyQ、Qt6、Fcitx5、X11/Wayland 与相关 KDE 运行组件，通过 quick-sharun 收集主程序，并保留现有功能插件目录兼容链接和翻译目录配置。

## 运行

```bash
./dist/copyq.AppImage
```

## 版本元数据

构建时从本次实际安装的 Arch `copyq` 包读取版本，去掉 epoch 与 pkgrel 后写入 `dist/version.txt`。workflow 使用 `SOFTWARE_KEY=copyq` 接入统一 `software_versions.json`。

## 变更记录

### 2026-09-16：接入统一软件版本元数据

仅增加版本元数据，不改变 CopyQ 插件搜索修复、翻译目录、Qt6/Fcitx5 或 quick-sharun 打包逻辑。
