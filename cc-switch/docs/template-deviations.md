# CC Switch 模板差异

本项目为 Tauri 2 / Rust、GTK 3、WebKitGTK 4.1 程序，单独归入 [Tauri / GTK 分类](../../docs/packaging-classification.md#用-quick-sharun-打包的-tauri--gtk-程序)。共用 [直接下载标准](../../anylinux_projects.md#直接下载安装包的标准模板) 的执行阶段、九项元数据顺序、通用注释和空行，不加入 Electron 专属处理。

## 来源核实

本次未找到 pkgforge-dev 对应应用的打包仓库。软件官方 Release 和当前 AUR 来源均提供 Linux DEB，因此采用先安装应用及依赖、再独立下载并解包官方 DEB 的两阶段流程。没有对应官方专属处理，不新增空的 `pkgforge-differences.md`。

## 当前实际差异

| 阶段 | 当前代码及原因 |
| --- | --- |
| 下载 | [第 20 行](../build_cc-switch.sh#L20)调用公共 GitHub 稳定 Release 下载入口，按 `CC-Switch-v{version}-Linux-x86_64.deb` 匹配唯一资产，校验 GitHub SHA-256 及 `cc-switch amd64`，stdout 重定向到 `cc-switch.version`。调用保持三行。 |
| 程序复制 | [第 28 行](../build_cc-switch.sh#L28)复制 `cc-switch-unpacked/usr/bin/.`；实际 DEB 中该目录仅有 `cc-switch` ELF，前端资源由 Tauri 程序承载，没有另行复制的应用资源目录。 |
| 版本读取 | [第 50 行](../build_cc-switch.sh#L50)使用公共 `text` 来源读取下载版本文件，不以可能滞后的 AUR 安装版本代替实际发布资产版本。 |
| 托盘动态库 | [第 53 行](../build_cc-switch.sh#L53)保留 `/usr/lib/libayatana-appindicator3.so.1` 显式输入；依据原 README 的动态加载失败记录。 |
| 输入法和 locale | [应用安装行](../build_cc-switch.sh#L13)补充 `fcitx5-gtk`；包内 locale 和四项语言环境按 [第 55 行起](../build_cc-switch.sh#L55)的标准代码生成。 |

## 工具自动部署的依据

已读取的 [quick-sharun 当前源码](https://github.com/pkgforge-dev/Anylinux-AppImages/blob/main/useful-tools/quick-sharun.sh) blob 为 `7053bbb3fac3dc51ab93e7c232de6899b5399028`：

- [GTK 部署](https://github.com/pkgforge-dev/Anylinux-AppImages/blob/main/useful-tools/quick-sharun.sh#L1188-L1204)会把对应 GTK 目录的 `immodules/*` 加入收集输入，因此 IBus 模块保持被收集，同时收集新安装的 Fcitx5 GTK 模块；调用处不再重复传入单个 IBus 路径。
- [WebKitGTK 识别](https://github.com/pkgforge-dev/Anylinux-AppImages/blob/main/useful-tools/quick-sharun.sh#L895-L901)会根据依赖设置部署选项和目录。实际 CC Switch ELF 明确依赖 `libwebkit2gtk-4.1.so.0`，GTK 部署中的 [WebKit 分支](https://github.com/pkgforge-dev/Anylinux-AppImages/blob/main/useful-tools/quick-sharun.sh#L1205-L1222)继续处理其资源；本脚本不另加重复 export。

这些说明记录工具机制，不是复制其他应用的专属补丁，也不表示已完成实机验证。

## 原依赖覆盖

原脚本两条安装命令共涉及 60 个不同包名，逐项对照未修改的公共基础清单；25 项由 `--base` 覆盖，其余 35 项全部保留。应用安装行额外补充 `fcitx5-gtk` 和公共 DEB 校验、解包所需的 `dpkg`。

- 公共基础包保留：`gcc`、`base-devel`、`wget`、`curl`、`tar`、`gzip`、`xz`、`binutils`、`patchelf`、`coreutils`、`appstream-glib`、`desktop-file-utils`、`util-linux`、`zsync`、`ibus`、`shared-mime-info`、`xdg-utils`、`glib2`、`ca-certificates`、`libxkbcommon`、`at-spi2-core`、`pango`、`fontconfig`、`gdk-pixbuf2`、`hicolor-icon-theme`。
- 应用安装行保留：`xorg-server`、`xorg-server-common`、`xorg-server-xvfb`、`cc-switch-bin`、`gtk3`、`libayatana-appindicator`、`libdbusmenu-glib`、`libdbusmenu-gtk3`、`webkit2gtk-4.1`、`libsoup3`、`glib-networking`、`gsettings-desktop-schemas`、`libsecret`、`libnotify`、`glibc`、`gcc-libs`、`zlib`、`libx11`、`libxext`、`libxi`、`libxtst`、`libxss`、`libxrandr`、`libxinerama`、`libxcomposite`、`libxdamage`、`libxfixes`、`libxkbcommon-x11`、`libxkbfile`、`cairo`、`fribidi`、`freetype2`、`harfbuzz`、`librsvg`、`adwaita-icon-theme`。

完整调用位于 [构建脚本第 11 行](../build_cc-switch.sh#L11)和 [第 13 行](../build_cc-switch.sh#L13)，没有漏掉原有 xorg、GTK、WebKit、托盘或图形运行依赖。

## 格式与验证边界

当前脚本与批准草稿逐字一致，共 69 行，22 行中文注释、13 行空行。空行在第 2、5、9、14、18、23、26、29、48、51、54、64、67 行。除程序参数和已说明的来源、托盘输入外，共用注释及对应行的位置保持标准。

提交前核对官方 DEB 摘要、包名与架构、程序及桌面资源、ELF 依赖、公共接口、脚本语法、依赖覆盖和文档引用。本次未重新构建 AppImage 或进行图形界面、输入法、托盘及协议回调验证。原始修复历史继续保留在 [README](../README.md#修复记录)，固定配置和旧日志缺失情况见 [hardcoded.md](hardcoded.md)。
