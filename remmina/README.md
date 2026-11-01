# Remmina AppImage

## 用途与产物

本目录把 Ubuntu 24.04 官方仓库中的 Remmina 与 FreeRDP 3、GTK3、WebKitGTK 等运行组件封装为 x86_64 AppImage，稳定产物名为 `remmina.AppImage`。

## 技术栈与打包方式

Remmina 为 GTK3 / C 桌面应用，RDP 使用 FreeRDP 3。当前构建直接使用 GitHub Actions 的 Ubuntu 24.04 runner，安装官方软件包后按原布局解包到 AppDir，使用 linuxdeploy 的 GTK / GStreamer 插件部署依赖，再由官方 appimagetool 与明确 runtime 生成 AppImage。打包链路不使用 Docker。

现有兼容处理包括 Remmina 插件相对路径、简体中文翻译、Local Terminal / SSH 运行环境、OpenSSL 3 legacy provider、WebKitGTK 运行目录、GTK3 Fcitx5 / IBus 输入模块以及本地 RDP 认证默认值。上述处理已接入 `build_remmina.sh`；workflow 不再调用 `fix_remmina_webkit.sh` 重新解包和封装产物。旧脚本保留为历史文件。

## 标准化入口

`build_remmina.sh` 遵循 [linuxdeploy 标准](../linuxdeploy_projects.md)，在资源准备阶段调用 `patches/prepare_runtime.sh`，在依赖部署后、最终封装前调用 `patches/fix_runtime.sh`。完整 AppRun、本地终端 wrapper、输入法缓存和 RDP 认证设置保留在主 build；用途及位置见 [专属差异](./docs/template-deviations.md)。

## 当前基线与验收

