# Escrcpy 官方 AppImage 同步发布

本目录用于自动获取、校验并原样发布 Escrcpy 上游官方 Linux x86_64 AppImage，统一接入本仓库 `latest` Release。这里是官方包同步入口，不是源码编译或二次重打包项目。稳定资产名为 `escrcpy.AppImage`。

## 用途与产物

Escrcpy 是基于 Electron 的 Android 设备管理与投屏工具，上游项目为 [viarotel-org/escrcpy](https://github.com/viarotel-org/escrcpy)。本目录不重新编译应用，也不替换上游业务资源；正式产物直接来自上游最新稳定 GitHub Release 的官方 `Escrcpy-<版本>-linux-x86_64.AppImage`。

最终产物：

```text
dist/escrcpy.AppImage
```

发布到本仓库 `latest` Release 时使用固定资产名：

```text
escrcpy.AppImage
```

## 保留此目录的意义

- 统一入口：与本仓库其他应用一起发布，便于集中下载和维护。
- 稳定地址：使用固定资产名，下载脚本无需随上游版本变化修改文件名；[下载 escrcpy.AppImage](https://github.com/newyorkthink/linux-packaging/releases/download/latest/escrcpy.AppImage)。
- 自动同步与校验：每次正式流程执行时获取上游最新稳定版，校验 SHA-256 后发布；这不代表应用运行时会通过本仓库自动更新。
- 收益边界：没有重新编译、补充运行库或加入兼容补丁，功能和兼容性保持官方包原状。若只需使用应用，直接下载上游官方包也可以。

目前没有已确认需要通过重打包解决的问题，保留官方产物作为基线；后续只有定位到具体依赖或兼容问题时，才考虑最小范围的补丁或重打包。

## 技术栈

- 应用：Electron / Chromium。
- 上游 Linux 打包：electron-builder。
- 目标架构：`x86_64`。
- 上游当前 Linux 配置会把 `common`、`linux`、`linux-x64` 的 `extraResources` 一并放入正式包；其中包含 Escrcpy 自身使用的 scrcpy、gnirehtet、wscrcpy、yadb、locales 和 Linux tray 等资源。
- AUR `escrcpy-bin` 仅用于核对 Arch Linux 社区打包思路，不作为本项目的应用二进制或版本来源；上游已经直接提供正式 AppImage，因此优先保留官方产物。

## 打包方式

当前路线是“官方 AppImage 自动同步发布”，不使用 quick-sharun、linuxdeploy 或 appimagetool 对官方产物做二次封装。

`build_escrcpy.sh` 的正式流程：

1. 请求 `viarotel-org/escrcpy` 的 GitHub `releases/latest`，并明确拒绝 draft / prerelease。
2. 从 Release 标签动态取得版本，不在仓库中固定 Escrcpy 版本。
3. 只接受与该版本精确对应的 `Escrcpy-<版本>-linux-x86_64.AppImage`。
4. 读取 GitHub Release API 提供的 `sha256:` digest，下载后进行 SHA-256 一致性校验。
5. 不修改官方 AppImage 内容，只复制为 `dist/escrcpy.AppImage`，交给统一 workflow 发布。

正式入口位于 `.github/workflows/build.yml`，使用独立 `Build Escrcpy` Job；push、schedule 和 `workflow_dispatch` 均沿用仓库统一选择与发布逻辑。

## 运行与兼容说明

本仓库没有为 Escrcpy 增加后台服务、systemd、udev、`sudo` / `pkexec`、网络代理、证书或其他宿主系统修改逻辑，也没有修改 Chromium sandbox 参数。运行行为、设备连接方式和上游内置资源均保持官方 AppImage 原状。

下载 Release 产物后，在 Linux 终端进入文件所在目录执行：

```bash
# 启动 Escrcpy 官方 AppImage
./escrcpy.AppImage
```

Android 设备的 USB / ADB 授权、无线连接及其他设备侧要求仍以 Escrcpy 上游实际行为和文档为准，本仓库不额外改变这些权限模型。

### 托盘显示行为

按本次核查的上游托盘实现，主窗口显示时不常驻托盘图标。关闭窗口并选择“最小化到托盘”后才创建图标；通过托盘重新显示主窗口时会销毁图标。因此，退出确认框尚未选择时没有图标，并不表示打包遗漏资源。Linux 实机反馈已确认选择“最小化到托盘”后图标出现。

## 检查记录

### 2026-09-13：官方包同步定位与托盘核查

- 检查对象：本仓库提交 `73595cf95e720889b7f5c8e40c8dcf5aa494951b` 的 `escrcpy/build_escrcpy.sh`、本 README 和统一 workflow，以及当次上游稳定 Release 对应的托盘源码。
- 现象：主窗口打开及退出确认框显示时未见托盘图标，并对本目录是否重新打包产生疑问。
- 范围与证据：完整读取同步脚本，核对 workflow 中对应发布入口，比较[本仓库 Release](https://github.com/newyorkthink/linux-packaging/releases/tag/latest) 与[上游 Release](https://github.com/viarotel-org/escrcpy/releases/latest) 的资产大小、GitHub API SHA-256 digest，并核查上游 `desktop/electron/services/tray/index.js` 的创建和销毁逻辑。
- 已确认：当次两边资产大小和 digest 完全一致；脚本校验官方文件后仅改为固定资产名发布，没有二次封装。托盘只在选择“最小化到托盘”后创建，后续 Linux 实机反馈确认图标已出现。
- 未确认：未下载两份资产重新计算哈希，未执行完整功能或跨环境兼容验证；终端中的 Fontconfig、IBus 和 GLib-GObject 信息未在本次定位根因，不据此宣称无影响或已修复。
- 处理：仅更新 `escrcpy/README.md`，明确同步用途、收益边界和托盘行为；没有发现需要修改打包流程的证据，暂不重打包。本次为文档澄清及检查记录，不属于程序修复，未监控 Actions。

## 变更记录

### 2026-09-12：首次接入官方 Linux x86_64 AppImage

- 检查对象：Escrcpy 上游仓库、最新稳定 GitHub Release、Linux electron-builder 配置、上游 `extraResources` 目录、AUR `escrcpy-bin` 入口，以及本仓库 `AGENTS.md`、统一 `build.yml` 和相近 Electron 项目。
- 原因：本仓库此前没有 Escrcpy 的正式 AppImage 构建与发布入口。
- 修改文件：新增 `escrcpy/build_escrcpy.sh`、本 README，并接入 `.github/workflows/build.yml`。
- 实现：动态选择上游最新稳定 x86_64 AppImage，严格使用 Release API 返回的 SHA-256 digest 校验后原样发布；不固定应用版本，不进行无证据的二次重打包，也不加入测试或冒烟代码。
- 静态确认：上游正式 Linux 配置包含 x64 AppImage target，并把 Linux / x64 的 Escrcpy 附加资源纳入正式包；当前 GitHub Release 也实际提供 x86_64 AppImage 及 SHA-256 digest。
- 验证状态：本次只完成仓库外静态核对和提交前 diff 检查；提交后的 GitHub Actions 与真实 Linux 运行结果按仓库规则不在本次任务中主动监控，构建及实机运行状态待正式流水线和后续真实使用结果确认。

## 2026-09-16：接入统一软件版本元数据

- 继续原样同步并校验 Escrcpy 官方 AppImage，不进行二次封装。
- 构建脚本复用本次官方稳定 Release 解析得到的 `VERSION`，额外写入 `dist/version.txt`。
- workflow 使用 `SOFTWARE_KEY=escrcpy` 接入统一 `software_versions.json`；Release 资产名仍为 `escrcpy.AppImage`。
