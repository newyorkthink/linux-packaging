# mpv 模板差异

本文件说明当前构建相对 [Arch 官方仓库原生程序系统入口标准](../../anylinux_projects.md#arch-官方仓库原生程序系统入口标准) 的差异，回答“为什么这里需要额外代码”。具体固定值见 [hardcoded.md](./hardcoded.md)，官方原文和未启用项见 [pkgforge-differences.md](./pkgforge-differences.md)。这些文档不参与打包，也不授权后续自动加入功能。

## 基础流程

`build_mpv.sh` 共 52 行，独立 hook 共 6 行。去掉下列三个专属段后，基础部分与 40 行原生系统入口模板保持相同结构、通用注释和空行；仅应用包参数、图标、desktop、输出名及版本包名不同。

应用来自 Arch 官方仓库，`/usr/bin/mpv` 是真实入口。因此直接收集系统程序，不为主程序增加 DEB / tar 下载、解包、复制阶段，也不套用 Electron 模板的 APPNAME、MAIN_BIN、STARTUPWMCLASS 和 DEPLOY_GTK。图标、desktop、版本及输出路径仍遵守公共阶段。

原脚本全部 17 个不同依赖名均保留：`appstream-glib base-devel binutils coreutils desktop-file-utils gcc glycin libheif mpv mpv-mpris patchelf util-linux wget xorg-server xorg-server-common xorg-server-xvfb zsync`。其中 10 项由未修改的基础包入口覆盖，另 7 项在应用安装行显式传入：

```bash
# 安装官方软件包及运行依赖。
"$SCRIPT_DIR/../common/arch/install_packages.sh" mpv mpv-mpris glycin libheif xorg-server xorg-server-common xorg-server-xvfb
```

## 实际启用的专属段

三段均位于第一次 quick-sharun 之后、最终封装之前，顺序和注释如下。

### 官方运行时 locale

[build_mpv.sh 第 36 行](https://github.com/newyorkthink/linux-packaging/blob/main/mpv/build_mpv.sh#L36)：

```bash
# 复用官方代码：固定运行时 locale。
echo 'LC_ALL=C.UTF-8' >> ./AppDir/.env
```

可执行命令原样采用 [pkgforge-dev 的 make-appimage.sh](https://github.com/pkgforge-dev/mpv-AppImage/blob/953226d87422e9ef2307afacd2e049b1ee0a7f56/make-appimage.sh#L19-L22)。官方注释说明 mpv 只支持 C / C.UTF-8 数值 locale，不能依赖 anylinux.so 设成其他值。本次经明确批准采用该实现，旧 `LC_ALL=` / `LC_NUMERIC=C` 两行退出当前流程；不再额外生成中文 locale 或部署 GTK / Qt 输入模块。这是当前应用的已批准例外，不能据此改动其他 GUI。

### 本仓库内置独立辅助程序

[build_mpv.sh 第 39 行](https://github.com/newyorkthink/linux-packaging/blob/main/mpv/build_mpv.sh#L39)：

```bash
# 本仓库兼容处理：在依赖收集后下载并校验独立辅助程序。
mkdir -p AppDir/usr/bin
"$SCRIPT_DIR/../common/github/download_latest_stable_named_asset.sh" yt-dlp/yt-dlp yt-dlp_linux AppDir/usr/bin/yt-dlp
chmod +x AppDir/usr/bin/yt-dlp
```

延续本仓库构建时内置 yt-dlp 的方式，供在线媒体解析使用；下载从原 wget 改为现有公共入口。公共入口动态选择最新正式 Release 中唯一的固定资产，要求并校验 GitHub SHA-256；缺少摘要或下载失败则构建失败，不回退到未经校验的文件。

旧脚本注释说放在依赖收集后是为了避免 patchelf 修改。当前保留这个顺序，没有在本次复现或证明二进制曾被破坏。它是本仓库处理，不是官方 get-yt-dlp hook 的原样复用。下载发生在构建环境，辅助程序随产物携带；不在启动时安装到用户程序目录，更新随下一次构建进行。

### 官方独立无参数窗口 hook

[build_mpv.sh 第 44 行](https://github.com/newyorkthink/linux-packaging/blob/main/mpv/build_mpv.sh#L44)：

```bash
# 文件内容复用官方代码：未传入参数时启用窗口模式。
mkdir -p AppDir/bin
cp "$SCRIPT_DIR/mpv-launch-gui.src.hook" AppDir/bin/mpv-launch-gui.src.hook
```

本仓库的复制命令只负责引用独立文件，不冒称官方原命令。[mpv-launch-gui.src.hook](../mpv-launch-gui.src.hook) 的可执行内容原样采用 [官方文件](https://github.com/pkgforge-dev/mpv-AppImage/blob/953226d87422e9ef2307afacd2e049b1ee0a7f56/AppDir/bin/mpv-launch-gui.src.hook)。官方说明无参数时要补伪 GUI 参数，否则双击不会打开窗口；当前有参数时保持参数不变。该文件由生成的 AppRun 加载，不作为单独程序执行。这里的 AppDir/bin 只保存 hook，不预复制 mpv 主程序。

## 未启用

官方运行时 get-yt-dlp / self-updater hooks、UPINFO、实验性宿主驱动、runtime preload、源码构建及 FFmpeg 瘦身补丁和正式脚本中的视频测试均未启用。完整原文、作用和取舍见 [pkgforge-differences.md](./pkgforge-differences.md)，不能把这些未启用项写成现有功能。

后续要加入某项时，只重新核实对应官方当前源码、适用性及影响，再按当次授权处理；历史快照不构成自动恢复指令。当前范围仅完成静态检查，运行结果见 [README](../README.md#维护说明与验证范围)。
