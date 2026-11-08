# Obsidian 模板差异说明

## 标准流程与使用范围

[build_obsidian.sh](../build_obsidian.sh) 延续 [Electron GitHub Release DEB 标准模板](../../templates/quick-sharun/electron-github-deb.sh) 的初始化、构建目录、独立下载、DEB 校验与解包、程序目录复制、版本、中文环境和封装步骤。系统安装阶段使用 AUR `obsidian-bin`，第二阶段从 [Obsidian 官方 Releases](https://github.com/obsidianmd/obsidian-releases) 下载 AMD64 DEB，不以系统已安装程序替代下载的程序。

当前 [build_obsidian.sh](../build_obsidian.sh) 已采用标准化 DEB 流程，并沿用现有的正式构建入口。被替换的 [tar.gz 构建脚本](https://github.com/newyorkthink/linux-packaging/blob/10b63b344943519468de0c994ae0bb0e37c5c281/obsidian/build_obsidian.sh) 仍可从 Git 历史查阅；工作树中不另保留 `_new` 或旧版副本。

## 应用专属部署配置

元数据阶段紧接模板的 `DEPLOY_GTK=1`，补入原 Obsidian 脚本使用的三项部署配置，并按同类标准化程序的部署注释风格说明用途。

```bash
# 本程序专属处理：部署 OpenGL 运行依赖。
export DEPLOY_OPENGL=1
# 本程序专属处理：部署 Vulkan 运行依赖。
export DEPLOY_VULKAN=1
# 本程序专属处理：部署 PipeWire 音频组件。
export DEPLOY_PIPEWIRE=1
```

三个开关属于本应用原有的部署范围，不属于 pkgforge-dev/Obsidian-AppImage-Enhanced 上游明示采用的配置。该上游未说明上述本应用专属部署配置的原因。

## 安装依赖覆盖

对照替换前的 [build_obsidian.sh](https://github.com/newyorkthink/linux-packaging/blob/10b63b344943519468de0c994ae0bb0e37c5c281/obsidian/build_obsidian.sh) 的两条 `yay -S` 命令，以及公共 `--base` 基础包和当前脚本已有依赖项。原有包名均已覆盖；应用安装行补入原有但未覆盖的：

`xorg-server`、`xorg-server-common`、`xorg-server-xvfb`、`gcc-libs`、`glibc`、`lsof`、`libxext`、`libxi`、`libxkbfile`、`libxcomposite`、`libxdamage`、`libxfixes`、`libva`、`libvdpau`、`pulseaudio`、`pulseaudio-alsa`、`pipewire-audio`。

已由公共基础包或应用安装行覆盖的依赖不重复增加；不另行执行系统升级或直接调用 `yay`。

## 附加运行资源扫描

在初始依赖收集阶段，使用原 Obsidian 构建脚本中完整的扫描命令；命令本体及执行顺序逐字保持。

```bash
quick-sharun \
  ./AppDir/bin/* \
  /usr/bin/hostname \
  /usr/lib/libnss* \
  /usr/lib/libsoftokn3.so \
  /usr/lib/libfreeblpriv3.so \
  /usr/lib/pkcs11/* \
  /usr/lib/gtk-3.0/3.0.0/immodules/im-ibus.so
```

这些附加目标来自替换前的 [build_obsidian.sh](https://github.com/newyorkthink/linux-packaging/blob/10b63b344943519468de0c994ae0bb0e37c5c281/obsidian/build_obsidian.sh)，不是复制 pkgforge-dev 上游的扫描命令；新增注释为 `# 本程序专属处理：收集 hostname、NSS 安全库及 GTK3 IBus 输入模块。`。路径及扫描范围见 [固定配置说明](./hardcoded.md)。

## desktop 文件路径修复

[GitHub Actions 构建记录](https://github.com/newyorkthink/linux-packaging/actions/runs/42482368145/job/128736920818) 显示：官方 AMD64 DEB 下载及校验成功，quick-sharun 收集阶段因 `/usr/share/applications/obsidian.desktop is NOT a valid path!` 退出。该错误来自当前 Obsidian 脚本指定的桌面文件路径，不属于公共下载或 GitHub API 故障。

[Obsidian AUR 打包代码](https://github.com/Sohimaster/traur/blob/2ae91ec0a5029c734398f47e35b09fed1d4faf6d/tests/corpus/benign/obsidian/PKGBUILD) 对照显示，官方 DEB 使用 `md.obsidian.Obsidian.desktop`；pkgforge-dev 的 [桌面入口](https://github.com/pkgforge-dev/Obsidian-AppImage-Enhanced/blob/138798b2139d4cafd8e3f86ada4c804397585a2a/AppDir/obsidian.desktop) 使用相同的 `StartupWMClass=md.obsidian.Obsidian`。因此将脚本的 `DESKTOP` 路径定向修正为 `/usr/share/applications/md.obsidian.Obsidian.desktop`；其余代码、图标路径和 `STARTUPWMCLASS` 不变。

```bash
# 使用系统里装好的桌面入口文件。
export DESKTOP="/usr/share/applications/md.obsidian.Obsidian.desktop"
```

这次修改只修复已出现的桌面文件路径错误；是否完成整个 AppImage 构建以本次修改后的 GitHub Actions 结果为准。

## pkgforge-dev 上游核对

参考仓库：[pkgforge-dev/Obsidian-AppImage-Enhanced](https://github.com/pkgforge-dev/Obsidian-AppImage-Enhanced/tree/138798b2139d4cafd8e3f86ada4c804397585a2a)，固定核对 commit 为 `138798b2139d4cafd8e3f86ada4c804397585a2a`。详细原文及采用、未启用处理见 [上游处理取舍](./pkgforge-differences.md)。

- [get-dependencies.sh](https://github.com/pkgforge-dev/Obsidian-AppImage-Enhanced/blob/138798b2139d4cafd8e3f86ada4c804397585a2a/get-dependencies.sh)：获取官方 tar.gz，并将程序目录及其资源复制到 AppDir。当前脚本使用官方 DEB 来源，仍复制完整 Electron 程序目录。
- [make-appimage.sh](https://github.com/pkgforge-dev/Obsidian-AppImage-Enhanced/blob/138798b2139d4cafd8e3f86ada4c804397585a2a/make-appimage.sh)：使用 `quick-sharun ./AppDir/bin/*`。本仓库增加的 NSS、hostname 与 GTK3 IBus 路径来自原 Obsidian 脚本。
- 上游使用 `self-updater.hook`、`fix-namespaces.hook`、`UPINFO` 和 `OPTIMIZE_LAUNCH`，本次均不引入。上游额外执行构建后测试，本次不增加测试步骤。
- 没有添加 `obsidian://` 宿主协议注册 hook；系统安装包提供的 desktop 仍由标准模板使用。

## 检查与发布范围

依赖列表已对照替换前脚本、公共基础包及应用安装项逐项核查。现行正式脚本与此前的 `_new` 候选脚本内容完全相同，包含已核对的安装依赖、部署配置及 quick-sharun 收集命令；正式构建清单中的路径及 workflow 均未改变。此前云端生成器的 Bash 语法检查只覆盖基础生成稿，专属处理及正式 AppImage 构建是否通过，以实际 GitHub Actions 结果为准。
