# Hermes Desktop AppImage

本目录用于把 `NousResearch/hermes-agent` 最新稳定 Release 对应的官方 Desktop 源码构建为 x86_64 Linux AppImage。

迁移基线来自 `newyorkthink/hermes-agent` 中已经实际发布过 `hermes-desktop.AppImage` 的 Desktop AppImage 方案；正式迁入本仓库后，构建和发布统一接入 `.github/workflows/build.yml`，不保留独立长期 workflow。

## 当前构建来源

- 上游源码由公共脚本获取。构建时通过 `GITHUB_TOKEN` 认证，读取 `NousResearch/hermes-agent` 最新正式 Release 并检出对应标签。
- Desktop 基于 Electron。构建使用上游 CI 的 PM 入口准备锁定的 Node.js 和 pnpm，按锁文件安装依赖，再走上游普通 Desktop 构建与 AppImage 封装流程。
- x86_64 AppImage 提供普通 Desktop 客户端，可以连接已有 Gateway，也可以使用已有的本机 Agent 或按需安装。本仓库发布的桌面客户端通过更换 AppImage 更新。
- 发布文件为 `latest` Release 中的 `hermes-desktop.AppImage`。AppImage 和 `version.txt` 使用同一个正式版本号。

## 官方构建迁移（2026-11-10）

