# Escrcpy AppImage

本目录用于把 Escrcpy 上游官方发布的 Linux x86_64 AppImage 接入本仓库统一构建与 `latest` Release。稳定资产名为 `escrcpy.AppImage`。

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

## 技术栈

- 应用：Electron / Chromium。
- 上游 Linux 打包：electron-builder。
- 目标架构：`x86_64`。
- 上游当前 Linux 配置会把 `common`、`linux`、`linux-x64` 的 `extraResources` 一并放入正式包；其中包含 Escrcpy 自身使用的 scrcpy、gnirehtet、wscrcpy、yadb、locales 和 Linux tray 等资源。
- AUR `escrcpy-bin` 仅用于核对 Arch Linux 社区打包思路，不作为本项目的应用二进制或版本来源；上游已经直接提供正式 AppImage，因此优先保留官方产物。

## 打包方式

当前路线是“官方 AppImage 原样接入”，不使用 quick-sharun、linuxdeploy 或 appimagetool 对官方产物做二次封装。

`build_escrcpy.sh` 的正式流程：

1. 请求 `viarotel-org/escrcpy` 的 GitHub `releases/latest`，并明确拒绝 draft / prerelease。
2. 从 Release 标签动态取得版本，不在仓库中固定 Escrcpy 版本。
3. 只接受与该版本精确对应的 `Escrcpy-<版本>-linux-x86_64.AppImage`。
4. 读取 GitHub Release API 提供的 `sha256:` digest，下载后进行 SHA-256 一致性校验。
5. 不修改官方 AppImage 内容，只复制为 `dist/escrcpy.AppImage`，交给统一 workflow 发布。

正式入口位于 `.github/workflows/build.yml`，使用独立 `Build Escrcpy` Job；push、schedule 和 `workflow_dispatch` 均沿用仓库统一选择与发布逻辑。

## 运行与兼容说明

本仓库没有为 Escrcpy 增加后台服务、systemd、udev、`sudo` / `pkexec`、网络代理、证书或其他宿主系统修改逻辑，也没有修改 Chromium sandbox 参数。运行行为、设备连接方式和上游内置资源均保持官方 AppImage 原状。

下载 Release 产物后可直接执行：

```bash
./escrcpy.AppImage
```

Android 设备的 USB / ADB 授权、无线连接及其他设备侧要求仍以 Escrcpy 上游实际行为和文档为准，本仓库不额外改变这些权限模型。

## 变更记录

### 2026-09-12：首次接入官方 Linux x86_64 AppImage

- 检查对象：Escrcpy 上游仓库、最新稳定 GitHub Release、Linux electron-builder 配置、上游 `extraResources` 目录、AUR `escrcpy-bin` 入口，以及本仓库 `AGENTS.md`、统一 `build.yml` 和相近 Electron 项目。
- 原因：本仓库此前没有 Escrcpy 的正式 AppImage 构建与发布入口。
- 修改文件：新增 `escrcpy/build_escrcpy.sh`、本 README，并接入 `.github/workflows/build.yml`。
- 实现：动态选择上游最新稳定 x86_64 AppImage，严格使用 Release API 返回的 SHA-256 digest 校验后原样发布；不固定应用版本，不进行无证据的二次重打包，也不加入测试或冒烟代码。
- 静态确认：上游正式 Linux 配置包含 x64 AppImage target，并把 Linux / x64 的 Escrcpy 附加资源纳入正式包；当前 GitHub Release 也实际提供 x86_64 AppImage 及 SHA-256 digest。
- 验证状态：本次只完成仓库外静态核对和提交前 diff 检查；提交后的 GitHub Actions 与真实 Linux 运行结果按仓库规则不在本次任务中主动监控，构建及实机运行状态待正式流水线和后续真实使用结果确认。
