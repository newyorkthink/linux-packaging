# WorkBuddy AppImage

本目录维护 **WorkBuddy Linux x86_64 AppImage** 的构建与发布。

## 构建来源

使用当前 AUR `workbuddy` 包作为 Linux 适配来源。

**本仓库不锁定 WorkBuddy 版本。**

构建时直接安装当前 AUR `workbuddy`：

```text
yay -S --noconfirm --needed workbuddy
```

实际版本通过以下方式动态读取：

```text
pacman -Q workbuddy
```

实际安装文件和应用目录通过以下方式动态定位：

```text
pacman -Qlq workbuddy
```

不得按 `5.x`、某个具体小版本或固定 `/opt` 目录编写版本判断。上游版本变化时，不应仅为了更新版本号修改本仓库。

## 当前稳定基线

当前稳定基线来自 **2026-08-28 已在 Linux 实机验证可以正常启动的 WorkBuddy AppImage 构建逻辑**。

后续只做了以下必要适配，并继续以该基线为准：

- WorkBuddy 版本改为从当前 AUR 实际安装结果动态获取，不锁版本。
- `app.asar.unpacked/package.json` 和 AUR 资源根目录改为从 `pacman -Qlq workbuddy` 动态定位，不写死 `/opt/workbuddy` 或 `/opt/WorkBuddy`。
- 保持 2026-08-28 已验证的 Electron runtime、资源复制、`process.resourcesPath` 修补、native module、托盘图标、CI `/dev/shm` 和 `quick-sharun` 构建逻辑。
- 在 `quick-sharun` 输入中额外加入 `/usr/bin/ln` 和 `/usr/bin/grep`，解决目标 Linux 环境下 AppImage 内 `ln`、`grep` 出现 `/bin/sh` 语法错误的问题。

当前 Linux 实机已验证：WorkBuddy 可以正常进入主界面，原先的 `ln` / `grep` `Syntax error: "(" unexpected` 已消失。

**除非出现明确的实际功能故障，否则不要再改动上述稳定基线，也不要为了清理非致命日志重构打包逻辑。**

## 构建文件

构建脚本：

```text
workbuddy/build_workbuddy.sh
```

GitHub Actions：

```text
.github/workflows/build.yml
```

最终发布文件：

```text
workbuddy.AppImage
```

## 已踩过的坑

以下处理已经形成稳定基线，后续修改时不得退回旧写法：

- **不要锁 WorkBuddy 版本。** 不要按具体版本号、版本范围或固定小版本判断构建逻辑；始终使用当前 AUR 实际安装版本。
- **不要写死 AUR 安装路径。** AUR 安装目录大小写和布局可能变化，应从 `pacman -Qlq workbuddy` 动态定位 `app.asar.unpacked/package.json`，再推导资源根目录。
- **不要要求安装结果必须存在 `app.asar`。** 构建应以 AUR 实际安装文件清单和 `app.asar.unpacked` payload 为准。
- **资源路径不能保留 AUR 系统安装目录硬编码。** payload 中的 AUR 资源根目录需要恢复为 `process.resourcesPath`，否则进入 AppImage 后路径会失效。
- **Electron runtime 不能只复制单个可执行文件。** 必须保留 `locales`、`resources`、snapshot 等完整运行文件，并根据实际 Electron 主版本动态定位运行目录。
- **不要把 `libqt6_shim.so` 当成必需依赖。** 它属于可选 Qt 原生主题 shim，不应因此引入整套 Qt6。
- **Linux native module 必须检查。** `node-pty` 和 `better-sqlite3` 必须是 Linux x86_64 ELF，不能混入 macOS、Windows 或其他架构的原生模块。
- **CI 下需要规避 `/dev/shm` 容量问题。** GitHub Actions 启动 Electron 时使用 `--disable-dev-shm-usage`，避免 Chromium shared-memory `ENOSPC`。
- **托盘图标不能只放 desktop icon。** WorkBuddy Linux AppIndicator 需要 `AppDir/bin/.workbuddy-linux/workbuddy.png`，否则主程序可以启动但 i3/i3bar 托盘可能缺少图标。
- **`ln` 和 `grep` 必须作为 `quick-sharun` 输入显式部署。** 否则目标 Linux 环境下可能调用到 AppImage 内错误入口并出现 `/bin/sh` 语法错误。

## 当前可忽略的非致命日志

在 WorkBuddy 已正常启动并进入主界面的前提下，以下日志目前不属于 AppImage 打包故障，不应仅为了消除日志而修改稳定基线：

- `punycode` deprecated：Node / Electron 依赖弃用警告。
- `Glycin running without sandbox`：Glycin 运行警告，当前未造成启动或功能失败。
- `wb.js bundle NOT found`：当前主界面及已验证功能仍可正常运行；只有对应 webview / 扩展功能实际异常时再针对处理。
- `packaged linux runtime not found ... falling back to archive extraction`：WorkBuddy 会自动回退到归档解压流程；只要后续 `failed=0`，无需为此改包。
- `rpc slow` / `rpc VERY SLOW`：性能日志，不等同于构建或启动失败。

只有当某条日志能够稳定对应到明确的实际功能异常时，才单独定位和处理该问题。

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
