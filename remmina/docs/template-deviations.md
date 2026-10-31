# Remmina 的 linuxdeploy 专属差异

本文件只记录专属处理；公共流程和固定注释遵循 [linuxdeploy 规范](../../linuxdeploy_projects.md)。

## 新入口与调用位置

| 脚本 | 调用位置 | 处理原因 |
| --- | --- | --- |
| `patches/prepare_runtime.sh <AppDir>` | 准备桌面资源和运行库，在第二次 linuxdeploy 前 | 处理发行版桌面入口，补入协议插件、中文翻译、WebKit 子进程及沙箱工具、FreeRDP 模块、OpenSSL legacy provider 和 GTK3 输入模块，供后续依赖部署。 |
| `patches/fix_runtime.sh <AppDir>` | 整理产物，在第二次 linuxdeploy 后、最终封装前 | 修正已部署文件中的 Remmina 插件、翻译及 WebKit 编译路径，移除临时 WebKit 扫描副本、宿主图形驱动库、glibc 运行库和未使用的 GStreamer MIDI 插件。 |

两个脚本直接处理已存在的 AppDir，不安装软件、不下载工具，也不解包或重新封装 AppImage。准备入口要求构建环境已安装上述资源；WebKit 子进程临时复制到 `usr/bin` 供依赖扫描，最终封装前由修复入口删除。修正后的插件和 WebKit 路径使用 `/proc/self/cwd`，AppRun 必须先切换到 AppDir。

完整 AppRun、Local Terminal / SSH 环境、GTK 输入模块缓存和 RDP 认证设置保留在主 build，不移入这两个入口。

## 公共入口

主 build 的工具准备复用 `common/linuxdeploy/prepare_linuxdeploy_tools.sh` 的 `gtk,gstreamer` 组合；APT 原布局解包复用 `common/apt/extract_installed_package.sh` 的附加软件包参数。参数说明见 [公共入口](../../common/README.md)，Remmina 的包名和资源清单由主 build 指定。

## AppRun 中保留的兼容处理

| 处理 | 原因 |
| --- | --- |
| Local Terminal 的 shell wrapper | Remmina 必须切换到 AppDir 加载相对插件和翻译；本地终端通过 wrapper 恢复启动目录及宿主 Shell。 |
| GTK3 输入模块缓存 | 模块路径包含每次启动的 AppImage 挂载目录，按宿主输入法提示或 Fcitx5 进程选择模块并生成缓存。 |
| OpenSSL provider 与 FreeRDP 模块目录 | 使用包内同源的 libcrypto、libssl 和 legacy provider，并从包内目录加载 FreeRDP 模块。 |
| 本地 / 工作组 RDP 认证默认值 | 仅在 `rdp_auth_filter` 缺失或为空时写入 `!kerberos,!u2u`，保留已有非空配置。 |
| 主题、WebKitGTK 与 GDK 图形配置 | 沿用现有主题跟随、禁用 DMABUF 渲染和禁用 GDK OpenGL 的兼容设置。 |

协议及 WebKitGTK 模块通过精确的 `-l` 参数交给 linuxdeploy；GTK 输入模块及其他原布局运行库由 `usr/lib` 扫描收集依赖。`NO_STRIP=1` 和 `GSTREAMER_INCLUDE_BAD_PLUGINS=1` 沿用原构建设置，不作为其他 GTK 项目的默认值。

## 当前状态

两个 `patches` 入口已接入主 build，Remmina job 直接使用 `ubuntu-24.04`，不使用 Docker。workflow 已移除旧 `fix_remmina_webkit.sh` 调用；旧脚本保留为历史文件，不与新入口同时执行。新链路已做语法和静态衔接检查，尚未实际构建或实机验证。
