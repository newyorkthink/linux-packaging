# Chromium AppImage

用于构建 Chromium 官方程序的 Linux x86_64 AppImage。

## 用途与产物

- 打包对象：Chromium（开源项目本体，非 Google Chrome）。
- 最终产物：`chromium.AppImage`，由 `build.yml` 中的 `build_chromium` Job 构建并发布到仓库 `latest` Release。
- 上游来源：Chromium 项目本身不提供官方通用 Linux 二进制发行版；使用 Arch `[extra]` 官方仓库的 `chromium` 包（该包直接基于 Google `chromium-browser-official` 官方源码构建）作为上游二进制来源。

## 技术栈

Chromium / Blink，GTK3 原生界面组件。依赖由 `pacman`/`yay` 按 `chromium` 包的真实依赖关系自动解析安装，未手工列运行库清单。

## 打包方式

- 路线：quick-sharun（Arch Linux 环境）。
- 版本：不锁定，每次构建安装仓库当前 `chromium`，通过 `chromium --version` 动态取实际版本号，写入 `~/version` 并追加到 desktop 文件的 `X-AppImage-Version`。
- desktop / 图标：直接复制官方包安装的 `/usr/share/applications/chromium.desktop` 与 hicolor/pixmaps 中的官方图标，不自制、不改品牌。
- 主程序与资源：Arch 的 `/usr/bin/chromium` 是启动器，真正的 Chromium 主程序及 `resources.pak`、`icudtl.dat`、`locales/`、`chrome-sandbox`、ANGLE / SwiftShader 运行文件都位于 `/usr/lib/chromium/`。构建时把该目录完整复制到 `AppDir/bin/`，再交给 quick-sharun 部署，避免只打包启动器而遗漏真正的浏览器程序和资源。
- 动态依赖探测：显式设置 `STRACE_BINARY=chromium` 与 `STRACE_FLAGS='about:blank --no-sandbox'`，让 quick-sharun 在构建阶段针对真正的 Chromium 主二进制收集动态加载依赖。
- 中文输入法：额外装 `ibus`、`fcitx5-gtk`，把两者的 GTK3 immodule 一并打包，同时兼顾 IBus 与 Fcitx5。

## 运行与兼容说明

- 仅支持 x86_64。
- 未自定义 AppRun，未强制指定 Ozone 平台；X11/Wayland 行为保持 Chromium 上游默认逻辑。
- 当前 AppImage 仍保留 Chromium 自身的 sandbox 行为；目标环境若无法初始化 sandbox，可在确认风险后使用 `--no-sandbox` 运行。
- Fcitx5/IBus 在最终 AppImage 里的实际输入效果以重新构建后的真实 Linux 环境反馈为准。

## 修复记录

### 2026-09-06：修复 AppImage 启动立即退出

- 故障现象：已构建的 `chromium.AppImage` 在真实 Linux 环境中执行 `./chromium.AppImage --no-sandbox` 后立即退出，无法正常打开浏览器。
- 根因：原脚本对 `/usr/bin/chromium` 使用 `readlink -f` 并据此推导程序目录；但 Arch 的 `/usr/bin/chromium` 是启动器而非 Chromium 主 ELF，真正程序与资源位于 `/usr/lib/chromium/`。因此构建输入只包含启动器，没有完整带入真正的 Chromium 主程序、资源和 locales。
- 修改文件：`chromium/build_chromium.sh`、`chromium/README.md`。
- 修复内容：改为显式使用 `/usr/lib/chromium/`，完整复制到 `AppDir/bin/` 后交给 quick-sharun；同时指定 `STRACE_BINARY=chromium` 与 `STRACE_FLAGS='about:blank --no-sandbox'`，确保动态依赖探测针对真实主程序执行；保留原有 IBus / Fcitx5 GTK3 输入法模块打包逻辑。
- 已知结果：脚本已完成静态语法检查；尚未重新构建新的 AppImage，因此启动结果需要以下一次真实构建和实机运行反馈为准。
