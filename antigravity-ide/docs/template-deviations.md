# Antigravity IDE 模板差异

核对日期：2026-10-30。基础顺序、通用注释、系统资源读取和中文环境沿用 [直接下载标准模板](../../anylinux_projects.md#直接下载安装包的标准模板)。

## 当前启用

| 阶段 | 当前处理及原因 |
| --- | --- |
| 安装 | 先通过公共入口安装基础包，再安装 `antigravity-ide fcitx5-gtk libnss_nis bubblewrap gvfs librsvg libvdpau xcb-util-wm libxkbcommon-x11 gcc-libs`。系统安装用于依赖、图标和 desktop；最终程序另行下载。 |
| 下载 | 用公共 HTML 链接下载入口从官网下载页选择唯一的 Linux x64 tar，并将同一下载 URL 中的版本保存到 `antigravity-ide.version`。下载命令按标准模板保持三行，链接与版本匹配规则作为参数传入。 |
| 解包和复制 | 公共解包入口后，将 `antigravity-ide-unpacked/Antigravity IDE/` 完整复制到 `AppDir/bin/`；保留程序与资源布局。 |
| 图形部署 | 在 `DEPLOY_GTK=1` 后原样保留 `DEPLOY_OPENGL=1`、`DEPLOY_VULKAN=1`，维持原构建的图形依赖部署范围。 |
| 版本 | 第一次 quick-sharun 前使用 `read_app_version.sh text antigravity-ide.version`；AppImage 成功生成后用公共保存入口写 `dist/version.txt`。 |
| 动态依赖 | 采用下面的官方原始收集命令，保留动态 NSS 模块，没有改写参数或路径。 |
| 中文环境 | 第一次收集之后生成 `AppDir/lib/locale/zh_CN.utf8`，向现有 `.env` 追加模板规定的四项变量。 |

来源：[官方原始命令](https://github.com/pkgforge-dev/Antigravity-IDE-AppImage/blob/d4297876ff865da85f0dff592cc6ab39b51563f0/make-appimage.sh)。执行阶段为读取版本之后、生成中文 locale 之前：

```bash
quick-sharun ./AppDir/bin/* /usr/lib/libnss_nis.so* /usr/lib/libnsl.so* /usr/lib/libnss_mdns*_minimal.so*
```

## 原依赖覆盖

对照 [修改前脚本](https://github.com/newyorkthink/linux-packaging/blob/10e06eb96d94bcebe3ea2f508b0377852011d60a/antigravity-ide/build_antigravity-ide.sh)、公共基础包清单和当前 [AUR PKGBUILD](https://github.com/archlinux/aur/blob/antigravity-ide/PKGBUILD) 核对原安装项：

| 提供方式 | 原依赖 |
| --- | --- |
| 公共 `--base` | `gcc`、`base-devel`、`wget`、`binutils`、`patchelf`、`coreutils`、`appstream-glib`、`desktop-file-utils`、`util-linux`、`zsync`、`nss-mdns`、`nss`、`at-spi2-core`、`dbus`、`glib2`、`libxkbcommon`、`nspr`、`pango`、`ibus`、`debugedit` |
| 应用包声明的运行依赖 | `alsa-lib`、`cairo`、`expat`、`glibc`、`gtk3`、`libcups`、`libx11`、`libxcb`、`libxcomposite`、`libxdamage`、`libxext`、`libxfixes`、`libxrandr`、`mesa`、`systemd-libs` |
| 应用安装行显式保留 | `libnss_nis`、`bubblewrap`、`gcc-libs`、`gvfs`、`librsvg`、`libvdpau`、`xcb-util-wm`、`libxkbcommon-x11` |

`gcc-libs` 是原脚本已有依赖，本次在应用安装行保留；`fcitx5-gtk` 按标准模板准备 GTK 输入模块。没有因使用 `--base` 而省略未覆盖的原依赖。

## 未启用

独立协议 desktop 复制、自定义 DWARFS 压缩及额外 bwrap 收集均未启用。强制 locale 开关、自动更新 hook、GitHub 更新元数据、精简包替换、官方自动启动测试均未启用。具体原文、判断依据及影响见 [采用与不采用记录](pkgforge-differences.md)，不把未启用内容写成当前功能。

本次验证只覆盖脚本静态语法、官方代码原样性、参数和文档一致性；不代表应用运行、图形加速、沙箱或协议回调已通过。
