# KeePassXC AppImage

## 用途与产物

本目录将 Arch 当前 KeePassXC 打包为 `keepassxc.AppImage`，并同时保留 CLI、proxy、X11 剪贴板和自动输入相关运行组件。

## 技术栈与打包方式

KeePassXC 为 Qt5/C++ 桌面应用。构建脚本安装 Arch `keepassxc` 及 Qt5/X11/Fcitx5 相关依赖，通过 quick-sharun 生成 AppImage。

## 版本元数据

构建时从本次实际安装的 `keepassxc` 包读取版本，去掉 Arch epoch 与 pkgrel 后写入 `dist/version.txt`。workflow 使用 `SOFTWARE_KEY=keepassxc` 接入统一版本清单。

## 运行

```bash
./keepassxc.AppImage
```

## 变更记录

### 2026-09-16：接入统一软件版本元数据

仅增加版本元数据输出和发布清单接入，不改变现有 Qt5、剪贴板、自动输入或 Fcitx5 打包逻辑。
