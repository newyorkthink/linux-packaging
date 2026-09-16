# RealVNC Connect AppImage

## 用途与产物

本目录将 AUR `realvnc-rvnc-connect` 提供的官方 RealVNC Connect Flutter bundle 重新封装，Release 资产固定为 `rvncconnect.AppImage`。

## 技术栈与打包方式

RealVNC Connect 当前 Linux 客户端为 Flutter 应用。外层 Arch 环境取得官方 bundle，真正的依赖收集和 AppImage 生成在 Ubuntu 22.04 容器中完成，以保持较低 GLIBC 基线，同时保留 Fcitx5 GTK3 与宿主浏览器打开逻辑。

## 版本元数据

构建时从本次实际安装的 `realvnc-rvnc-connect` 包读取版本，去掉 Arch epoch 与 pkgrel 后写入 `dist/version.txt`。统一清单键使用 `realvnc_connect`，实际 Release 资产仍为 `rvncconnect.AppImage`。

## 运行

```bash
./rvncconnect.AppImage
```

## 变更记录

### 2026-09-16：接入统一软件版本元数据

仅增加版本元数据和发布映射，不改动现有 Flutter bundle、Ubuntu 22.04、GLIBC、Fcitx5、GTK 或 xdg-open 稳定逻辑。
