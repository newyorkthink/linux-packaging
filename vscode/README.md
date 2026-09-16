# Visual Studio Code AppImage

## 用途与产物

本目录从 Microsoft 官方稳定版 Linux x64 tar 包构建 `dist/vscode.AppImage`。

## 技术栈与打包方式

Visual Studio Code 为 Electron / Chromium 桌面应用。构建脚本动态解析 Microsoft stable 下载地址，保留官方程序目录，读取官方 desktop 与 URL handler，并通过 quick-sharun 收集 GTK3、NSS、X11、OpenGL 和 IBus 运行依赖。

## 运行

```bash
./dist/vscode.AppImage
```

## 版本元数据

版本从官方程序目录 `resources/app/package.json` 读取，并继续写入 desktop 的 `X-AppImage-Version`。构建完成后同一版本写入 `dist/version.txt`，workflow 使用 `SOFTWARE_KEY=vscode` 接入统一清单。

## 变更记录

### 2026-09-16：接入统一软件版本元数据

仅增加更新器版本文件与统一发布映射，不改变 Microsoft stable 下载、Electron 目录、URL handler 或 quick-sharun 基线。
