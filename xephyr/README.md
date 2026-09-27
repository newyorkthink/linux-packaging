# Xephyr AppImage

Xephyr 是在现有 X11 显示器的一个窗口里运行的嵌套 X server。它提供独立的显示编号，可以在窗口里启动 i3 和其他 X11 程序；本 AppImage 只包含 Xephyr，不会自动安装或启动 i3。

## 使用

在有可用 X11 显示器的图形会话中运行；Wayland 会话需要可用的 XWayland。以下命令在 Linux 图形会话终端执行：

```bash
# 给下载的 AppImage 添加执行权限。
chmod +x Xephyr.AppImage

# 在 :99 打开 1600×900 的嵌套 X11 窗口。
./Xephyr.AppImage :99 -screen 1600x900
```

另开一个 Linux 终端，把已安装的 i3 启动到该显示器，无需新增 i3 配置：

```bash
# 把 i3 启动在 :99，而非宿主显示器。
DISPLAY=:99 i3
```

`:99` 已被占用时，将两条命令中的显示编号改为同一个未占用编号。按 Ctrl+Shift 可切换 Xephyr 的键盘、鼠标抓取状态；在嵌套 i3 内使用与宿主 i3 相同的快捷键时可能需要先抓取，结束后再按 Ctrl+Shift 释放。两个桌面仍共用当前用户的文件和配置，已有 i3 配置的自动启动命令也会照常执行。

## 打包

- 来源：[Arch 官方 `xorg-server-xephyr`](https://archlinux.org/packages/extra/x86_64/xorg-server-xephyr/)；构建时经公共 Arch 安装入口取得当前包，不固定版本。
- 技术栈为 X.Org 的 C 语言 X11 server；工作流使用 x86_64 Arch 容器，键盘映射由 `xorg-xkbcomp` 和 `xkeyboard-config` 提供。
- 构建脚本 [`build_xephyr.sh`](./build_xephyr.sh) 用 quick-sharun 打包 `/usr/bin/Xephyr`、`/usr/bin/xkbcomp` 和 XKB 键盘规则；将 X server 编译时的系统路径映射至包内，使用 quick-sharun 生成的 `AppRun` 原样透传命令行参数。无需另写启动 hook 或 i3 配置。
- 上游包没有 desktop 和图标；构建时生成临时 desktop，并使用 Arch Adwaita 主题中的通用显示器图标。Xephyr 是 X server，不需要为自身添加中文 locale 或 GTK / Qt 输入模块。
- 统一工作流 [`.github/workflows/build.yml`](../.github/workflows/build.yml) 使用清单 [`.github/appimage-apps.json`](../.github/appimage-apps.json) 的 `xephyr` 项构建和发布 `Xephyr.AppImage`。产物目录 `dist/`；公共入口 [`get_package_version.sh`](../common/arch/get_package_version.sh) 从本次安装的 Arch 包读取上游版本，再由 [`save_appimage_version.sh`](../common/build/save_appimage_version.sh) 检查产物并写入 `version.txt`。

## 验证状态

2026-09-27：已检查源码入口、XKB 辅助程序、构建参数与工作流接入；完整 CI 构建和目标桌面上的运行效果尚未验证。

## 修正记录

2026-09-27：初次提交 `c311e1f` 为 Xephyr 加入了无关的中文 locale 和启动 hook，且 `-no-host-grab` 会禁止手动抓取键鼠，不适合内外都用 i3 的快捷键。修正 `build_xephyr.sh` 和本 README：删除上述内容，将 XKB 的编译时路径映射到包内，运行时由用户指定显示编号。静态检查完成；CI 构建及实机运行仍待验证。

2026-09-27：提交 `56334e5` 仍在 Xephyr 脚本中重复检查产物并直接写入 `version.txt`，没有复用现有公共入口。修正 `build_xephyr.sh` 和本 README：保留 Arch 包版本解析，改用 `common/build/save_appimage_version.sh` 检查最终 AppImage 并保存版本；静态检查完成，CI 构建及实机运行仍待验证。

2026-09-27：初次产物命名为小写 `xephyr.AppImage`，不符合上游程序 `Xephyr` 的大小写。修正 `build_xephyr.sh`、`README.md` 和 `.github/appimage-apps.json`：统一使用 `Xephyr.AppImage`；静态检查完成，CI 构建仍待验证。

2026-09-27：前次修正只复用了版本保存入口，`build_xephyr.sh` 仍自行解析 `pacman -Q` 返回的 epoch 与 `pkgrel`。新增 `common/arch/get_package_version.sh` 统一读取已安装 Arch 包的上游版本，Xephyr 构建改为调用该入口；原有产物检查和版本保存入口不变。静态检查完成，CI 构建仍待验证。