构建基线为 [7346900](https://github.com/newyorkthink/linux-packaging/commit/7346900ae63d06a4c4cddd353f87f9903acc6be1)。[Actions run 41221937920](https://github.com/newyorkthink/linux-packaging/actions/runs/41221937920) 已成功完成 Remmina 构建、Release 上传和版本元数据发布步骤。

2026-11-01，用户提供的实机截图确认：程序正常启动，中文界面和输入法候选框显示正常，WWW 页面能够加载，RDP 连接能够显示远程 Windows 桌面。

日志中仍有 GTK、GLib 和 WebKit 告警，原因尚未定位，暂不处理。当前实现作为已确认基线保留，后续仅在有明确需求或功能故障并获得授权时调整，不为消除这些告警反复改动已验证实现。

## 版本元数据

`common/apt/extract_installed_package.sh` 读取实际安装的 `remmina` 版本，去掉 Debian epoch 和 revision，仅以主软件包作为版本来源；附加插件包按各自已安装的同一版本下载并解包。

构建日志保留 `Remmina 版本：<版本>`。最终封装成功后，公共封装入口写入 `dist/version.txt`；workflow 沿用现有日志读取及元数据上传步骤，上传 `software-version-remmina`，并以 `remmina.AppImage` 更新 `software_versions.json`。

## 构建与运行

正式构建入口为 `.github/workflows/build.yml`。相关脚本：

```text
remmina/build_remmina.sh
remmina/patches/prepare_runtime.sh
remmina/patches/fix_runtime.sh
```

运行最终产物：

```bash
./remmina.AppImage
```

## 变更记录

以下检查范围记录各次提交当时执行的检查，当前验收结论以 [当前基线与验收](#当前基线与验收) 为准。

### 2026-11-01：避免 GStreamer 部署误选辅助桌面入口

- 故障依据：[Actions run 41220793043 的 Build Remmina](https://github.com/newyorkthink/linux-packaging/actions/runs/41220793043/job/124594759881)。GStreamer 插件内部再次调用 linuxdeploy，未指定 desktop；自动选择了没有 `Icon` 字段的 `remmina-gnome.desktop`，退出码为 1。原始日志：

  ```text
  [gstreamer/stdout] WARNING: No desktop file specified, using first desktop file found: AppDir/usr/share/applications/remmina-gnome.desktop
  [gstreamer/stdout] ERROR: Icon entry missing in desktop file: AppDir/usr/share/applications/remmina-gnome.desktop
  ERROR: Failed to run plugin: gstreamer (exit code: 1)
  ```

- 处理：`patches/prepare_runtime.sh` 在依赖部署前，将 `remmina-gnome.desktop` 和 `org.remmina.Remmina-file.desktop` 暂存到 AppDir 内的 `.remmina-desktop-files/`，使 applications 目录仅保留主入口 `org.remmina.Remmina.desktop`；`patches/fix_runtime.sh` 在依赖部署完成后恢复原文件并移除空暂存目录。不删除或修改辅助入口的内容。
- 检查范围：两个 helper 的语法及临时目录中的 desktop 暂存、选择和恢复；未执行实际打包或实机运行。主 build、公共脚本、workflow 和其他项目保持原样。

### 2026-11-01：修正 Ubuntu 24.04 的图标资源包名

- 故障依据：[Actions run 41219755183 的 Build Remmina](https://github.com/newyorkthink/linux-packaging/actions/runs/41219755183/job/124591702545)。下载图标与主题资源时，APT 因 `adwaita-icon-theme-full` 没有候选版本而退出，退出码为 100。原始错误：

  ```text
  E: Can't select candidate version from package adwaita-icon-theme-full as it has no candidate
  ```

- 处理：Ubuntu 24.04 的下载清单移除 `adwaita-icon-theme-full`，保留 `adwaita-icon-theme` 和 `gnome-themes-extra-data`；构建环境继续使用 Ubuntu 24.04。公共脚本、workflow 和其他项目保持原样。
- 检查范围：仅做主 build 的语法检查及本次完整差异核对；未执行实际打包或实机运行，提交后不监控 Actions。

### 2026-11-01：按 linuxdeploy 标准接入 patches

- 主 build 改为直接安装并解包 Ubuntu 软件包，复用公共工具准备、APT 解包和最终封装入口；资源准备与封装前修复分别调用两个 `patches` 脚本。
- Remmina job 使用 `ubuntu-24.04`，移除旧 `fix_remmina_webkit.sh` 调用；其他应用 job、Release 资产名和版本发布机制保持原样。既有修复历史完整保留。
- 检查范围：主 build、AppRun、本地终端 wrapper 的语法，以及 workflow 的 YAML、路径和调用顺序；未执行实际打包或实机运行，提交后不监控 Actions。

### 2026-10-30：把公共脚本挂进容器并安装 rsvg-convert

- 故障依据：[Actions run 41022743379](https://github.com/newyorkthink/linux-packaging/actions/runs/41022743379) 的 Build Remmina。构建命令是 `env -u GITHUB_ACTIONS`，容器只挂载应用目录到 `/work`。日志：`/work/../common/appimage/prepare_appdir_for_appimagetool.sh: No such file or directory`，退出码 127。
- 处理：把仓库 `common` 只读挂到容器 `/common`，封装前改调这个路径。容器安装列表增加 `librsvg2-bin`。原 appimagetool 命令未改。
- 验证范围：只做了 `bash -n`。这次构建结果尚未验证。

### 2026-10-30：补齐 appimagetool 要求的 PNG 图标

- 故障依据：[Actions run 41010671616](https://github.com/newyorkthink/linux-packaging/actions/runs/41010671616) 的 Build Remmina。appimagetool continuous build 333（git `b082d2e`，2026-10-29）报根目录没有 `org.remmina.Remmina.png`，`.DirIcon` 无效，退出码 1。发行版图标是 SVG。
- 处理：`build_remmina.sh` 和 `fix_remmina_webkit.sh` 都在原封装命令前调用 `common/appimage/prepare_appdir_for_appimagetool.sh`。原 appimagetool 参数和 AppRun 未改。
- 验证范围：公共脚本做过语法检查和临时目录检查。没有重打 Remmina，没有重跑 Actions。构建环境需要 `rsvg-convert`、`magick` 或 `convert` 才能把 SVG 转成 PNG；本次没有在正式构建里确认该工具是否已安装。

### 2026-09-16：接入统一软件版本元数据

- 修改文件：`.github/workflows/build.yml`、本 README。
- 版本信息只从当前构建已经输出的 Remmina 软件包版本提取，不改变应用构建、WebKitGTK 修复或 Release 资产名。
- 提交后不主动监控 Actions，实际新清单记录以下一次成功构建为准。

### 2026-09-16：修复版本元数据写入权限

- 故障现象：Remmina AppImage 已完成构建和 WebKitGTK 修复，但 `Prepare software version metadata` 在写入 `remmina/dist/version.txt` 时返回 `Permission denied`。
- 根因：`build_remmina.sh` 通过 Docker 在挂载的工作区中创建 `dist/`，目录归属为 root；后续 GitHub Actions runner 用户不能直接在该目录创建新文件。
- 修复内容：仅将版本文件写入改为通过 `sudo tee` 写入 root 所有的 `dist/`；不修改 Remmina 构建、WebKitGTK 修复、AppImage 内容或 Release 资产名。

### 2026-11-01：补齐中间封装前的公共图标准备

- 故障依据：[运行 #1102 的 Build Remmina](https://github.com/newyorkthink/linux-packaging/actions/runs/41298501421/job/124824392737)。linuxdeploy 的输出插件报根目录缺少 `org.remmina.Remmina.png` / XPM，`.DirIcon` 无效，退出码为 1；后面的运行目录修正和最终封装未执行。
- 原因与处理：新版内置 appimagetool 在中间封装就检查根图标。公共工具准备现安装外部输出包装，在 linuxdeploy 完成 GTK / GStreamer 及根桌面资源部署后复用现有图标与权限准备，再交给官方输出插件；最终封装前的准备继续保留。
- 本项目 build、AppRun、本地终端 wrapper、输入法、认证配置及两个 patches 均未修改，保留已确认的实机基线。公共实现、官方依据和提交前验证边界见 [更新兼容说明](../docs/linuxdeploy-update-compatibility.md)；本次不重复宣称新的完整应用构建或实机验收。
