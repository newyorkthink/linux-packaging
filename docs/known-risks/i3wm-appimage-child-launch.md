# 从 i3wm AppImage 启动别的程序

2026-09-24，WPS 上看到的。先别改别的构建脚本。某个程序只有从 i3 启动才坏时，先对照这里。

## 实机情况

i3 自己也是这个仓库打的 AppImage。从它里面再启动另一个 AppImage，有时行，有时不行。

WPS 这次的结果：

| 启动方式 | 结果 |
| --- | --- |
| 终端直接运行 `wps.AppImage` | 能开。主页、文字、演示是中文，文字稿和幻灯片里能打中文 |
| Rofi | `44ea0d4` 这版能开。用户确认下的就是这一版 |
| i3 用 `i3-msg exec` 直接跑同一个文件 | 出现过起不来 |

Rofi 能开，不能当成 i3 直接执行也没问题。其他 quick 包从同一个 i3 开过，没有这现象。WPS 特殊在它带一套自己编译的 Qt。

## 坏的时候日志是什么

先有 `awk: cannot open "1830"`。这句不是退出原因，程序还在往下跑。

接着是：

```text
qt.qpa.plugin: Could not load the Qt platform plugin "xcb" in "" even though it was found.
Cannot load library .../office6/qt/plugins/platforms/libqxcb.so: (libxkbcommon-x11.so.0: 无法打开共享目标文件：没有那个文件或目录)
```

然后 `bin/wps` 启动 `office6` 程序的那一行段错误。终端里没有 i3 这套环境，所以能开。

`QT_DEBUG_PLUGINS=1` 才会打出缺的是哪个库。没这行之前，只看到 `xcb` 插件加载失败，不够用来改。

## 原因

i3 这个 AppImage 启动别的程序时，会把自己的库搜索路径传下去。终端能看到的系统库，这条路径里不一定还在。

WPS 的 `libqxcb.so` 要 `libxkbcommon-x11.so.0`。系统里有这份库，终端找得到。从 i3 启动时找不到，插件就加载失败。

已经试过、不要再照做的改法：

- 把整个 `AppDir/lib` 放进 `LD_LIBRARY_PATH`。这个目录里有包内的 `libc.so.6`，系统的 `bash` 和 `grep` 会加载它，报 `__pointer_chk_guard`。
- 用上级传下来的 `SHARUN_DIR` 当本包目录。那可能是 i3 的挂载点，会把本包自己的 `.mount_` 库路径丢掉。

`44ea0d4` 把 `libxkbcommon-x11.so.0`、`libxkbcommon.so.0`、`libxcb-xkb.so.1` 放进了 `office6`。2026-09-24 下载 Release 里的 `wps.AppImage` 核对过，`office6/` 和 `lib/` 里都有 `libxkbcommon-x11.so.0`。这没有消除“从 i3 直接执行有时起不来”这条记录。

## 别的程序如果只有从 i3 启动才坏

1. 用 i3 自己启动一次，不要用终端里开的 Rofi 代替。
2. Qt 程序加上 `QT_DEBUG_PLUGINS=1`，看 `Cannot load library` 后面缺的文件名。
3. 只把缺的那个库放进这个程序自己已经在用的库目录。不要把整个 `AppDir/lib` 塞进库路径。
4. 不要用上级的 `SHARUN_DIR` 或 `APPDIR` 当作自己的目录。
