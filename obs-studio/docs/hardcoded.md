# OBS Studio 写死的路径

本页保存路径依据与原始故障记录。当前构建原样采用官方通配收集命令，已覆盖的模块和脚本目录不再逐个追加参数；共享数据由工具扫描收集。下列旧章节保留当时的处理与判断，当前取舍以新增的更正记录和 [官方处理取舍](./pkgforge-differences.md) 为准。

## `/usr/lib/obs-modules`

- 为什么写死：OBS 33 已经没有 `/usr/lib/obs-plugins`。模块在这个目录，例如 `core/obs-browser.so`。
- 写死的内容：`/usr/lib/obs-modules`
- 作用：和主程序同一次交给 `quick-sharun`。
- 当初报错全文：

```text
'/usr/lib/obs-plugins' is NOT present!
Process completed with exit code 1.
```

当时检测到的版本是 OBS Studio 33.0.0。

## `/usr/share/obs`

- 为什么写死：模块的语言、浏览器页面和主题在这个数据目录。
- 写死的内容：`/usr/share/obs`
- 作用：把这些数据一起收进包。
- 当初报错：同上。旧脚本还写了 `/usr/lib/cef`。OBS 33.0.0 的官方包文件列表里没有这个路径。

## `/usr/bin/obs-ffmpeg-mux`

- 为什么写死：这是 OBS 录制时自己拉起的程序。
- 写死的内容：`/usr/bin/obs-ffmpeg-mux`
- 作用：和主程序一起进包。
- 当初报错：同上。构建停在不存在的插件目录，还没有跑到缺这个程序。

## `/usr/lib/obs-scripting`

- 为什么写死：OBS 的 Python 脚本模块在这个目录，不在 `/usr/lib/obs-modules`。
- 写死的内容：`/usr/lib/obs-scripting`
- 作用：和主程序同一次交给 `quick-sharun`，让包里有 `obspython.py` 和 `_obspython.so`。
- 当初报错全文：

```text
warning: [Python] Python failure in obs_scripting_load_python:1707:
ModuleNotFoundError: No module named 'obspython'
warning: [Python] Error importing obspython.py', unloading obs-python
warning: [Python] Failed to load python plugin
```

## 2026-10-30：采用官方配置并更正 CEF 路径判断

官方来源为 [`make-appimage.sh`，commit `8c17c157a498876f75b84cb0a30307aba641b396`](https://github.com/pkgforge-dev/OBS-Studio-AppImage/blob/8c17c157a498876f75b84cb0a30307aba641b396/make-appimage.sh)。本次原样采用两项 export 和完整收集命令，不把新增配置描述成已经复现并修复的运行故障；官方未说明逐项原因。

| 固定内容 | 采用依据与作用 | 原始故障记录 |
| --- | --- | --- |
| `export DEPLOY_SDL=1` | 本次明确选择的官方配置；强制启用工具的 SDL 部署分支，处理构建环境中实际存在的相关运行库。 | 未有该开关对应的独立原始报错，不虚构缺少 SDL 的故障。 |
| `export PATH_MAPPING_HARDCODED='libobs.so*'` | 本次明确选择的官方配置；按文件名指定 libobs 的系统路径处理，影响包内二进制和工具生成的临时路径 hook。 | 未有该开关对应的独立原始报错；不能将旧模块目录错误当作已证明必须启用此开关的证据。 |
| `/usr/bin/obs*` | 官方原文；当前包提供主程序、录制辅助程序及其他 OBS 辅助入口。 | 原有录制辅助程序处理背景见前文，未出现新的独立报错。 |
| `/usr/lib/obs*` | 官方原文；当前包提供 `obs-modules` 与 `obs-scripting`，通配符覆盖两者。 | 原始模块目录错误和 `ModuleNotFoundError: No module named 'obspython'` 全文保留在前文。 |
| `/usr/lib/libobs*` | 官方原文；显式收集 libobs 相关库。 | 未有该参数对应的独立原始报错。 |
| `/usr/lib/cef` | 官方原文；由 `obs-studio` 的独立 `cef` 依赖包提供，包含动态库、语言包和其他数据。 | 旧记录中的“不存在”是文件来源判断错误，不是已经取得该目录缺失的原始报错。 |
| `/usr/lib/libluajit*.so*` | 官方原文；显式收集 LuaJIT 运行库，`luajit` 是当前软件包依赖。 | 未有该参数对应的独立原始报错。 |

此前只查看 `obs-studio` 自己的文件列表，遗漏了独立的 `cef` 包，因此把 `/usr/lib/cef` 判定为不存在。该判断已被当前 [CEF 文件列表](https://archlinux.org/packages/extra/x86_64/cef/files/) 否定，旧记录只作为当时判断保留，不能再用于删除当前官方参数。

`/usr/share/obs` 仍是当前包的数据目录；官方命令没有将它显式列为参数，quick-sharun 默认按已收集程序名扫描数据目录。该覆盖关系来自 [工具源码](https://github.com/pkgforge-dev/Anylinux-AppImages/blob/862becf483277b2d2576cbc3fec6284489efd4ea/useful-tools/quick-sharun.sh) 的核查，不是对新产物或实机结果的确认。
