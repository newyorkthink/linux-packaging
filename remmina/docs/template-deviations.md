# Remmina 的 linuxdeploy 专属差异

本文件只记录专属处理；公共流程和固定注释遵循 [linuxdeploy 规范](../../linuxdeploy_projects.md)。

## 新入口与调用位置

| 脚本 | 调用位置 | 处理原因 |
| --- | --- | --- |
| `patches/prepare_runtime.sh <AppDir>` | 准备桌面资源和运行库，在第二次 linuxdeploy 前 | 处理发行版桌面入口，补入协议插件、中文翻译、WebKit 子进程及沙箱工具、FreeRDP 模块、OpenSSL legacy provider 和 GTK3 输入模块，供后续依赖部署。 |
| `patches/fix_runtime.sh <AppDir>` | 整理产物，在第二次 linuxdeploy 后、最终封装前 | 修正已部署文件中的 Remmina 插件、翻译及 WebKit 编译路径，移除临时 WebKit 扫描副本、宿主图形驱动库、glibc 运行库和未使用的 GStreamer MIDI 插件。 |

两个脚本直接处理已存在的 AppDir，不安装软件、不下载工具，也不解包或重新封装 AppImage。准备入口要求构建环境已安装上述资源；WebKit 子进程临时复制到 `usr/bin` 供依赖扫描，最终封装前由修复入口删除。修正后的插件和 WebKit 路径使用 `/proc/self/cwd`，AppRun 必须先切换到 AppDir。

后续迁移时，完整 AppRun、Local Terminal / SSH 环境、GTK 输入模块缓存和 RDP 认证设置保留在主 build，不移入这两个入口。

## 公共入口

后续主 build 的工具准备复用 `common/linuxdeploy/prepare_linuxdeploy_tools.sh` 的 `gtk,gstreamer` 组合；APT 原布局解包复用 `common/apt/extract_installed_package.sh` 的附加软件包参数。参数说明见 [公共入口](../../common/README.md)，Remmina 的包名和资源清单由主 build 指定。

## 当前状态

新入口尚未接入。当前 `build_remmina.sh`、workflow 和仍被调用的 `fix_remmina_webkit.sh` 保持原样；后续获准迁移调用方时再切换，不同时执行新旧修复。本次不进行实际构建或运行验证。
