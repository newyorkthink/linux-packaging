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
- 资源文件：构建时探测 `chromium` 二进制真实所在目录是否与 `resources.pak`/`locales/` 同目录；如是，整个目录一并交给 quick-sharun（做法与仓库内 `vscode` 等 Electron/Chromium 系应用一致），避免只收集到 ELF 依赖漏掉非 ELF 资源。
- 中文输入法：额外装 `ibus`、`fcitx5-gtk`，把两者的 GTK3 immodule 一并打包，同时兼顾 IBus 与 Fcitx5。

## 运行与兼容说明

- 仅支持 x86_64。
- 未自定义 AppRun，未强制指定 Ozone 平台；沙盒、X11/Wayland 行为保持 Chromium 上游默认逻辑。
- 已知风险，待真实 Linux 环境验证：
  - 部分发行版（例如限制非特权 user namespace 的较新 Ubuntu 默认策略）下 Chromium 沙盒可能无法正常初始化；本实现未加 `--no-sandbox` 等绕过逻辑，具体表现需要在目标环境实测后再确认是否要处理、怎么处理。
  - 资源文件是否与二进制同目录、Fcitx5/IBus 在最终 AppImage 里的实际加载效果，都需要首次真实构建和真实运行反馈确认。

## 修复记录

暂无。首次实现尚未经过真实 GitHub Actions 构建和真实 Linux 环境运行验证，等有实际结果后再按规范补充。
