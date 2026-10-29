# Cursor AppImage

## 用途与产物

本目录从 Cursor 官方 Linux x64 DEB 动态下载当前版本，并通过 quick-sharun 重新封装为 `dist/cursor.AppImage`。

## 技术栈与打包方式

Cursor 属于 Electron / VS Code 系谱。构建脚本下载当前官方 x64 deb，把整个程序目录放进 AppDir/bin，修正 desktop 入口，再交给 quick-sharun。GTK 3 输入模块由 quick-sharun 收集。包内带有 zh_CN.UTF-8。

## 运行

```bash
./dist/cursor.AppImage
```

## 版本元数据

版本从官方包内 `resources/app/package.json` 读取。现有 `X-AppImage-Version` 逻辑继续保留，构建完成后同一版本额外写入 `dist/version.txt`，workflow 使用 `SOFTWARE_KEY=cursor` 接入统一清单。

## 变更记录

### 2026-09-16：接入统一软件版本元数据

仅增加 `dist/version.txt` 与发布映射；官方 DEB 解析、Electron 目录、desktop、IBus/NSS 与 quick-sharun 逻辑保持不变。

### 2026-10-29：按 Electron 目录方式重排构建脚本

官方 x64 deb 改由 download_file.sh 从当前下载地址取得，再用 extract_archive.sh 解包。整个程序目录放进 AppDir/bin。脚本不再逐个传入 NSS、pkcs11 和输入模块。包内增加中文 locale。提交 7d92a907c379a0e0c0cf405948726d9fd39b770b。