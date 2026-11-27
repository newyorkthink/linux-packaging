# 从 i3wm AppImage 启动别的程序

本页记录通过 `i3.AppImage`（当前采用 `quick-sharun` 路线打包的 X11 窗口管理器）启动外部程序时出现过的两类实际问题与源码级根因。某个程序只有从 `i3.AppImage` 启动才异常、或换回旧版 `i3.AppImage` 就恢复正常时，先对照本页核查，不要急着修改被启动应用的构建脚本，也不要反复改写已经标准化的 `i3wm/build_i3wm.sh`。

---

## 一、2026-11-27 案例：脚本已标准化且 `i3` 本体未变，为何新版 `i3.AppImage` 仍导致部分外部程序异常

### 实机现象

2026-11-27 将 [i3wm/build_i3wm.sh](../../i3wm/build_i3wm.sh) 按标准模板重写并重新构建后，新版 `i3.AppImage` 本身启动、`i3 --version`（`4.25.1`）、窗口平铺与状态栏运行正常，但从新版 `i3.AppImage` 会话中启动的部分外部程序出现异常：

- 独立截图工具直接段错误退出（`segmentation fault (core dumped)`）。
- 商业终端客户端的本地会话启动时闪退。
- 重启 X11 并切回此前构建的旧版 `i3.AppImage`（同为 `4.25.1`）后，上述两项故障立即消失。

### 已核实的对比证据（排除了脚本漏改与 `i3` 版本问题）

1. **脚本差异排查**：核对标准化前后的 `git diff -- i3wm/build_i3wm.sh`，确认 20 个内置入口、依赖列表、`STARTUPWMCLASS="i3"`、`PATH_MAPPING` 及默认配置复制均完整保留，没有功能遗漏。
2. **新旧成品解包逐字节比对**：解包并对比可正常使用的旧版 `i3.AppImage`（2026-09-17 构建，约 17.0 MB）与新版 `i3.AppImage`（2026-11-27 构建，约 14.2 MB）：
   - 两版包内的 `shared/bin/i3`（`4.25.1`，`539,360` 字节）及全部 12 个 ELF 二进制完全**逐字节一致**。
   - 两版的 `.env`、`path-mapping.so`、`libxcb*` 与 `libxkbcommon*` 均未出现导致上述崩溃的缺失或变更。
   - 真正发生变化的是构建时动态拉取的上游 **`pkgforge-dev/Anylinux-sharun` 运行时版本**：旧版为 **`3.2.2`**，新版为 **`3.11.0`**。

### 源码级根因：窗口管理器通过 `execl` 派生子进程，而上游 `anylinux.so` 在 `3.2.2 → 3.11.0` 改变了 `execl` 拦截行为

- **i3 的子进程启动方式**：`i3` 作为 X11 窗口管理器，是整个桌面会话所有快捷键程序、终端、托盘工具与嵌套 AppImage 的父进程。根据上游源码 `i3/src/startup.c`，`i3` 启动外部命令固定调用 `execl("/bin/sh", "/bin/sh", "-c", command, NULL)`（`i3bar` 同样通过 `execl` 调用 `/bin/sh -c`）。
- **旧版 `Anylinux-sharun 3.2.2` 的实际行为**：`AppRun.lib` 在启动 `i3` 时会把 `XDG_CACHE_HOME` 改写为 `~/.cache/AppImage-Cache`，并设置 `PATH_MAPPING`、`GCONV_PATH`、`PERLLIB`、`GSETTINGS_SCHEMA_DIR` 等包装环境变量。`3.2.2` 版本的 `anylinux.so` 虽然拦截了 `execve` / `execvp` 等函数，但**没有拦截 `execl` / `execle` / `execlp`**。因此，在旧版 `i3.AppImage` 会话下，所有通过 `i3` 的 `execl` 启动的桌面子进程长期意外继承了改写后的环境（例如 `XDG_CACHE_HOME=~/.cache/AppImage-Cache`）。
- **新版 `Anylinux-sharun 3.11.0` 的上游改动**：上游在 2026-11-11 的 PR #56 / #57 中为 `anylinux.so` 补齐了 `execl` / `execle` / `execlp` 拦截，使 `i3` 派生子进程时开始执行环境还原，将 `XDG_CACHE_HOME` 恢复为宿主默认值（`~/.cache`），并同步引入 `SHARUN_BIN_NAME`、`HOST_KERNEL_VERSION`、包内 `dash` 与部分运行库 stub（已核对 `old-linux-kernel-compat-layer` 在较新内核上不激活）。
- **为什么标准化后仍会踩雷**：
  - 本仓库的“标准化”只统一了 `build_i3wm.sh` 的模板结构、依赖安装、工作区与版本入口，**无法冻结 `quick-sharun` 每次构建动态拉取的上游 `Anylinux-sharun` 运行时行为**。
  - 普通单一应用升级 `Anylinux-sharun` 通常只影响自己；但 `i3` 是整个桌面会话的根父进程，上游只要调整 `anylinux.so` 对 `execl` 或环境变量的拦截与恢复逻辑，就会一次性改变整棵桌面子进程树看到的运行环境与缓存路径，进而诱发对旧缓存目录或 `exec` 环境敏感的外部程序出现段错误或会话闪退。

### 决策与备选退路

