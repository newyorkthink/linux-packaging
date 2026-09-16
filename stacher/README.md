# Stacher AppImage

## 用途与产物

本目录从 Stacher 官方 Linux x64 更新端点动态下载当前 DEB，并重新封装为 `stacher.AppImage`。

## 技术栈与打包方式

Stacher 7 为 Electron 桌面应用。构建脚本从官方 DEB control 读取版本和架构，保留完整 Electron 运行目录与 Node 原生模块，并通过 quick-sharun 部署 GTK、图形和音频依赖。

## 版本元数据

构建脚本复用官方 DEB control 中的 `VERSION`，在现有最终产物检查完成后写入 `dist/version.txt`。workflow 使用 `SOFTWARE_KEY=stacher` 接入统一版本清单。

## 运行

```bash
./stacher.AppImage
```

## 变更记录

### 2026-09-16：接入统一软件版本元数据

仅增加版本元数据与发布映射，不改变现有 Stacher Electron 目录、Node 模块、音频或输入法逻辑。
