# Obsidian AppImage

## 用途与产物

本目录从 Obsidian 官方 Desktop Releases 动态选择最近一个包含 Linux x64 tar 包的版本，并重新封装为 `obsidian.AppImage`。

## 技术栈与打包方式

Obsidian 为 Electron 桌面应用。脚本保留官方 Linux x64 程序目录和资源，通过 quick-sharun 补齐 GTK、NSS、X11、OpenGL、PipeWire 与 IBus 运行组件。

## 版本元数据

构建脚本复用从官方 tar 包 URL 解析出的 `VERSION`，AppImage 成功生成后写入 `dist/version.txt`。workflow 使用 `SOFTWARE_KEY=obsidian` 接入统一版本清单。

## 运行

```bash
./obsidian.AppImage
```

## 变更记录

### 2026-09-16：接入统一软件版本元数据

仅增加统一版本输出与发布映射，不改变现有 Obsidian 上游选择、Electron 依赖或输入法逻辑。
