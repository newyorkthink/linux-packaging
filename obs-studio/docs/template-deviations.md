# OBS Studio 模板差异

本页记录现有构建相对 [原生程序系统入口标准](../../anylinux_projects.md#arch-官方仓库原生程序系统入口标准) 的专属内容。注释与分类整理保留原有命令、参数、路径、续行及执行顺序。

## 应用及依赖来源

使用 Arch 官方仓库的 `obs-studio` 二进制包，由 `common/arch/install_packages.sh` 安装；直接收集 `/usr/bin/obs`，不重复下载或预复制主程序。Qt 6 输入模块使用现有的 `fcitx5-qt`，IBus 由基础包入口提供。

`qt6ct`、`kvantum` 和 `lxqt-qtplugin` 是 Qt 6 主题插件包，必须保留在应用依赖安装行中。quick-sharun 收集插件，不另行传入插件路径。完整警告及包名含义见 [Qt 主题插件](../../anylinux_projects.md#qt-主题插件)。

## 现有专属处理

| 所在阶段 | 保留内容 | 依据与影响 |
| --- | --- | --- |
| 打包元数据 | `DEPLOY_OPENGL=1`、`DEPLOY_PIPEWIRE=1`、`DEPLOY_PYTHON=1`、`DEPLOY_QT=1`。 | 对应现有 OpenGL、PipeWire、Python 和 Qt 6 部署需求，保留现有配置。 |
| 依赖收集 | `/usr/bin/obs-ffmpeg-mux`、`/usr/lib/obs-modules`、`/usr/share/obs`、`/usr/lib/obs-scripting` 与主程序同次收集。 | 录制辅助程序及运行时加载的模块、数据和脚本模块不能仅依赖主程序的动态库收集。路径依据和原始故障见 [写死的路径](./hardcoded.md)。 |
| 中文环境 | 在依赖收集后生成 `zh_CN.UTF-8`，向已有 `AppDir/.env` 追加语言和 locale 路径。 | 遵守有窗口程序的中文环境要求，不另写 `AppRun.sh`，不覆盖 quick-sharun 生成的入口。 |
| 版本记录 | 最终封装后继续由 `common/arch/get_package_version.sh` 读取版本，再调用 `common/build/save_appimage_version.sh` 保存。 | 保留原有小写 `version` 变量、调用位置和两行保存命令；本次不迁移版本接口或重新排版。公共入口去掉 epoch 和 pkgrel，并在最终产物非空后保存版本。 |

## 核实来源与边界

现有脚本和记录基线为本仓库 `5c5a8e5a1dc67ba074996eebc1448c1124afab55`。pkgforge-dev 对应打包已核对 [`8c17c157a498876f75b84cb0a30307aba641b396`](https://github.com/pkgforge-dev/OBS-Studio-AppImage/tree/8c17c157a498876f75b84cb0a30307aba641b396) 的 [`make-appimage.sh`](https://github.com/pkgforge-dev/OBS-Studio-AppImage/blob/8c17c157a498876f75b84cb0a30307aba641b396/make-appimage.sh)、[`get-dependencies.sh`](https://github.com/pkgforge-dev/OBS-Studio-AppImage/blob/8c17c157a498876f75b84cb0a30307aba641b396/get-dependencies.sh) 和 [`.github/workflows/appimage.yml`](https://github.com/pkgforge-dev/OBS-Studio-AppImage/blob/8c17c157a498876f75b84cb0a30307aba641b396/.github/workflows/appimage.yml)；其依赖脚本同样列有三个主题插件包，但未说明逐项原因。本次不新增、恢复或替换官方专属处理。

分类登记和注释整理不代表增加构建或实机验收结论。已发生的故障及现有状态仍以 [README](../README.md) 和 [路径记录](./hardcoded.md) 为准。
