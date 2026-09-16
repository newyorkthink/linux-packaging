# mpv AppImage

## 用途与产物

本目录将 Arch 当前 mpv 打包为 `mpv.AppImage`，并保留 yt-dlp 与双击无参数时的伪 GUI 启动行为。

## 技术栈与打包方式

mpv 为原生 C 媒体播放器。构建脚本安装 Arch `mpv`，通过 quick-sharun 收集运行依赖，并额外放入独立 yt-dlp。

## 版本元数据

构建时从本次实际安装的 `mpv` 包读取版本，去掉 Arch epoch 与 pkgrel 后写入 `dist/version.txt`。workflow 使用 `SOFTWARE_KEY=mpv` 接入统一版本清单。

## 运行

```bash
./mpv.AppImage
```

## 变更记录

### 2026-09-16：接入统一软件版本元数据

仅增加版本元数据输出，不改变现有 mpv、yt-dlp、locale 或 GUI hook 行为。
