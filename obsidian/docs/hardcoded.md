# Obsidian 固定配置说明

本文件记录 [build_obsidian.sh](../build_obsidian.sh) 使用的固定名称、来源和运行资源路径。应用专属处理及上游对照见 [模板差异说明](./template-deviations.md)。

## 程序来源与安装包

| 固定值 | 来源与作用 |
| --- | --- |
| `obsidian-bin` | [AUR obsidian-bin](https://aur.archlinux.org/packages/obsidian-bin)；安装应用及提供桌面资源，最终程序取自第二阶段下载的官方 DEB。[AUR PKGBUILD](https://github.com/archlinux/aur/blob/e89ed1447d267e208b01482bb78c9f6c3e5d45e7/PKGBUILD) 同样使用官方 DEB。 |
| `obsidianmd/obsidian-releases`，标签前缀 `v` | [Obsidian 官方 Releases](https://github.com/obsidianmd/obsidian-releases/releases)；匹配正式桌面版本。 |
| `obsidian_{version}_amd64.deb` | 官方 Linux x86_64 DEB 资产名；版本由公共解析器动态选择，不写死当前版本。 |
| `obsidian`、`amd64` | DEB 预期包名和架构，公共入口在下载后核对。 |
| `opt/Obsidian` | 官方 DEB 内的 Electron 主程序目录，完整复制到 `AppDir/bin`。 |
| `work/app.deb`、`work/unpacked`、`work/source-version.txt` | 应用构建工作目录内的下载、解包和版本记录文件。 |

## 桌面资源及启动元数据

| 固定值 | 来源与作用 |
| --- | --- |
| `APPNAME=Obsidian`、`MAIN_BIN=obsidian` | 产品名称与主程序文件名。 |
| `STARTUPWMCLASS=obsidian` | 沿用本仓库原 Obsidian 脚本的窗口类参数；pkgforge-dev 上游 desktop 使用不同的 `md.obsidian.Obsidian`，本次不修改当前值。 |
| `/usr/share/icons/hicolor/512x512/apps/obsidian.png` | 构建脚本指定的系统图标路径，供 quick-sharun 使用。 |
| `/usr/share/applications/md.obsidian.Obsidian.desktop` | Obsidian 官方 DEB 使用的 desktop 文件名；AUR `obsidian-bin` 直接解包官方 DEB。GitHub Actions 构建记录 `42482368145` 曾因旧路径 `/usr/share/applications/obsidian.desktop` 不存在而失败，现改用包内实际名称。 |
| `obsidian.AppImage`、`dist/version.txt` | 原应用发布资产名和统一版本元数据路径。 |

## 应用专属依赖与扫描目标

OpenGL、Vulkan 和 PipeWire 配置逐项对应原脚本已有的 `DEPLOY_OPENGL=1`、`DEPLOY_VULKAN=1` 和 `DEPLOY_PIPEWIRE=1`。运行依赖的补充范围、公共基础包覆盖关系见 [模板差异说明](./template-deviations.md)。

`./AppDir/bin/*` 以程序目录为初始扫描目标；`/usr/bin/hostname` 为辅助命令；`/usr/lib/libnss*`、`/usr/lib/libsoftokn3.so`、`/usr/lib/libfreeblpriv3.so`、`/usr/lib/pkcs11/*` 为 NSS 相关库及模块；`/usr/lib/gtk-3.0/3.0.0/immodules/im-ibus.so` 为 GTK3 IBus 输入模块。这些路径是原 Obsidian 构建脚本已有的 Arch 构建环境路径，并非面向任意系统的通用示例。

没有添加上游自更新参数或命名空间 hook。`build_obsidian.sh` 已替换为现行 DEB 构建脚本，清单中的执行路径保持不变；对应取舍见 [上游处理取舍](./pkgforge-differences.md)。
