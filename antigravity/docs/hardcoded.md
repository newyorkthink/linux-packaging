# Antigravity 固定配置依据

核对日期：2026-10-30。当前脚本面向仓库的 Linux x86_64 构建；不因设置 `ARCH` 而支持下载其他架构。

| 固定项 | 当前值 | 依据与用途 |
| --- | --- | --- |
| 系统包 | `antigravity` | [AUR PKGBUILD](https://github.com/archlinux/aur/blob/antigravity/PKGBUILD)；先安装应用及声明的依赖。 |
| 下载页 | `https://antigravity.google/download` | [官方打包下载代码](https://github.com/pkgforge-dev/Antigravity-AppImage/blob/0aebfce24807ec0b6c2388305e604da5102ea4f8/get-dependencies.sh)；动态取得当前链接，不固定版本。 |
| URL 范围 | `storage.googleapis.com/antigravity-public/antigravity-hub/<版本>-<构建号>/linux-x64/Antigravity.tar.gz` | 与已核实的官方页面链接格式及原脚本来源对应；公共入口要求唯一匹配，版本取同一 URL。 |
| 归档、解包、版本临时文件 | `antigravity.tar.gz`、`antigravity-unpacked`、`antigravity.version` | 本应用目录内的构建中间文件。 |
| 归档根目录 | `Antigravity-*` | [AUR 解包与安装代码](https://github.com/archlinux/aur/blob/antigravity/PKGBUILD)；完整保留程序目录。 |
| 应用名、程序名、窗口类 | `Antigravity`、`antigravity`、`Antigravity` | [系统主 desktop](https://github.com/archlinux/aur/blob/antigravity/antigravity.desktop) 的应用标识、Exec 与 StartupWMClass；不使用 URL handler 代替主 desktop。 |
| 图标 | `/usr/share/pixmaps/antigravity.png` | AUR PKGBUILD 的图标安装路径，直接读取已安装文件。 |
| 主 desktop | `/usr/share/applications/antigravity.desktop` | AUR PKGBUILD 的 desktop 安装路径，直接交给 quick-sharun。 |
| 输出 | `dist/antigravity.AppImage`、`dist/version.txt` | 当前应用的固定产物名；封装成功后保存本次下载版本。 |
| 部署开关 | `DEPLOY_GTK=1`、`DEPLOY_OPENGL=1`、`DEPLOY_VULKAN=1` | GTK 使用标准模板；GL/Vulkan 原样保留官方与原构建已有的部署范围。 |
| 动态依赖 | `libnss_nis.so*`、`libnsl.so*`、`libnss_mdns*_minimal.so*`、`/usr/bin/bwrap` | [官方收集命令](https://github.com/pkgforge-dev/Antigravity-AppImage/blob/0aebfce24807ec0b6c2388305e604da5102ea4f8/make-appimage.sh)；处理不能仅依靠静态链接关系收集的模块与沙箱辅助程序。 |
| 中文环境 | `LANG=zh_CN.UTF-8`、`LANGUAGE=zh_CN:zh`、`LC_MESSAGES=zh_CN.UTF-8`、`LOCPATH=${SHARUN_DIR}/lib/locale` | 标准模板生成包内中文 locale 并在运行时定位。 |

没有设置强制 `DEPLOY_LOCALE`、`ADD_HOOKS` 或 `UPINFO`。这些未采用项的依据见 [官方处理判断](pkgforge-differences.md)。
