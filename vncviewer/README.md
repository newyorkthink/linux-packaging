# RealVNC Viewer 7.15.1 AppImage

## 用途与产物

本目录独立构建 RealVNC Viewer 7.15.1 的 Linux x86_64 远程桌面客户端，正式产物为 `dist/realvnc_vnc_viewer.AppImage`，版本记录为 `dist/version.txt`。Viewer 仅负责连接远端 VNC 桌面，不安装 RealVNC Server 或宿主机服务。

## 原始安装包

安装包来自 [本仓库 Original Package Archive](https://github.com/newyorkthink/linux-packaging/releases/tag/original-package-archive)：`VNC-Viewer-7.15.1-Linux-x64.deb`，GitHub Release 记录的 SHA-256 为：

```text
05e3c75e053507492f7b9a3f2d75925ac6b5dc9249af73ae6c1ac51bc5d6aabb
```

该归档保留上游官方 DEB 原始资产；官方旧版下载直链已经不能作为可靠的持续来源。构建通过公共 GitHub API 认证、下载和 SHA-256 校验机制取得同一个归档资产。直链失败时按资产 ID 认证回退，不使用第三方镜像。软件版本取自已校验 DEB 的 `Version` 元数据。

## 技术栈与打包方式

使用 Ubuntu 24.04 独立 Actions Job，以及仓库已有 `linuxdeploy-cli-apt.sh` 无框架插件标准流程。运行依赖为 Ubuntu 的 `libsm6`、`libx11-6` 和 `libxext6`。公共脚本负责工作区、安装包下载与安装、原始布局解包、linuxdeploy 工具、空 AppDir 初始化和最终封装。构建不启用 Qt、GTK 或 GStreamer 插件。

保留官方 DEB 的 `usr/bin/vncviewer`、相关运行资源和图标。仅对 AppDir 中的 `realvnc-vncviewer.desktop` 副本设置 `Exec=vncviewer`、`Icon=vncviewer48x48`，并移除废弃的 `Encoding` 与 `Application` 分类，将旧版新建连接快捷方式转换为 `Actions=NewConnection;` 和 `[Desktop Action NewConnection]`，保留原有名称和启动命令；不修改原始 DEB。部署时使用该副本及官方 48×48 PNG 图标。根 `AppRun` 直接执行包内 `usr/bin/vncviewer` 并透传参数。linuxdeploy 部署依赖及中间输出，官方 appimagetool 配合 Type 2 runtime 生成最终 AppImage。

## 运行与构建

在 Linux 终端进入 AppImage 所在目录后：

```bash
# 运行 RealVNC Viewer 客户端。
./realvnc_vnc_viewer.AppImage
```

在 GitHub Actions 的 **Build AppImages** 中选择 `vncviewer/build_vncviewer.sh`；独立 Job 仅构建并发布该应用，成功后更新软件版本清单。构建脚本不启动后台 VNC 服务，运行 Viewer 不需要 sudo。

## 校验及维护

构建时验证 Release 的唯一资产、上传状态和官方 SHA-256；最终封装入口核对 AppImage 非空、输出 SHA-256 并保存版本。构建结果以 Actions 的实际状态为准；静态核对不等同于实机验收。

## 构建故障与修复

2026 年 11 月 8 日，[Viewer 构建 Job](https://github.com/newyorkthink/linux-packaging/actions/runs/42492346252/job/128770404168) 已完成官方 DEB 下载、安装、解包及 linuxdeploy 依赖收集，但在 appimagetool 校验桌面入口时失败，退出码为 1。日志指出 `Encoding` 和 `Categories` 中的 `Application` 已废弃，`[NewConnection Shortcut Group]` 不符合规范。

本次在既有启动入口、图标处理之后，对桌面文件副本删除废弃字段、改用标准 `Actions` 引用及 `[Desktop Action NewConnection]` 分组，并删除原 Unity 专属的 `TargetEnvironment`。保留各语言快捷方式名称及 `Exec=vncviewer`。原始安装包、公共下载接口、运行依赖、AppRun、linuxdeploy、appimagetool 和 Actions 不变。详见 [专属差异](./docs/template-deviations.md)。

本项目依据仓库已有的 [linuxdeploy 规范](../linuxdeploy_projects.md)、[标准模板](../templates/appimage/linuxdeploy-cli-apt.sh) 和 [固定注释](../docs/linuxdeploy-comments.md) 整理。应用专属 desktop 副本调整不改变其他项目的启动逻辑。
