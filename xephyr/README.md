# Xephyr AppImage

Xephyr 是在现有 X11 显示器的一个窗口里运行的嵌套 X server。它提供独立的显示编号，可以在窗口里启动 i3 和其他 X11 程序；本 AppImage 只包含 Xephyr，不会自动安装或启动 i3。

## 使用

在有可用 X11 显示器的图形会话中运行；Wayland 会话需要可用的 XWayland。默认占用 `:99`，窗口大小为 1600×900：

```bash
chmod +x xephyr.AppImage
./xephyr.AppImage
```

另开终端，把已安装的 i3 启动到这个显示器，无需新增 i3 配置：

```bash
DISPLAY=:99 i3
```

也可指定其他未占用的显示编号和尺寸：

```bash
./xephyr.AppImage :98 -screen 1280x800
DISPLAY=:98 i3
```

默认不抓取宿主键盘和鼠标，也不监听 TCP。Xephyr 的 X11 窗口与宿主桌面分开，但程序仍以当前用户身份运行，共用用户文件和配置；已有 i3 配置中的自动启动命令也会照常执行。需要文件或进程隔离时还需容器或独立用户。`:99` 已被占用时换一个显示编号。

## 打包

- 来源：[Arch 官方 `xorg-server-xephyr`](https://archlinux.org/packages/extra/x86_64/xorg-server-xephyr/)；构建时经公共 Arch 安装入口取得当前包，不固定版本。
- 技术栈为 X.Org 的 C 语言 X11 server；工作流使用 x86_64 Arch 容器，键盘映射由 `xorg-xkbcomp` 和 `xkeyboard-config` 提供。
- 构建脚本 [`build_xephyr.sh`](./build_xephyr.sh) 用 quick-sharun 打包 `/usr/bin/Xephyr`、`/usr/bin/xkbcomp` 和 XKB 键盘规则；将编译时的 `/usr/bin/xkbcomp` 路径映射至包内，并用生成的 `AppRun` 与 hook 指定包内键盘规则和启动参数。无需另外写启动包装或 i3 配置。
- 上游包没有 desktop 和图标；构建时生成临时 desktop，并使用 Arch Adwaita 主题中的通用显示器图标。Xephyr 本身不用 GTK / Qt 输入模块；包内提供 `zh_CN.UTF-8` locale，窗口里运行的程序自行提供需要的输入法模块。
- 统一工作流 [`.github/workflows/build.yml`](../.github/workflows/build.yml) 使用清单 [`.github/appimage-apps.json`](../.github/appimage-apps.json) 的 `xephyr` 项构建和发布 `xephyr.AppImage`。产物目录 `dist/`；`version.txt` 取本次安装的 Arch 包版本。

## 验证状态

2026-09-27：已检查源码入口、XKB 辅助程序、构建参数与工作流接入；完整 CI 构建和目标桌面上的运行效果尚未验证。
