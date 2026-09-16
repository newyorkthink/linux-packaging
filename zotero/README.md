# Zotero AppImage

## 用途与产物

本目录从 Zotero 官方 release Linux x86_64 tar 包重新封装 `zotero.AppImage`。

## 技术栈与打包方式

Zotero Linux 客户端使用 Mozilla/Firefox 系桌面运行时。构建脚本保留官方 tar 包程序目录与 desktop/icon，通过 quick-sharun 补齐 GTK、NSS、X11、OpenGL 和 IBus 运行依赖。

## 版本元数据

构建时从官方 tar 包内 `application.ini` 的 `Version` 字段读取实际版本，AppImage 成功生成后写入 `dist/version.txt`。workflow 使用 `SOFTWARE_KEY=zotero` 接入统一版本清单。

## 运行

```bash
./zotero.AppImage
```

## 变更记录

### 2026-09-16：接入统一软件版本元数据

仅增加版本读取、`dist/version.txt` 与发布映射，不改变现有 Zotero 官方 tar 包、NSS、GTK、X11、OpenGL 或 IBus 打包逻辑。
