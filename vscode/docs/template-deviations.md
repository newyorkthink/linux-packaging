# 模板差异说明

本目录按根目录 [Anylinux / quick-sharun 打包规范](../../anylinux_projects.md) 的 Electron 直接下载路线构建。本文只记录当前应用的差异、代码出处和原因，不改变通用模板。

## 官方来源

- 官方打包仓库：[pkgforge-dev/Visual-Studio-Code-AppImage](https://github.com/pkgforge-dev/Visual-Studio-Code-AppImage)。
- 固定核对 commit：[`0016f8465bfeb37d7bb557eeab0c8469a41cf0de`](https://github.com/pkgforge-dev/Visual-Studio-Code-AppImage/commit/0016f8465bfeb37d7bb557eeab0c8469a41cf0de)。
- 依赖与程序整理原文：[get-dependencies.sh](https://github.com/pkgforge-dev/Visual-Studio-Code-AppImage/blob/0016f8465bfeb37d7bb557eeab0c8469a41cf0de/get-dependencies.sh)。
- 图形部署原文：[make-appimage.sh](https://github.com/pkgforge-dev/Visual-Studio-Code-AppImage/blob/0016f8465bfeb37d7bb557eeab0c8469a41cf0de/make-appimage.sh)。
- 命令行路由原文：[AppDir/bin/cli-router.hook](https://github.com/pkgforge-dev/Visual-Studio-Code-AppImage/blob/0016f8465bfeb37d7bb557eeab0c8469a41cf0de/AppDir/bin/cli-router.hook)。
- 版权与许可：[LICENSE](https://github.com/pkgforge-dev/Visual-Studio-Code-AppImage/blob/0016f8465bfeb37d7bb557eeab0c8469a41cf0de/LICENSE)。

## 官方归档格式与程序布局

当前路线继续使用 Microsoft 官方稳定版 Linux x64 tar 包，保持原有程序来源。相对直接下载 DEB 的模板，下载目标和公共解包参数采用 tar 格式，完整程序目录从 `vscode-unpacked/VSCode-linux-x64/.` 复制到 `AppDir/bin/`，不拆开主程序和相邻资源。

依赖和图标、desktop 由已安装的 `visual-studio-code-bin` 提供。最终程序文件仍来自单独下载的官方 tar 包，不从系统安装目录复制程序本体。

## 系统桌面资源

- 与标准模板的差异：[Cursor](../../cursor/build_cursor.sh) 和 [WorkBuddy](../../workbuddy/build_workbuddy.sh) 模板没有单独创建协议入口目录、收集独立协议入口文件的步骤。本构建参照 [官方 get-dependencies.sh](https://github.com/pkgforge-dev/Visual-Studio-Code-AppImage/blob/0016f8465bfeb37d7bb557eeab0c8469a41cf0de/get-dependencies.sh) 中保留 `code-url-handler.desktop` 的做法增加此步骤，实际文件从已安装包取得。
- 位置：依赖安装完成后取得协议入口；打包元数据阶段直接指定系统图标和主 desktop。
- 主 desktop：`/usr/share/applications/com.microsoft.VSCode.desktop`。
- URL 入口来源：`/usr/share/applications/com.microsoft.VSCode.UrlHandler.desktop`，复制到 `AppDir/share/applications/code-url-handler.desktop`。
- 图标：`/usr/share/pixmaps/vscode.png`。
- 原因：已安装的软件包已经提供完整的桌面文件。本仓库按标准模板使用这些现成资源，不引入官方下载模板及占位符替换流程。
- 归属：复制系统资源的命令为本仓库构建代码，不标注为官方原命令，也不将其描述成对官方命令的等价复用。

## 删除上游明确排除的组件

- 位置：版本读取后、第一次 quick-sharun 收集依赖之前。
- 原始出处：[get-dependencies.sh](https://github.com/pkgforge-dev/Visual-Studio-Code-AppImage/blob/0016f8465bfeb37d7bb557eeab0c8469a41cf0de/get-dependencies.sh) 末尾。
- 本仓库复用的命令原文：

```bash
rm -rf ./AppDir/bin/resources/app/node_modules/@github/copilot-linuxmusl-x64
```

官方原注释为 `# not needed`，意思是该目录不需要保留。官方未说明进一步技术原因；本文不把其他推测作为官方理由。

构建脚本将这条简略注释改成“复用官方代码：删除上游明确标为不需要保留的运行组件。”。只改变注释表达，删除命令、参数和路径保持原样。处理仅删除代码中明确指定的目录，不删除相邻组件。

## 图形部署选项

- 位置：打包元数据阶段，紧接 GTK 部署选项。
- 原始出处：[make-appimage.sh](https://github.com/pkgforge-dev/Visual-Studio-Code-AppImage/blob/0016f8465bfeb37d7bb557eeab0c8469a41cf0de/make-appimage.sh)。
- 原样复用的命令：

```bash
export DEPLOY_OPENGL=1
export DEPLOY_VULKAN=1
```

用途是让 quick-sharun 收集 OpenGL 和 Vulkan 运行依赖。官方未说明该应用启用这些选项的额外背景原因，不将其解释成已确认的故障修复。

`libdbusmenu-glib` 已在本仓库原有依赖列表中，继续通过统一安装入口安装。本次没有把官方的包管理器命令改写后标注为官方代码，也没有引入系统整体升级命令。

## 原有依赖覆盖关系

按原脚本的两条安装命令逐项对照，原有基础工具和运行依赖均有明确来源，不以调用 `--base` 代替依赖核对：

- 由 [公共基础包清单](../../common/arch/install_packages.sh) 保留：`gcc`、`base-devel`、`curl`、`wget`、`tar`、`gzip`、`binutils`、`patchelf`、`coreutils`、`appstream-glib`、`desktop-file-utils`、`util-linux`、`zsync`、`gnupg`、`nss`、`shared-mime-info`、`xdg-utils`、`libxkbcommon`、`ibus`。
- 由已安装 `visual-studio-code-bin` 的 [AUR 依赖声明](https://github.com/archlinux/aur/blob/visual-studio-code-bin/PKGBUILD) 保留：`libxkbfile`、`gtk3`、`libsecret`、`gcc-libs`、`libnotify`、`libxss`、`glibc`、`lsof`、`alsa-lib`。
- 在现有应用安装行明确追加保留：`xorg-server`、`xorg-server-common`、`xorg-server-xvfb`、`libdbusmenu-glib`、`libx11`、`libxext`、`libxi`、`libxrandr`、`libxtst`、`libxcomposite`、`libxdamage`、`libxfixes`、`mesa`、`libglvnd`、`libva`、`libvdpau`。

以上对照没有遗漏原有包名。本次不删减应用安装行，也不改动统一基础包。

## 独立命令行路由文件

- 本仓库文件：`vscode/cli-router.hook`。
- 官方文件：[AppDir/bin/cli-router.hook](https://github.com/pkgforge-dev/Visual-Studio-Code-AppImage/blob/0016f8465bfeb37d7bb557eeab0c8469a41cf0de/AppDir/bin/cli-router.hook)。
- 构建位置：包内 locale 配置之后、最终封装之前，将本仓库配套文件复制到 `AppDir/bin/cli-router.hook`。
- 代码一致性：在原文件头部补充官方 MIT 版权和许可注释；去掉新增的许可注释后，文件与固定 commit 的官方原文件逐字一致。原可执行代码、参数、字符串、运行提示和原有注释均未改写。
- 原始原因：文件中的注释明确说明远程终端应使用 remote CLI、WSL 中的安装提示及 root 启动参数检查；末尾通过 `ELECTRON_RUN_AS_NODE=1` 执行程序自身的 `cli.js`。不追加官方未实现的行为。

构建脚本上方的一行中文注释明确标为“文件内容复用官方代码”。文件复制命令是本仓库的引用步骤，不冒称官方原命令。

## 版本、中文环境与验证范围

版本从本次官方程序的 `resources/app/package.json` 通过公共入口读取，保留构建 HOME 下的 `version` 和两个 desktop 的版本元数据处理；最终产物成功生成后通过公共入口写入 `dist/version.txt`。

包内中文 locale 及四项中文环境配置按通用模板保留。输入模块由 GTK 部署流程收集，不另写输入法启动包装。

本次核对包括 Bash 语法、ShellCheck、官方代码逐字一致性、固定路径与文档引用。没有把静态检查视为真实 AppImage 构建或图形界面验收。

ShellCheck 沿用标准模板中 `export ARCH="$(uname -m)"` 的既有 SC2155 格式提示，不为消除此提示拆分已确认的模板命令。
