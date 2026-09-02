# Modern CSV AppImage

## 用途

本目录将 Modern CSV Linux 稳定版重新封装为 AppImage，产物名固定为：

```text
moderncsv.AppImage
```

上游与打包参考：

- Modern CSV：`https://www.moderncsv.com/`
- AUR `moderncsv-bin`：`https://aur.archlinux.org/packages/moderncsv-bin`
- pkgforge-dev `quick-sharun`：`https://github.com/pkgforge-dev/Anylinux-AppImages`
- 官方说明：`https://github.com/pkgforge-dev/Anylinux-AppImages/blob/main/HOW-TO-MAKE-THESE.md`
- 仓库基线：`copyq/build_copyq.sh`

## 打包环境

Modern CSV 使用仓库统一的 Arch Linux / AnyLinux quick-sharun 构建环境。

`.github/workflows/build.yml` 中的 Modern CSV Job 与 CopyQ 等标准项目一样，直接复用：

```text
ghcr.io/pkgforge-dev/archlinux:latest
pkgforge-dev/anylinux-setup-action
.github/actions/build-anylinux
```

应用脚本本身不再启动额外 Docker / chroot，也不重复下载 quick-sharun。

## 打包流程

`build_moderncsv.sh` 保持普通 quick-sharun 项目的简单结构：

1. 设置 `STARTUPWMCLASS`、`ICON`、`DESKTOP`、`OUTPATH`、`OUTNAME`、`DEPLOY_OPENGL`。
2. 使用 `yay` 安装 `moderncsv-bin` 及 Qt6、Fcitx5、OpenSSL、OpenGL 相关依赖。
3. 直接执行：

```bash
quick-sharun /usr/bin/moderncsv
```

4. 只在 `AppDir/.env` 补充当前需要的中文 locale 与 XCB 环境：

```text
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
QT_QPA_PLATFORM=xcb
```

5. 最后执行：

```bash
quick-sharun --make-appimage
```

`quick-sharun` 负责常规 ELF、Qt plugin、动态依赖和 AppRun 生成，不在普通构建脚本里重复实现这些通用逻辑。

## Qt 与中文输入

Modern CSV 当前按 Qt 6 打包。构建环境安装 `fcitx5-qt`，输入上下文必须与应用实际 Qt 主版本对应；Qt5 与 Qt6 都有各自主版本对应的 Compose、Fcitx5、IBus 输入上下文，不能跨 Qt 主版本混用。

本脚本不设置 `LD_LIBRARY_PATH`、`QT_PLUGIN_PATH` 或 `QT_QPA_PLATFORM_PLUGIN_PATH`，避免人为干预 quick-sharun 的默认依赖与 Qt plugin 处理。

这里的中文环境只负责 UTF-8 locale 和 Linux 输入环境，不向 Modern CSV 注入非官方中文界面翻译。

## 特殊处理原则

CopyQ 中 `lib/copyq/plugins` 的符号链接修复属于 CopyQ 自身插件搜索行为，不复制到 Modern CSV。

普通程序默认保持“安装依赖 -> 设置 quick-sharun 变量 -> quick-sharun 主程序 -> 必要 `.env` -> `--make-appimage`”这一条主线。只有程序出现能够明确定位的特有运行问题时，才增加对应的最小特殊处理，不预先加入重复 plugin 遍历、`ldd`、最终 AppImage 再提取或额外 wrapper。
