# CopyQ AppImage

## 用途与产物

本目录将 Arch Linux 当前稳定 CopyQ 打包为 `dist/copyq.AppImage`。

## 技术栈与打包方式

CopyQ 为 Qt6 剪贴板管理器。按 [Qt 系统入口标准](../templates/quick-sharun/qt-installed.sh) 整理，使用公共入口安装 Arch 官方二进制包及原有依赖，保留 Qt6 输入与主题插件。quick-sharun 同次收集主程序、功能插件和共享资源，由工具生成 AppRun 并封装。

## 标准结构与专属处理

- 严格模式、工作目录、公共安装、工作区准备、版本读取与保存、包内中文 locale 采用 [quick-sharun 规范](../anylinux_projects.md)。依赖安装命令保持模板的单行格式，不使用续行符。构建重建本目录的 `AppDir/` 与 `dist/`，清理其中的旧构建产物。
- 保留 `STARTUPWMCLASS=copyq`、SVG 图标、原桌面入口及 `DEPLOY_OPENGL=1`；按 Qt6 标准显式设置 `DEPLOY_QT=1`。
- 功能插件兼容链接与 `COPYQ_TRANSLATION_PREFIX` 原命令保持不变，注释标明“本程序专属处理”。中文 locale 与翻译资源分别准备，不覆盖工具生成的 AppRun。
- 原样采用 pkgforge-dev 的完整收集命令；其瘦身包、自更新和强制软件渲染配置未启用。来源与取舍见 [官方处理取舍](./docs/pkgforge-differences.md)，实际差异见 [模板差异](./docs/template-deviations.md)，固定值与已有插件问题见 [固定配置](./docs/hardcoded.md)。

## 运行

在 Linux 终端的 `copyq` 项目目录运行：

```bash
./dist/copyq.AppImage
```

## 版本元数据

构建时从本次实际安装的 Arch `copyq` 包读取版本，去掉 epoch 与 pkgrel 后写入 `dist/version.txt`。workflow 使用 `SOFTWARE_KEY=copyq` 接入统一 `software_versions.json`。

## 变更记录

### 2026-09-16：接入统一软件版本元数据

仅增加版本元数据，不改变 CopyQ 插件搜索修复、翻译目录、Qt6/Fcitx5 或 quick-sharun 打包逻辑。

### 2026-11-06：按 Qt 系统入口标准整理

统一公共安装、工作目录、中文 locale 和版本入口，保留原依赖、窗口元数据、OpenGL 配置、功能插件兼容链接与翻译目录设置；完整收集 CopyQ 程序、插件及共享资源。分类、export 与上游来源登记同步更新。
