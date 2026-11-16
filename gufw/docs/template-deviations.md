# 模板差异

底稿是 `templates/appimage/linuxdeploy-gtk-apt.sh`。生成器只替换该模板的占位参数，不接受自定义代码块，也没有 APT 模板的应用准备阶段。标准生成结果不能表达下面的行为，所以本应用拟不走生成器，保留专用脚本。不新增模板。

例外只包括：

| 位置 | 差异 | 原因 |
| --- | --- | --- |
| 下载并准备应用 | 除 `gufw` 外，显式解包 `python3-minimal`、当前版本的 `pythonX.Y-minimal`、`pythonX.Y`、`libpythonX.Y-minimal`、`libpythonX.Y-stdlib`、`python3-gi` 和 GTK/GI 包。仅当 `ldd` 看到共享 `libpython` 时追加其软件包 | 公共解包入口不递归依赖。解释器可能静态链接 Python 核心，没有共享库时不能把空包名交给解包入口 |
| 准备桌面资源和运行库 | 调用 `patches/prepare_gufw_sources.py` | 改界面路径，并在 `ufw_backend.py` 的 `_run_cmd` 中清理宿主命令环境 |
| 准备 AppRun | 第二次 linuxdeploy 之前安装拟采用的独立 `AppRun` | 正文较长，且必须在插件包装前就位 |
| 核心打包 | 增加三项 `--deploy-deps-only`，不增加 `--executable` | 桌面入口是脚本。`--deploy-deps-only` 只收集已经解包的 ELF 依赖，不复制第二个程序 |
| 运行 | 普通用户启动时将 AppDir 复制到 `/tmp`，再由 root 执行副本 | 为 root 提供可读取的普通文件系统路径，Gufw 保持 root 运行 |
| 运行 | 将插件写出的 `GTK_EXE_PREFIX`、`GTK_PATH`、`GTK_IM_MODULE_FILE` 改到临时副本，并由 `pass_env` 传给 root | 插件按挂载目录写这些变量。输入法缓存只接受副本内的 `immodules.cache`，避免 root 读到挂载目录或宿主机缓存 |
| 运行 | 不追加调用方的 `LD_LIBRARY_PATH` | 该值可能指向 FUSE 挂载，不能传给 root |

工作区、工具下载、空 AppDir、locale、`DEPLOY_GTK_VERSION=3`、官方 appimagetool 和版本文件仍用公共入口。hook 只由当前官方插件生成。整理产物阶段不删除、不补写 hook，也不覆盖 linuxdeploy 已经生成的顶层 `AppRun`。
