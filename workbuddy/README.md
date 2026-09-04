# WorkBuddy AppImage

本目录维护 **WorkBuddy Linux x86_64 AppImage** 的构建与发布。

## 构建来源

使用当前 AUR `workbuddy` 包作为 Linux 适配来源。

当前 AUR 配方直接下载 WorkBuddy 官方 Linux x64 DEB，并使用系统 `electron` 启动展开后的 `app.asar.unpacked`。因此本仓库不重复修补或裁剪 `node-pty`、`better-sqlite3` 等 Linux native module，只处理 AUR 临时构建版本一致性和 AppImage 便携化所需的路径、Electron runtime、desktop、图标与依赖部署。

**本仓库不锁定 WorkBuddy 版本。**

构建时先克隆当前 AUR `workbuddy`，以 AUR 对外发布的 `.SRCINFO` `pkgver` 为本次构建版本，并确认该版本对应的官方 Linux x64 DEB source。若临时克隆中的 `PKGBUILD` 初始 `pkgver` 与 `.SRCINFO` 不一致，只修正本次临时 `PKGBUILD`，同时让 `pkgver()` 返回同一版本，再执行 `makepkg`。

这样可以避免 `makepkg` 在 source 解析阶段使用旧 `pkgver` 下载旧 DEB、随后 `pkgver()` 又把软件包元数据更新成新版本，最终形成“包版本是新版、实际 payload 仍是旧版”的错配。

实际安装版本继续通过以下方式动态读取：

```text
pacman -Q workbuddy
```

实际安装文件和应用目录通过以下方式动态定位：

```text
pacman -Qlq workbuddy
```

不得按 `5.x`、某个具体小版本或固定 `/opt` 目录编写版本判断。上游版本变化时，不应仅为了更新版本号修改本仓库。

## 技术栈

- 上游应用：WorkBuddy 官方 Linux x64 DEB。
- AUR：负责官方 Linux 包来源、Electron payload 展开和 Linux 系统安装适配。
- Runtime：Arch `electron` 包提供的完整 Electron runtime。
- AppImage：使用 `quick-sharun` 部署运行库并生成最终单文件。
- 目标架构：Linux x86_64。

## 当前打包逻辑

`workbuddy/build_workbuddy.sh` 只保留 AUR 版本一致性和 AppImage 层必须处理的内容：

1. 安装构建依赖并临时克隆当前 AUR `workbuddy`。
2. 从 `.SRCINFO` 动态取得 AUR 对外发布版本，确认 Linux x64 DEB source 与该版本一致；若 `PKGBUILD` 初始 `pkgver` 滞后，只在临时副本中修正，并固定本次 `pkgver()` 返回同一版本。
3. 使用修正后的当前 AUR 配方执行 `makepkg`，安装完成后同时校验 `pacman` 包版本和 `app.asar.unpacked/package.json` payload 主版本，任一不一致都停止构建。
4. 从 `pacman -Qlq` 动态取得 `app.asar.unpacked`、desktop 和图标。
5. 根据系统 Electron 主版本复制完整 `/usr/lib/electron<主版本>` runtime，保留 `locales`、`resources`、snapshot 等文件。
6. AUR 为系统安装会把 `process.resourcesPath` 替换为 `/opt` 下资源目录；复制进 AppImage 后恢复为 `process.resourcesPath`，避免 AppImage 挂载路径变化导致资源失效。
7. 直接复用 AUR desktop，只把 `Exec=/usr/bin/workbuddy...` 前缀改为 `Exec=workbuddy...`，保留 Desktop Actions 原有 URI 参数和图标。
8. 复制 desktop icon，并把托盘图标放到 WorkBuddy Linux AppIndicator 实际读取的 `.workbuddy-linux/workbuddy.png`。
9. 使用 `quick-sharun` 部署 Electron 运行库、输入法、NSS、`ln`、`grep` 等已确认需要的运行项并生成 AppImage。

不再保留旧版针对非原生 Linux payload 的 native module 查找、平台裁剪和 ELF 校验逻辑；这些仍属于 AUR / 官方 Linux 包的职责。

## 当前稳定基线

2026-08-28 的旧基线解决了当时 WorkBuddy 非完整 Linux payload 下的 native module、资源路径和托盘图标问题。

自 2026-09-03 起，AUR `workbuddy` 已改用官方 Linux DEB，因此当前基线调整为：

- WorkBuddy Linux 应用适配继续由 AUR 配方负责，本仓库只补 AUR 临时构建版本一致性并做 AppImage 便携化。
- 继续动态读取版本和安装布局，不锁版本、不写死 `/opt/workbuddy` 或 `/opt/WorkBuddy`。
- AUR `.SRCINFO` 与 `PKGBUILD` 初始 `pkgver` 必须在 source 下载前保持一致；不能只相信最终 `pacman -Q` 的包版本。
- 最终安装 payload 版本必须与本次 AUR 对外发布版本一致，否则停止构建，不能发布“新版本号 + 旧 payload”的 AppImage。
- 继续保留 Electron 完整 runtime。
- 继续把 AUR 系统安装目录硬编码恢复成 `process.resourcesPath`。
- 继续保留托盘图标路径、CI `/dev/shm` 处理以及 `quick-sharun` 中的 `/usr/bin/ln`、`/usr/bin/grep`。
- 不再重复处理 `node-pty`、`better-sqlite3` 等 AUR 已经负责的 Linux native module。
- AUR desktop 的 Desktop Actions 必须保留原有 URI 参数，不能把所有 `Exec=` 行统一覆盖成同一条命令。

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

