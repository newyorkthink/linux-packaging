# Cursor AppImage

## 用途与产物

本目录从 Cursor 官方 Linux x64 DEB 动态下载当前版本，并通过 quick-sharun 重新封装为 `dist/cursor.AppImage`。

## 技术栈与打包方式

Cursor 属于 Electron / VS Code 系谱。构建脚本解包官方 DEB，保留 Cursor 自带程序与资源，修正 desktop 入口，并收集 GTK3、NSS、X11、OpenGL、PipeWire 与 IBus 相关运行组件。

## 运行

```bash
./dist/cursor.AppImage
```

## 版本元数据

版本从官方包内 `resources/app/package.json` 读取。现有 `X-AppImage-Version` 逻辑继续保留，构建完成后同一版本额外写入 `dist/version.txt`，workflow 使用 `SOFTWARE_KEY=cursor` 接入统一清单。

## 变更记录

### 2026-09-16：接入统一软件版本元数据

仅增加 `dist/version.txt` 与发布映射；官方 DEB 解析、Electron 目录、desktop、IBus/NSS 与 quick-sharun 逻辑保持不变。
