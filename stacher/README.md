# Stacher AppImage

## 用途与产物

本目录从 Stacher 官方 Linux x64 更新端点动态下载当前 DEB，并重新封装为 `stacher.AppImage`。

## 技术栈与打包方式

Stacher 7 为 Electron 桌面应用。构建时先安装 AUR 的 `stacher7` 及所需依赖，再通过公共下载入口独立获取官网 DEB。公共入口核对包的 amd64 架构并解包，构建脚本保留完整 Electron 运行目录与 Node 原生模块，通过 quick-sharun 部署 GTK3、图形和音频依赖。

官方版本取自 DEB control。现有 Electron DEB 模板从 `package.json` 读取版本，因此按专用流程整理。处理依据见[模板差异](./docs/template-deviations.md)与[固定配置](./docs/hardcoded.md)。

## 版本元数据

构建脚本从本次下载的官方 DEB 读取 `Version`。成品生成后保存 `dist/stacher.AppImage.sha256`，再由公共入口写入 `dist/version.txt`。workflow 使用 `SOFTWARE_KEY=stacher` 接入统一版本清单。

## 运行

```bash
# 在下载目录启动 Stacher AppImage。
./stacher.AppImage
```

## 变更记录

### 2026-11-28：整理官网 DEB 打包流程

将依赖安装、下载、架构校验、解包和版本保存接入公共入口。沿用包内桌面资源、完整运行目录及便携启动参数。已完成静态核对，实际构建与桌面运行结果待验收。

### 2026-09-16：接入统一软件版本元数据

仅增加版本元数据与发布映射，不改变现有 Stacher Electron 目录、Node 模块、音频或输入法逻辑。
