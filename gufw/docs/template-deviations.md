# 模板差异

底稿是 `templates/appimage/linuxdeploy-gtk-apt.sh`。生成器只替换该模板的占位参数，不接受自定义代码块，也没有 APT 模板的应用准备阶段。标准生成结果不能表达下面的行为，所以本应用采用已验证的专用脚本，不走生成器。不新增模板。

例外只包括：

| 位置 | 差异 | 原因 |
| --- | --- | --- |
| 下载并准备应用 | 原生运行库从当前 Ubuntu 24.04 环境显式解包 `python3-minimal`、当前版本的 `pythonX.Y-minimal`、`pythonX.Y`、`libpythonX.Y-minimal`、`libpythonX.Y-stdlib`、`python3-gi` 和 GTK/GI 包。仅当 `ldd` 看到共享 `libpython` 时追加其软件包 | 公共解包入口不递归依赖。解释器可能静态链接 Python 核心，没有共享库时不能把空包名交给解包入口 |
| 下载并准备应用 | 通过公共签名 APT 下载入口从 `resolute / universe` 的 `amd64` 索引选择 `gufw` 的 `all` 包，仅解包界面应用 | 保留当前不依赖 WebKit 的应用版本，避免将 Ubuntu 26.04 的原生库带入包内；来源版本来自签名索引，原始 GLIBC 故障见 [README](../README.md#glibc-运行库兼容性) |
| 准备桌面资源和运行库 | 调用 `patches/prepare_gufw_sources.py` | 改界面路径、将三个窗口的绝对图标路径改为 `icon_name=gufw`、让普通规则与日志继承主题前景色、为配置文件导入导出指定宿主用户目录，并在 `ufw_backend.py` 的 `_run_cmd` 中清理宿主命令环境 |
| 准备 AppRun | 第二次 linuxdeploy 之前安装独立 `AppRun` | 正文较长，且必须在插件包装前就位 |
| 核心打包 | 增加三项 `--deploy-deps-only`，不增加 `--executable` | 桌面入口是脚本。`--deploy-deps-only` 只收集已经解包的 ELF 依赖，不复制第二个程序 |
| 核心打包 | 显式传入 `--desktop-file "$APPDIR/usr/share/applications/gufw.desktop"` | Python 运行包也提供 desktop，自动选择曾误用 Python 入口并导致中间封装失败，详见[构建故障记录](./error.md) |
| 运行 | 普通用户启动时将 AppDir 复制到 `/tmp`，再由 root 执行副本 | 为 root 提供可读取的普通文件系统路径，Gufw 保持 root 运行 |
| 运行 | 将插件写出的 `GTK_EXE_PREFIX`、`GTK_PATH`、`GTK_IM_MODULE_FILE` 改到临时副本，并由 `pass_env` 传给 root | 插件按挂载目录写这些变量。输入法缓存只接受副本内的 `immodules.cache`，避免 root 读到挂载目录或宿主机缓存 |
| 运行 | 先准备 `LOCPATH`，通过 `env` 为界面子进程传入中文 `LANG`、`LANGUAGE`、`LC_ALL`；主题使用 `Adwaita:dark` | 启动 Shell 保留宿主 locale，避免准备路径前切换中文时报警；子进程不受调用方 locale 覆盖，并覆盖插件的亮色回退 |
| 运行 | 已有 X11 Fcitx／IBus XIM 会话时使用 `GTK_IM_MODULE=xim`，保留宿主 `XMODIFIERS` | root 界面通过 XIM 输入，避免跨用户连接输入法 D-Bus；原生 Wayland 和未配置 XIM 的会话保持宿主模块 |
| 运行 | 不追加调用方的 `LD_LIBRARY_PATH` | 该值可能指向 FUSE 挂载，不能传给 root |

工作区、工具下载、空 AppDir、locale、`DEPLOY_GTK_VERSION=3`、官方 appimagetool 和版本文件仍用公共入口。hook 只由当前官方插件生成。整理产物阶段不删除、不补写 hook，也不覆盖 linuxdeploy 已经生成的顶层 `AppRun`。

用户实机验证通过，结果见 [README 实机验证](../README.md#实机验证)。