- **不要锁 WorkBuddy 版本。** 始终从当前 AUR `.SRCINFO` 动态取得本次对外发布版本。
- **不要直接假设 AUR `PKGBUILD` 初始 `pkgver` 与 `.SRCINFO` 一致。** source 数组会在 `pkgver()` 更新版本前解析；初始版本滞后会下载旧 DEB，再生成带新版本号的软件包。
- **不要只看 `pacman -Q workbuddy` 判断 payload 是否正确。** 同时检查 `app.asar.unpacked/package.json`，防止软件包元数据与实际应用版本错配。
- **不要写死 AUR 安装路径。** 从 `pacman -Qlq workbuddy` 动态定位 `app.asar.unpacked/package.json`，再推导资源根目录。
- **不要要求安装结果必须存在 `app.asar`。** 当前打包入口是 AUR 已展开的 `app.asar.unpacked`。
- **资源路径不能保留 AUR 系统安装目录硬编码。** payload 中的 AUR 资源根目录需要恢复为 `process.resourcesPath`。
- **Electron runtime 不能只复制单个可执行文件。** 必须保留 `locales`、`resources`、snapshot 等完整运行文件。
- **不要把 `libqt6_shim.so` 当成必需依赖。** 它属于可选 Qt 原生主题 shim，不应因此引入整套 Qt6。
- **不要重复修补 AUR 已完成的 Linux native module。** 当前 AUR 已基于官方 Linux DEB 处理 Linux payload；AppImage 层不再自行查找、裁剪或替换 native module。
- **CI 下需要规避 `/dev/shm` 容量问题。** GitHub Actions 启动 Electron 时使用 `--disable-dev-shm-usage`。
- **托盘图标不能只放 desktop icon。** WorkBuddy Linux AppIndicator 需要 `AppDir/bin/.workbuddy-linux/workbuddy.png`。
- **desktop 不能覆盖全部 `Exec=`。** AUR desktop 含多个 Desktop Actions，只替换 `/usr/bin/workbuddy` launcher 前缀，必须保留各 Action 的 `workbuddy://...` 参数。
- **`ln` 和 `grep` 必须作为 `quick-sharun` 输入显式部署。** 否则目标 Linux 环境下可能出现 `/bin/sh` 语法错误。

## 变更记录

### 2026-09-04：修复 AUR 包版本与实际 WorkBuddy payload 版本错配

- 现象：AUR 页面和 `pacman -Q workbuddy` 显示 `5.5.2.37672479_2b0177c3-1`，但实际 AppImage「关于」显示 `v5.4.5`，运行日志同时出现 `Version changed 5.4.7 -> 5.4.5`。
- 根因：AUR `.SRCINFO` 已更新到新版本及对应官方 Linux x64 DEB，但同一 AUR 当前 `PKGBUILD` 的初始 `pkgver` 仍是旧版本；`makepkg` 先按旧 `pkgver` 解析并下载 source，后续 `pkgver()` 再更新软件包版本，造成新版包元数据包装旧版 payload。
- 修改文件：`workbuddy/build_workbuddy.sh`、`workbuddy/README.md`。
- 修改内容：构建前临时克隆 AUR，以 `.SRCINFO` 版本修正本次临时 `PKGBUILD` 的初始 `pkgver`，并固定本次 `pkgver()` 返回相同版本；安装后同时校验包版本与 payload 主版本，不一致时直接停止构建。
- 不修改 AUR 上游仓库，不写死 `5.5.2` 或其他具体版本。

### 2026-09-04：跟随 AUR 官方 Linux 包精简 AppImage 逻辑

- 现象：原构建脚本仍保留旧 Linux 适配时期的 `node-pty` / `better-sqlite3` 裁剪、ELF 校验、完整 AUR 文件清单输出和多层防御检查。
- 根因：这些逻辑形成于 AUR 尚未直接使用 WorkBuddy 官方 Linux DEB 的阶段；当前 AUR 已负责 Linux payload 适配。
- 修改文件：`workbuddy/build_workbuddy.sh`、`workbuddy/README.md`。
- 修改内容：删除重复 native module 处理和调试输出，只保留 AppImage 资源路径还原、Electron runtime、desktop/icon、托盘图标和 `quick-sharun` 运行依赖；同时修正 desktop 处理，保留 Desktop Actions 参数。
- 已知结果：已基于当前 AUR 配方核对构建假设，并完成 Bash 静态语法检查；不把静态检查表述为真实 Linux 运行验证。

### 2026-09-01：保留 `ln` / `grep` 运行项

- 现象：目标 Linux 环境中 AppImage 内 `ln`、`grep` 曾出现 `/bin/sh` `Syntax error: "(" unexpected`。
- 根因：便携运行环境调用到了错误入口。
- 修改文件：`workbuddy/build_workbuddy.sh`。
- 修改内容：在 `quick-sharun` 输入中显式加入 `/usr/bin/ln` 和 `/usr/bin/grep`。
- 已知结果：真实 Linux 环境确认错误消失，WorkBuddy 可正常进入主界面。
- 对应提交：`921ae73fe1cd4b351fe2f40a6f7eef26c7d698b1`。

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

GitHub Actions 构建完成后执行现有 Xvfb smoke test，通过后发布到 `latest` Release：

```text
https://github.com/newyorkthink/linux-packaging/releases/tag/latest
```
