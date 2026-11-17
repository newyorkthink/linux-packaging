# 固定配置

| 项目 | 值 | 依据 |
| --- | --- | --- |
| 构建基线 | Ubuntu 24.04，glibc 2.39 | 原包运行时要求宿主缺少的 `GLIBC_2.43`，原始错误见 [README 修复记录](../README.md#glibc-运行库兼容性)。Python、GTK 和原生依赖只来自该构建环境 |
| 应用来源 | `https://archive.ubuntu.com/ubuntu`、`resolute`、`universe`、`gufw`，DEB 架构 `all`、索引架构 `amd64` | [官方当前包](https://packages.ubuntu.com/resolute/gufw) 无 WebKit 依赖；Noble 旧包仍需要 WebKit，故只下载并解包当前应用包，不安装跨发行版的原生库。版本和 DEB 地址取自签名索引，不固定版本 |
| 官方归档公钥 | `https://archive.ubuntu.com/ubuntu/project/ubuntu-archive-keyring.gpg` | [官方归档目录](https://archive.ubuntu.com/ubuntu/project/) 提供；公共入口验证 `InRelease`、索引与 DEB 摘要及包身份 |
| GTK | `DEPLOY_GTK_VERSION=3` | 上游 `gi.require_version('Gtk', '3.0')` |
| 主 desktop | `AppDir/usr/share/applications/gufw.desktop` | Gufw 上游 desktop 的 `Exec=gufw`、`Icon=gufw`，第二次 linuxdeploy 显式选择此入口，依据见[故障记录](./error.md) |
| 防火墙命令 | `/usr/sbin/ufw` | 上游 `UFW_PATH`。AppRun 只检查这个路径 |
| 宿主命令 PATH | `/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin` | `ufw_backend.py` 补丁使用这份路径，避免删除规则和启停时走包内 Python |
| 提权程序 | `/usr/bin/env` | 由 pkexec 或 sudo 提权后，通过该宿主命令恢复运行环境，再启动包内 Python |
| 运行副本 | `/tmp/gufw-runtime.*` | 普通文件系统，供 root 执行；`/tmp` 禁止执行时会失败 |
| Python 包名 | 由当前解释器版本组成；共享 `libpython` 仅在 `ldd` 实际找到时追加 | 不写死 `3.14`，也不把缺少共享库当成错误。[Noble 当前解释器](https://packages.ubuntu.com/noble/python3-minimal) 为 Python 3.12，应用脚本仍从实际解释器动态读取系列号 |
| GTK 包名 | `libgtk-3-0t64` | [Ubuntu Noble](https://packages.ubuntu.com/noble/libgtk-3-0t64) 使用该包名，与本次原生运行库基线一致 |
| GTK 插件变量 | 不写死目录 | `GTK_EXE_PREFIX`、`GTK_PATH`、`GTK_IM_MODULE_FILE` 取插件产物并改到当前根目录。输入法缓存必须是副本内的文件 |
| 界面语言 | `LANG=zh_CN.UTF-8`、`LANGUAGE=zh_CN:zh`、`LC_ALL=zh_CN.UTF-8` | 软件包自带 `zh_CN` 翻译；先准备包内 `LOCPATH`，再通过 `env` 为界面子进程传入中文配置，避免调用方覆盖。启动 Shell 沿用宿主 locale，不提前触发中文 locale 加载。原始 locale 警告及复现结果见 [README 修复记录](../README.md#中文-locale深色主题窗口图标与-x11-输入) |
| 主界面主题 | `GTK_THEME=Adwaita:dark` | 按已选择的深色界面覆盖插件亮色回退；隔离 GTK 界面测试通过，Polkit 对话框仍由宿主控制；普通规则与日志使用主题前景色，保留原有状态色 |
| X11 root 输入 | 已有 Fcitx／IBus XIM 会话时 `GTK_IM_MODULE=xim` | 保留宿主 `XMODIFIERS`，通过 XIM 输入；原生 Wayland 与未配置 XIM 的会话不强制修改模块 |
| 窗口图标 | `icon_name=gufw` | 三个 UI 文件原本写死宿主 PNG 路径并报缺图；改从包内 hicolor 图标资源查找 |
| 库目录 | 同时加入 `usr/lib` 和 `usr/lib/x86_64-linux-gnu` | 只针对本次 x86_64 构建 |

用户已实测正式产物的图形授权与主窗口启动；本次中文菜单、深色主题、窗口图标及输入模块配置通过隔离 GTK 测试。用户后续实测已确认图形授权后的深色界面、中文菜单与 X11 中文输入正常。

用户实机验证通过，结果见 [README 实机验证](../README.md#实机验证)。
