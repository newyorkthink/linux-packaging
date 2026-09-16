# SMPlayer AppImage

## 用途与产物

本目录将 Arch 当前 SMPlayer 及其 mpv/mplayer 运行组件打包为 `smplayer.AppImage`。

## 技术栈与打包方式

SMPlayer 为 Qt5 媒体播放器前端。构建脚本通过 quick-sharun 同时收集 SMPlayer、simple_web_server、mplayer、mpv、yt-dlp 以及 Qt5/Fcitx5 等运行依赖。

## 版本元数据

构建时从本次实际安装的 `smplayer` 包读取版本，去掉 Arch epoch 与 pkgrel 后写入 `dist/version.txt`。workflow 使用 `SOFTWARE_KEY=smplayer` 接入统一版本清单。

## 运行

```bash
./smplayer.AppImage
```

## 变更记录

### 2026-09-16：接入统一软件版本元数据

仅增加版本元数据，不改变现有播放器、yt-dlp、Qt5、主题或 locale 逻辑。
