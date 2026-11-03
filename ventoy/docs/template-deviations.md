# Ventoy 模板差异

Ventoy 使用[直接 appimagetool 封装标准](../../linuxdeploy_projects.md#直接-appimagetool-模式同一体系的精简流程)。以下处理仅用于 Ventoy 的发行包和启动布局。

| 阶段 | 处理 | 依据与影响 |
| --- | --- | --- |
| 准备构建目录 | 公共工作目录入口启用 `--temporary-source`。 | 下载、解包和工具写入本次临时目录，退出时清理。工作区只重建 Ventoy 的 `AppDir` 和 `dist`。 |
| 下载并准备应用 | 公共下载入口启用 `--latest-with-checksum`，用同一 Release 的 GitHub SHA-256 和官方 `sha256.txt` 校验归档。 | 官方 Release 同时提供 Linux 归档与校验清单。通过后返回本次实际版本，并写出 tag 对应的提交供图标下载使用。 |
| 下载并准备应用 | 完整复制官方发行目录到 `AppDir/ventoy/`。 | GUI、worker、WebUI 和启动资源沿用官方相对布局。 |
| 准备桌面资源和运行库 | 在 AppDir 根目录生成 desktop，并从本次 tag 对应的提交取得官方 PNG 图标。 | 图标对应本次发行版本。封装时由公共入口处理根图标和权限。 |
| 准备桌面资源和运行库 | 调用公共 locale 入口生成包内 `zh_CN.UTF-8`。 | 为 AppRun 提供包内 locale 数据。GTK3 简体中文界面已通过实机验证。 |
| 准备 AppRun | 主脚本内联完整 AppRun，设置 `LOCPATH` 和 `LANG`，执行 `VentoyGUI.x86_64`。 | GTK 和 Qt 在没有保存语言选择时默认使用简体中文。保留包内程序及运行库的搜索路径、无障碍桥接设置和参数转发。配置依据见[固定配置说明](./hardcoded.md)。 |
| 下载打包工具 | 直接封装模式显式传入 `--release-ref latest`。 | 两个封装工具继续使用各自官方的 `/releases/latest`，下载时校验 SHA-256。 |
| 整理产物 | 公共封装入口使用默认参数，写入 `dist/version.txt`。 | 工具统一使用标准封装命令。启动镜像、GTK3 缺库和最终成品解包检查不进入日常构建。发布资产的 SHA-256 已核对。GTK3 中文启动、U 盘识别及 1.1.17 到 1.1.18 的升级均经[实机验证](../README.md#构建与验证)通过。 |
