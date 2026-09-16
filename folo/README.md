# Folo AppImage

## 用途与产物

本目录从 Folo 官方稳定 Desktop Linux x64 AppImage 提取上游 Electron 程序并重新封装，最终资产固定为 `folo.AppImage`。

## 技术栈与打包方式

Folo 为 Electron 桌面应用。构建脚本通过官方 GitHub Releases 动态选择稳定 `desktop/v<version>`，校验官方 AppImage，保留 Electron 运行目录与 Node 原生模块，并使用 quick-sharun 补齐 GTK、图形和音频运行时。

## 版本元数据

构建脚本复用本次 Release 解析得到的 `VERSION`，在现有最终产物检查完成后写入 `dist/version.txt`。workflow 使用 `SOFTWARE_KEY=folo` 接入统一 `software_versions.json`。

## 运行

```bash
./folo.AppImage
```

## 变更记录

### 2026-09-16：接入统一软件版本元数据

仅增加 `dist/version.txt` 与 workflow 清单接入，不改变现有 Folo Electron 运行目录、音频依赖、输入法或启动逻辑。
