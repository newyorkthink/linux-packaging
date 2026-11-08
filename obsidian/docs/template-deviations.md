# Obsidian 模板差异说明

## 标准流程与使用范围

[build_obsidian_new.sh](../build_obsidian_new.sh) 延续 [Electron GitHub Release DEB 标准模板](../../templates/quick-sharun/electron-github-deb.sh) 的初始化、构建目录、独立下载、DEB 校验与解包、程序目录复制、版本、中文环境和封装步骤。系统安装阶段使用 AUR `obsidian-bin`，第二阶段从 [Obsidian 官方 Releases](https://github.com/obsidianmd/obsidian-releases) 下载 AMD64 DEB，不以系统已安装程序替代下载的程序。

正式构建脚本仍是 [build_obsidian.sh](../build_obsidian.sh)，其来源为官方 x64 tar.gz；本次没有改变正式构建清单。

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

对照原 [build_obsidian.sh](../build_obsidian.sh) 的两条 `yay -S` 命令，以及公共 `--base` 基础包和新脚本已有依赖项。原有包名均已覆盖；应用安装行补入原有但未覆盖的：

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

这些附加目标来自原 [build_obsidian.sh](../build_obsidian.sh)，不是复制 pkgforge-dev 上游的扫描命令；新增注释为 `# 本程序专属处理：收集 hostname、NSS 安全库及 GTK3 IBus 输入模块。`。路径及扫描范围见 [固定配置说明](./hardcoded.md)。

## pkgforge-dev 上游核对

参考仓库：[pkgforge-dev/Obsidian-AppImage-Enhanced](https://github.com/pkgforge-dev/Obsidian-AppImage-Enhanced/tree/138798b2139d4cafd8e3f86ada4c804397585a2a)，固定核对 commit 为 `138798b2139d4cafd8e3f86ada4c804397585a2a`。

- [get-dependencies.sh](https://github.com/pkgforge-dev/Obsidian-AppImage-Enhanced/blob/138798b2139d4cafd8e3f86ada4c804397585a2a/get-dependencies.sh)：获取官方 tar.gz，并将程序目录及其资源复制到 AppDir。当前新脚本改用官方 DEB 来源，仍复制完整 Electron 程序目录。
- [make-appimage.sh](https://github.com/pkgforge-dev/Obsidian-AppImage-Enhanced/blob/138798b2139d4cafd8e3f86ada4c804397585a2a/make-appimage.sh)：使用 `quick-sharun ./AppDir/bin/*`。本仓库增加的 NSS、hostname 与 GTK3 IBus 路径来自原 Obsidian 脚本。
- 上游使用 `self-updater.hook`、`fix-namespaces.hook`、`UPINFO` 和 `OPTIMIZE_LAUNCH`，本次均不引入。上游额外执行构建后测试，本次不增加测试步骤。
- 没有添加 `obsidian://` 宿主协议注册 hook；系统安装包提供的 desktop 仍由标准模板使用。

## 检查与发布范围

依赖列表已对照原脚本、公共基础包及应用安装项逐项核查；新脚本的三个修改位置分别是安装依赖、部署开关及 quick-sharun 收集。正式构建清单仍指向原脚本，未改变相关公共脚本或工作流。此前云端生成器的语法检查只覆盖基础生成稿，不视为本次专属修改的完整 AppImage 构建验证。
