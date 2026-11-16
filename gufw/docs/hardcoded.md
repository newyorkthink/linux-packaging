# 固定配置

| 项目 | 值 | 依据 |
| --- | --- | --- |
| GTK | `DEPLOY_GTK_VERSION=3` | 上游 `gi.require_version('Gtk', '3.0')` |
| 主 desktop | `AppDir/usr/share/applications/gufw.desktop` | Gufw 上游 desktop 的 `Exec=gufw`、`Icon=gufw`，第二次 linuxdeploy 显式选择此入口，依据见[故障记录](./error.md) |
| 防火墙命令 | `/usr/sbin/ufw` | 上游 `UFW_PATH`。AppRun 只检查这个路径 |
| 宿主命令 PATH | `/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin` | `ufw_backend.py` 补丁使用这份路径，避免删除规则和启停时走包内 Python |
| 提权程序 | `/usr/bin/env` | 由 pkexec 或 sudo 提权后，通过该宿主命令恢复运行环境，再启动包内 Python |
| 运行副本 | `/tmp/gufw-runtime.*` | 普通文件系统，供 root 执行；`/tmp` 禁止执行时会失败 |
| Python 包名 | 由当前解释器版本组成；共享 `libpython` 仅在 `ldd` 实际找到时追加 | 不写死 `3.14`，也不把缺少共享库当成错误。resolute 目前的解释器在 `python3.14-minimal` |
| GTK 包名 | `libgtk-3-0t64` | 2026-11-16 核对 Ubuntu resolute 仍使用该包名 |
| GTK 插件变量 | 不写死目录 | `GTK_EXE_PREFIX`、`GTK_PATH`、`GTK_IM_MODULE_FILE` 取插件产物并改到当前根目录。输入法缓存必须是副本内的文件 |
| 界面语言 | `LANG=zh_CN.UTF-8`、`LANGUAGE=zh_CN:zh` | 软件包自带 `zh_CN` 翻译 |
| 库目录 | 同时加入 `usr/lib` 和 `usr/lib/x86_64-linux-gnu` | 只针对本次 x86_64 构建 |

这些值没有经过 AppImage 实机运行确认。