- 旧流程用 `npm ci` 安装依赖，而上游 `v0.23.1` 已改用 pnpm，构建在封装前以 `EUSAGE` 退出。[原构建日志](https://github.com/newyorkthink/linux-packaging/actions/runs/42739512268/job/129576894448)
- 本次切换到上游带标签的完整构建，移除旧 npm 流程、独立 AppImage 源码补丁及依赖这些补丁的检查。
- 上游 `v0.23.1` 锁定的 electron-builder 在封装时把缺少模块声明的 CommonJS 图标工具复制到 Desktop 的 ES 模块目录，会触发 `require is not defined`。[上游打包入口](https://github.com/NousResearch/hermes-agent/blob/v0.23.1/apps/desktop/scripts/run-electron-builder.mjs#L68-L85) · [图标工具封装](https://github.com/electron-userland/electron-builder-binaries/blob/icons%401.2.1/packages/icons/assets/build.sh#L55-L104)
- 构建只在检测到该工具仍缺少模块声明并需要按 CommonJS 加载时，为 Runner 的临时打包工具目录生成一份 `package.json`。上游准备的工具和源码直接交给官方打包入口。
- 新版的运行结果见[实机验证](#实机验证)。

## 恢复普通 Desktop 构建（2026-11-10）

- 上游 `bundled` 构建将本地 Agent、Python 环境和离线依赖缓存一并打包，发布的 AppImage 实际约为 1.887 GiB。[完整包构建日志](https://github.com/newyorkthink/linux-packaging/actions/runs/42749500950/job/129609540029)
- 固定模板无法调用上游普通 Desktop 源码构建入口。本次经用户授权按专用构建例外处理，使用上游锁定的 pnpm 构建普通 Desktop，沿用图标工具的临时 CommonJS 声明。[上游构建说明](https://github.com/NousResearch/hermes-agent/blob/v0.23.1/apps/desktop/BUILDING.md#L378)
- 构建脚本将 AppImage 复制到发布目录，由公共入口统一设置 `0755` 并写入版本。
- GitHub Actions 首次构建并发布 `v0.23.1` 的 x86_64 普通 AppImage。该次产物约为 137.4 MiB，发布资产的 SHA-256 与构建产物一致，版本清单已更新。[构建与发布记录](https://github.com/newyorkthink/linux-packaging/actions/runs/42756081699/job/129630731165)

## 实机验证

### 2026-11-10：用户实机验证通过

用户已确认 Hermes Desktop `v0.23.1` 实机验证通过。

| 实测项目 | 通过结果 |
| --- | --- |
| AppImage 启动 | `hermes-desktop.AppImage` 在 Linux 实机正常启动。 |
| 中文界面 | 界面正常显示中文。 |
| Gateway 连接 | 已连接的 Gateway 显示就绪。 |
| 历史会话 | 可以打开历史会话并查看已有消息。 |

#### 运行观察

- 终端构建标记为 `3b4215785882 (v0.23.1)`。普通版状态栏的客户端版本优先采用当前 Gateway 的运行版本，本次显示 `v0.22.6`。[上游版本显示实现](https://github.com/NousResearch/hermes-agent/blob/3b421578588243f920886e6fe79a6faa87ea026e/apps/desktop/electron/app-version.ts#L79-L96)
- 终端记录了 `409` 响应，提示为 `Exclusive maintenance refused`。Gateway 持有配置目录的运行锁时会拒绝需要独占访问的离线维护请求，实测中仍可查看历史会话。[上游维护规则](https://github.com/NousResearch/hermes-agent/blob/3b421578588243f920886e6fe79a6faa87ea026e/website/docs/user-guide/features/web-dashboard.md#L553-L564)

## 旧版 Linux AppImage 兼容处理

旧版迁移时保留了源方案中已经实际用于发布成品的 Linux 兼容逻辑。

- 直接启动 standalone AppImage 时自动探测 KeePassXC Secret Service、GNOME Keyring 或 KWallet，并为 Electron `safeStorage` 选择 password-store。
- AppImage 内置 `libsecret-1.so.0`，并给 Electron 主程序加入 `$ORIGIN/resources/linux-libs` RUNPATH，避免宿主机缺少 Chromium 动态加载所需客户端库。
- 中文 Linux locale 映射为 Chromium `zh-CN`；Hermes 没有明确设置 `display.language` 时，初始界面跟随系统语言。
- standalone AppImage 禁用源码 checkout 方式的 Desktop 自更新入口，避免 AppImage 自己修改或替换源码目录。
- 构建后检查 `zh-CN.pak`、内置 `libsecret-1.so.0` 和 Electron RUNPATH。
- 最终 AppImage 在 Xvfb + D-Bus + GNOME Keyring 环境中实际执行，检查 `gnome_libsecret`、`safeStorage` 加密/解密往返以及中文 locale。
- GitHub Actions smoke test 会临时隐藏 Runner 的系统 `libsecret-1.so.0`，确保最终 AppImage 确实能够使用自身内置副本；trap 会在退出时恢复 Runner 文件。本机手动构建不会执行这一步系统库移动。

## 旧版稳定基线（2026-09-12）

- 稳定修复提交：`f13c6ffe2b75e21b572fa33a3fbcbbfa125fe0b7`（`fix(hermes-desktop): adapt patches to upstream desktop changes`）。
- 对应 GitHub Actions Run：`34662458787`，其中 `Build Hermes Desktop` 已成功完成并把 `hermes-desktop.AppImage` 上传到 `latest` Release。
- CI 对最终 AppImage 的实际运行结果为：检测到 `gnome-libsecret`，`safeStorage encryptionAvailable=true`，加密/解密往返 `roundTrip=true`，中文 locale 为 `zh-CN`；该次产物 SHA-256 为 `bc73db99007f769cd7b13263c3cd22329c30c98b52078047214955c45fffacce`。
- Linux 实机验证已确认最终 AppImage 能直接启动图形界面，中文界面正常，会话与对话功能可用。
- 上游 `v2026.9.11` 已在 Desktop i18n 中原生使用机器 locale 作为未保存语言时的回退；当前补丁不再覆盖这段上游逻辑，只校验其仍存在。Desktop update preload bridge 按方法名停用 `check`、`apply`，以及 `setChannel` 或旧的 `getBranch` / `setBranch`，不再锁定整段函数签名。
- 当前启动日志中的 Fontconfig cache 版本提示、systemd `UnitExists`、IBus surrounding-text 警告以及 Electron deprecated 提示，在上述成功启动和功能验证中均未造成实际故障；不得仅为消除这些非致命日志改动当前稳定打包链。

## 上游兼容修复记录（2026-09-22）

- GitHub Actions Run `35688857294` 的 `Build Hermes Desktop` Job `106632942395` 在上游稳定版更新为 `v2026.9.21` 后失败，实际错误为 `FileNotFoundError: apps/desktop/scripts/after-pack.mjs`。
- 根因是上游已删除原 `after-pack.mjs`，并将 Windows 可执行文件标记逻辑迁移到 `afterExtract`；旧补丁仍强制读取已经不存在的文件。
- 当前修复不改动上游 `afterExtract`：补丁脚本改为生成独立的 `scripts/after-pack-appimage.mjs`，通过 electron-builder 的 `afterPack` 配置只负责 Linux Electron RUNPATH 处理，继续保留内置 `libsecret-1.so.0` 方案。
- 已对 `v2026.9.21` 实际源码执行完整补丁，补丁锚点校验、Python 语法检查、生成的 Node.js hook 语法检查及 diff whitespace 检查均通过；提交时尚未通过新的 GitHub Actions 完整构建和最终 AppImage 运行验证。

## 上游兼容修复记录（2026-09-24）

- `v2026.9.24` 的 About 更新 `ListRow` 增加了 `id={settingElementId(SETTING_IDS.about.automaticUpdates)}`，旧锚点无法唯一定位，构建在隐藏源码自更新入口前停止。
- 补丁同时接受带 `id` 的新写法和原来的写法，仍然把整块更新控件藏起来，并保留版本旁的 Release Notes。
- 同一版本恢复了仅处理 macOS locale 的 `scripts/after-pack.mjs`。Linux AppImage hook 先调用它，再设置内置 `libsecret` 的 RUNPATH，不覆盖上游逻辑。
- `src/main.tsx` 现在使用只接受 `children` 的 `ProfileI18nProvider`。补丁不再给它加 `initialLocale`，界面语言继续走上游已有的系统语言回退。Chromium `zh-CN` 映射仍保留。

## 上游兼容修复记录（2026-10-08）

- 上游最新稳定版从日期标签 `v2026.9.24` 改成了 `v0.21.6`。构建不再检查标签是不是 `v年.月.日`，`releases/latest` 返回的稳定 tag 都会打。
- `v0.21.6` 的 About 页改成 `UpdateStatusCard`，`v0.21.7` 又加了 `UpdateChannelRow`。补丁只去掉 Desktop 自己的更新入口和通道开关，远程后端更新保留。旧的 `ListRow` 写法仍然接受。
- `v0.21.6` 的打包脚本在命令行带 `--x64` 时，会把原生依赖写到 `apps/desktop/build/native-deps-linux-x64`，上游自己的输出检查拒绝这个目录。构建不再传 `--x64`，由 x64 构建机使用允许的 `native-deps` 目录。
- 同一版把 `icon-tool.js` 复制到 `apps/desktop` 下面后，Node 会按 ES 模块执行它，`require` 直接报错。复制后补一个 CommonJS 的 `package.json`。
- `v0.21.6` 的 electron-builder 读取 `electron-builder.config.cjs`。只改 `package.json` 时，内置 `libsecret` 和 AppImage hook 都不会进包。补丁改这个配置文件。

## 上游兼容修复记录（2026-11-03）

- 故障：[Run 41592310499 / Job 125785327437](https://github.com/newyorkthink/linux-packaging/actions/runs/41592310499/job/125785327437) 在上游 `v0.22.6` 的专属补丁阶段失败，原始错误为 `无法确认上游 Desktop 系统语言回退逻辑，停止构建，避免覆盖新的 i18n 实现。`；尚未进入 AppImage 封装。
- 原因：上游仍保留机器语言回退，但 `resolveInitialLocale` 的第一个参数已从 `undefined` 改为 `requestedRef.current`；旧补丁只接受原来的完整字符串，因此把新的有效实现判为未知结构。
- 修复：仅调整 `patch_hermes_desktop.py` 的检查，精确接受上述两种调用，并要求总共只匹配一次；后续自检使用本次实际匹配到的完整调用。缺失、未知写法、重复调用或两种写法同时出现时仍停止，不改写上游 i18n 源码。现有构建脚本、工作流、公共入口及其他兼容补丁保持原样。
- 验证：Python 语法及七个语言回退接受 / 拒绝场景通过；在隔离目录中对 `v0.22.6` 的必要源码文件执行完整补丁成功，`src/i18n/context.tsx` 的字节内容保持不变。
- 实机验收：修复提交 [e6aa5cb](https://github.com/newyorkthink/linux-packaging/commit/e6aa5cbde49d522bab8008348b5ea71c9660172f) 对应的新产物已在 Linux 实机启动，中文界面正常，启动日志确认已识别并选择 `gnome-libsecret` 后端。本次语言回退检查失配问题已修复，现有打包方案继续保留。

## 构建文件

`build_hermes-desktop.sh` 负责获取上游正式标签源码、准备锁定的 pnpm 工具链、调用上游普通 Desktop 构建并整理发布产物。

## 发布

正式 CI 使用：

```text
.github/workflows/build.yml
```

手动构建项：

```text
hermes-desktop/build_hermes-desktop.sh
```

最终资产：

```text
https://github.com/newyorkthink/linux-packaging/releases/download/latest/hermes-desktop.AppImage
```

## 运行配置

Hermes Desktop 的 Gateway URL、Session Token、API Key、IP 和端口属于实际部署环境配置，不写入 AppImage，也不固化在本仓库打包脚本中。

需要连接 Hermes Dashboard 时，在 Desktop 中按实际环境填写：

```text
Gateway URL: http://<IP地址>:<Dashboard端口>
Session token: <Dashboard Session Token>
```

OpenAI-compatible API 同样使用实际部署参数：

```text
Base URL: http://<IP地址>:<API端口>/v1
API Key: <API_SERVER_KEY>
Model: <实际模型ID>
```

## 源迁移记录

源仓库 Desktop AppImage 迁移范围：

| 源文件 | 源 Git blob SHA | 用途 |
| --- | --- | --- |
| `.github/workflows/desktop-appimage.yml` | `818c0b3c586d77c5a6ebac7c791cd855c9a7c529` | 已发布方案的构建、补丁、验证和 Release 基线 |
| `README_AppImage.md` | `a21343376d673a8f1219c4da8d2ecef9677e9900` | 已发布方案的使用和兼容性说明基线 |

源 `desktop-latest` Release 已存在由 `github-actions[bot]` 上传的 `hermes-desktop.AppImage`；迁入本仓库时将源 workflow 的实际构建逻辑拆分为当前目录脚本，并按照本仓库规则接入统一 `build.yml`。
