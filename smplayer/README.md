# SMPlayer AppImage

## 用途与产物

本目录将 Arch 当前 SMPlayer 及其 mpv/mplayer 运行组件打包为 `smplayer.AppImage`。

## 技术栈与打包方式

从 Arch 官方仓库安装 Qt5 版 SMPlayer。quick-sharun 收集主程序、simple_web_server、mpv、mplayer、应用资源和 Qt5 输入模块，使用 `QT_DIR=qt` 选择 Arch 的 Qt5 插件目录。深色主题使用 `adwaita-qt5`。

官方 Python 版 yt-dlp 由公共入口下载并校验 SHA-256，随系统 Python 一起封装。公共入口使用 Actions 凭据查询正式 Release，官方直链失败时按同一资产 ID 认证下载。

包内提供简体中文 locale，界面翻译来自 SMPlayer 自带的资源。依赖、输入模块和主题的依据见[模板差异](./docs/template-deviations.md)与[固定配置](./docs/hardcoded.md)。

## 版本元数据

构建时由公共入口读取本次实际安装的 `smplayer` 版本，去掉 Arch epoch 与 pkgrel。AppImage 封装成功后，公共脚本将版本写入 `dist/version.txt`，供现有工作流更新软件版本清单。

## 运行

```bash
./smplayer.AppImage
```

## 变更记录

### 2026-11-11：整理 Qt5 打包流程

统一公共安装、工作区和版本步骤，明确 Qt5 插件来源，并接入带认证回退和摘要校验的 yt-dlp 下载入口。已核对依赖、资源路径和构建脚本，构建与实机结果待确认。

### 2026-09-16：接入统一软件版本元数据

仅增加版本元数据，不改变现有播放器、yt-dlp、Qt5、主题或 locale 逻辑。
