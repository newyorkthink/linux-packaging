# Antigravity IDE 固定配置依据

核对日期：2026-10-30。当前脚本面向仓库的 Linux x86_64 构建；不因设置 `ARCH` 而支持下载其他架构。

| 固定项 | 当前值 | 依据与用途 |
| --- | --- | --- |
| 系统包 | `antigravity-ide` | [AUR PKGBUILD](https://github.com/archlinux/aur/blob/antigravity-ide/PKGBUILD)；先安装应用及声明的依赖。 |
| 下载页 | `https://antigravity.google/download` | [官方打包下载代码](https://github.com/pkgforge-dev/Antigravity-IDE-AppImage/blob/d4297876ff865da85f0dff592cc6ab39b51563f0/get-dependencies.sh)；动态取得当前链接，不固定版本。 |
| URL 范围 | `edgedl.me.gvt1.com/edgedl/release2/.../stable/<版本>-<构建号>/linux-x64/Antigravity%20IDE.tar.gz` | 与已核实的官方页面链接格式及原脚本来源对应；公共入口要求唯一匹配，版本取同一 URL。 |
| 归档、解包、版本临时文件 | `antigravity-ide.tar.gz`、`antigravity-ide-unpacked`、`antigravity-ide.version` | 本应用目录内的构建中间文件。 |
| 归档根目录 | `Antigravity IDE` | [AUR 解包与安装代码](https://github.com/archlinux/aur/blob/antigravity-ide/PKGBUILD)；完整保留程序目录。 |
| 应用名、程序名、窗口类 | `Antigravity IDE`、`antigravity-ide`、`antigravity-ide` | [系统主 desktop](https://github.com/archlinux/aur/blob/antigravity-ide/antigravity-ide.desktop) 的应用标识、Exec 与 StartupWMClass；不使用 URL handler 代替主 desktop。 |
| 图标 | `/usr/share/pixmaps/antigravity-ide.png` | AUR PKGBUILD 的图标安装路径，直接读取已安装文件。 |
| 主 desktop | `/usr/share/applications/antigravity-ide.desktop` | AUR PKGBUILD 的 desktop 安装路径，直接交给 quick-sharun。 |
| 输出 | `dist/antigravity-ide.AppImage`、`dist/version.txt` | 当前应用的固定产物名；封装成功后保存本次下载版本。 |
| 部署开关 | `DEPLOY_GTK=1`、`DEPLOY_OPENGL=1`、`DEPLOY_VULKAN=1` | GTK 使用标准模板；GL/Vulkan 原样保留官方与原构建已有的部署范围。 |
| 动态依赖 | `libnss_nis.so*`、`libnsl.so*`、`libnss_mdns*_minimal.so*` | [官方收集命令](https://github.com/pkgforge-dev/Antigravity-IDE-AppImage/blob/d4297876ff865da85f0dff592cc6ab39b51563f0/make-appimage.sh)；处理不能仅依靠静态链接关系收集的模块。 |
| 中文环境 | `LANG=zh_CN.UTF-8`、`LANGUAGE=zh_CN:zh`、`LC_MESSAGES=zh_CN.UTF-8`、`LOCPATH=${SHARUN_DIR}/lib/locale` | 标准模板生成包内中文 locale 并在运行时定位。 |

没有固定 DWARFS 压缩参数，也没有独立协议入口路径。没有设置强制 `DEPLOY_LOCALE`、`ADD_HOOKS` 或 `UPINFO`。这些未采用项的依据见 [官方处理判断](pkgforge-differences.md)。
