# WorkBuddy AppImage

本目录维护 **WorkBuddy Linux x86_64 AppImage** 的构建与发布。

## 构建来源

使用当前 AUR `workbuddy` 包作为 Linux 适配来源。

**不要在本仓库锁定 WorkBuddy 版本。** 构建时直接安装当前 AUR `workbuddy`，并通过 `pacman -Q workbuddy` 读取实际安装版本。上游版本变化时不应仅为了版本号修改本仓库。

## 构建

构建脚本：

```text
workbuddy/build_workbuddy.sh
```

GitHub Actions：

```text
.github/workflows/build.yml
```

最终发布：

```text
workbuddy.AppImage
```

## 已踩过的坑

以下处理是已经验证过的兼容基线，后续修改时不要退回旧写法：

- **不要写死 WorkBuddy 版本。** 曾经按 `5.3.x`、`5.4.x` 判断 AUR 版本，版本更新后会制造无意义失败；应始终使用当前 AUR 实际版本。
- **不要写死 `/opt/workbuddy` 或 `/opt/WorkBuddy`。** AUR 安装目录大小写曾发生差异，写死 `/opt/workbuddy/app.asar.unpacked/package.json` 会导致实际文件存在但构建仍报找不到。应从 `pacman -Qlq workbuddy` 动态定位 `app.asar.unpacked/package.json`，再推导资源根目录。
- **不要要求安装结果必须存在 `app.asar`。** 当前 AUR 会提供展开后的 `app.asar.unpacked` payload，构建应以实际安装文件清单为准。
- **资源路径不能保留 AUR 系统安装目录硬编码。** 如果 payload 中写死当前 AUR 资源根目录，需要恢复为 `process.resourcesPath`，否则放进 AppImage 后路径会失效。
- **Electron runtime 不能只复制单个可执行文件。** 必须保留 `locales`、`resources`、snapshot 等完整运行文件，并根据实际 Electron 主版本动态定位 `/usr/lib/electron<主版本>`。
- **不要把 `libqt6_shim.so` 当成必需依赖。** 它是可选 Qt 原生主题 shim；让 `quick-sharun` 处理它会因为缺少整套 Qt6 而中止。
- **Linux native module 必须检查。** `node-pty` 和 `better-sqlite3` 必须是 Linux x86_64 ELF，不能把 macOS、Windows 或其他架构预构建带进 AppImage。
- **CI 下需要规避 `/dev/shm` 容量问题。** GitHub Actions 启动 Electron 时使用 `--disable-dev-shm-usage`，否则可能出现 Chromium `font_data` / shared-memory `ENOSPC`。
- **托盘图标不能只放 desktop icon。** WorkBuddy 的 Linux AppIndicator 会从 `path.dirname(process.resourcesPath)/.workbuddy-linux/workbuddy.png` 读取磁盘图标，因此 AppImage 内必须保留 `AppDir/bin/.workbuddy-linux/workbuddy.png`，否则主程序能启动但 i3/i3bar 托盘无图标。

## 用户数据

用户数据位于：

```text
~/.workbuddy/
```

该目录不属于 AppImage 构建内容，不得打包或上传。它可能包含账号会话、Connector token、自定义模型 API Key、对话历史和本地文件索引等私有数据。

## 发布

GitHub Actions 构建完成后执行 Xvfb smoke test，通过后发布到 `latest` Release：

```text
https://github.com/newyorkthink/linux-packaging/releases/tag/latest
```