- **当前策略**：暂不改动正式 `i3wm/build_i3wm.sh` 路线，也**不修改**被启动应用的打包脚本；有稳定旧版 `i3.AppImage` 的环境可继续沿用旧版，暂不用每日构建出的 `quick-sharun` 新版直接覆盖。
- **已准备的备选方案**：在 [Temporary/i3wm/](../../Temporary/i3wm/README.md) 暂存了基于 Ubuntu 24.04 + `linuxdeploy` + 原生 `appimagetool` 的完整备选草稿（`build_i3wm_linuxdeploy.sh` 与官方 SVG 图标）。该路线不含 `anylinux.so` / `LD_PRELOAD`，全部包内 ELF 通过 `RPATH` 查找随包运行库，根 `AppRun` 不导出 `LD_LIBRARY_PATH` 且清除 `APPDIR` / `APPIMAGE` / `ARGV0` / `OWD`。
- **切换前的关键提醒**：`linuxdeploy` 路线虽然能彻底摆脱上游 `Anylinux-sharun` 的运行时拦截与库路径污染，但它同样使用宿主默认的 `XDG_CACHE_HOME`（`~/.cache`），不会指向 `~/.cache/AppImage-Cache`。将来切换实机测试时，若个别外部程序仍出现崩溃，需同步检查该程序自身在 `~/.cache` 中的缓存文件，不要直接误判为 `linuxdeploy` 打包失败。

---

## 二、2026-09-24 案例：WPS 从 `i3.AppImage` 直接启动时的库路径与挂载点泄漏

### 实机情况

i3 自己也是本仓库打的 AppImage。从它里面再启动另一个 AppImage，有时行，有时不行。WPS 这次的结果：

| 启动方式 | 结果 |
| --- | --- |
| 终端直接运行 `wps.AppImage` | 能开。主页、文字、演示是中文，文字稿和幻灯片里能打中文 |
| Rofi | `44ea0d4` 这版能开。用户确认下的就是这一版 |
| i3 用 `i3-msg exec` 直接跑同一个文件 | 出现过起不来 |

Rofi 能开，不能当成 i3 直接执行也没问题。其他 quick 包从同一个 i3 开过，没有这现象。WPS 特殊在它带一套自己编译的 Qt。

### 坏的时候日志是什么

先有 `awk: cannot open "1830"`。这句不是退出原因，程序还在往下跑。

接着是：

```text
qt.qpa.plugin: Could not load the Qt platform plugin "xcb" in "" even though it was found.
Cannot load library .../office6/qt/plugins/platforms/libqxcb.so: (libxkbcommon-x11.so.0: 无法打开共享目标文件：没有那个文件或目录)
```

然后 `bin/wps` 启动 `office6` 程序的那一行段错误。终端里没有 i3 这套环境，所以能开。

`QT_DEBUG_PLUGINS=1` 才会打出缺的是哪个库。没这行之前，只看到 `xcb` 插件加载失败，不够用来改。

### 原因与避坑记录

i3 这个 AppImage 启动别的程序时，会把自己的库搜索路径传下去。终端能看到的系统库，这条路径里不一定还在。WPS 的 `libqxcb.so` 要 `libxkbcommon-x11.so.0`，系统里有这份库，终端找得到，从 i3 启动时找不到，插件就加载失败。

已经试过、不要再照做的改法：

- 把整个 `AppDir/lib` 放进 `LD_LIBRARY_PATH`。这个目录里有包内的 `libc.so.6`，系统的 `bash` 和 `grep` 会加载它，报 `__pointer_chk_guard`。
- 用上级传下来的 `SHARUN_DIR` 当本包目录。那可能是 i3 的挂载点，会把本包自己的 `.mount_` 库路径丢掉。

`44ea0d4` 把 `libxkbcommon-x11.so.0`、`libxkbcommon.so.0`、`libxcb-xkb.so.1` 放进了 `office6`。2026-09-24 下载 Release 里的 `wps.AppImage` 核对过，`office6/` 和 `lib/` 里都有 `libxkbcommon-x11.so.0`。这没有消除“从 i3 直接执行有时起不来”这条记录。

---

## 三、后续 AI 排查与维护必查清单

每当再次遇到“只有从 `i3.AppImage` 启动才坏”、或准备重新评估新版 `quick-sharun` `i3.AppImage` 时，按下面顺序核查：

1. **先查上游运行时版本，再看本仓库脚本**：
   - 必须先核对上游 **`pkgforge-dev/Anylinux-sharun`**（`anylinux.so`、`AppRun.lib`、`path-mapping.so`）与 **`pkgforge-dev/Anylinux-AppImages`**（`quick-sharun`）的最新版本及近期变更日志。
   - 重点检查 `execl` / `execve` 拦截、`XDG_CACHE_HOME`、`PATH_MAPPING`、`LD_LIBRARY_PATH`、`SHARUN_DIR` / `APPDIR` 清理逻辑是否有新变动，再核对本次 `i3` 本体版本是否真的发生变化。
2. **三项不要盲目做的操作**：
   - **不要**未经对比就断定是已标准化的 `i3wm/build_i3wm.sh` 漏改参数而反复折腾构建脚本；
   - **不要**在未定位子进程环境差异前，擅自修改被 `i3` 启动的其他应用的构建脚本；
   - **不要**把整个 `AppDir/lib` 塞进 `LD_LIBRARY_PATH`，也不要在任何其他 AppImage 中沿用外层传下来的 `SHARUN_DIR` 或 `APPDIR`。
3. **定位单应用缺失库时的核对方法**：
   - 必须用 `i3` 自己启动复现，不要用终端里开的 Rofi 代替；
   - Qt 程序加上 `QT_DEBUG_PLUGINS=1`，看 `Cannot load library` 后面具体缺的文件名，只把缺的库放进该程序已经在用的私有库目录。
4. **评估路线切换**：
   - 若上游 `Anylinux-sharun` 仍持续带来窗口管理器子进程环境波动，按 [Temporary/i3wm/README.md](../../Temporary/i3wm/README.md) 核对并经用户逐次授权后，评估正式切换为 `build_i3wm_linuxdeploy.sh`（同时将原脚本更名为 `build_i3wm_anylinux.sh`）。
