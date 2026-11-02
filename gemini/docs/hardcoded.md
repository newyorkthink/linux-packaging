# Gemini 固定路径和参数

本文记录当前构建中的固定接口、资源路径和兼容参数。应用版本、安装包地址、大小、SHA-256 和 Electron 版本均动态取得；文中的 `1.17.0`、`44.5.1` 只属于检查证据，不是构建锁定值。

## Omaha 查询和来源限制

- 为什么固定：Google 更新服务按应用 ID、通道和 Windows x64 系统信息提供完整包；与已经确认的既有来源保持一致。
- 固定内容：`https://update.googleapis.com/service/update2`、`{533dd80c-942a-4464-b6a9-2e59428d784e}`、`prod win 10.0.22000 x64`、允许源 `https://dl.google.com/`、解码后的目录前缀 `/release2/Google DeepMind/`、文件名规则 `GeminiSetup-{version}(_uncompressed)?[.]exe`。
- 作用：公共入口只选择对应应用、当前版本及允许来源中的完整包，同时校验大小和摘要。系统版本是更新服务的查询参数，不是运行机器的信息。
- 原始报错：本次没有查询或校验故障；已有来源已成功取得并校验 1.17.0 完整包。下方日志保留其随后在旧补丁阶段失败的证据，不把该错误归因于来源参数。

## 产品布局与 runtime

- 为什么固定：当前完整包包含与 `resources/app.asar` 同目录对应的 `Gemini.exe`，产品资源还包含 `app.asar.unpacked` 外置文件。
- 固定内容：只选择唯一 `*/resources/app.asar`；主程序为对应目录的 `Gemini.exe`；最终 Linux 程序和产品资源放在 `AppDir/bin`，修补中间目录位于本项目 `work`。
- 作用：避免混用不同版本目录；先完整提取 ASAR，保留产品和相邻资源布局。
- 原始报错：2026-09-27 的既有记录为删除外置模块过早导致 `asar extract` 报 `ENOENT`，完整来由继续保留在 [README 修复历史](../README.md)。本次延续先提取、后删除的顺序。

## 精确 Electron 版本与资产规则

- 为什么固定：实际程序的 Electron 标识才代表当前产品层配套的 runtime，开发依赖范围不是精确构建版本。
- 固定内容：ASCII / UTF-16LE 标识 `Electron[/ ]v?[0-9]+\.[0-9]+\.[0-9]+`；官方下载目录 `https://github.com/electron/electron/releases/download/v<实际版本>/`；只接受同版 `electron-v<实际版本>-linux-x64.zip` 及官方 `SHASUMS256.txt`。
- 作用：保留已验证的实际程序识别，防止从旧开发依赖选择错误 runtime；版本未知时失败。
- 原始报错：没有伪造 runtime 崩溃记录。1.17.0 的实际检查得到 `Gemini.exe = 44.5.1`，而包内 `devDependencies.electron = ^42.4.1`；本次不采用这个开发依赖值，也不继续旧的回退分支。

## PE 原生模块和非 sticky 修补

- 为什么固定：已确认的 `gemini_native.node` 是 Windows PE 模块，Linux Electron 不能直接加载；主窗口的显式 all-workspaces 调用会造成已记录的跨工作区显示。
- 固定内容：继续只移除 `resources/app.asar.unpacked/` 下、名称为 `gemini_native.node` 且实际识别为 PE 的文件及其提取副本；窗口只修补 `setVisibleOnAllWorkspaces(true/!0)`。
- 作用：保留原有文件类型、名称、路径和提取副本保护。非 sticky 补丁只处理窗口，不再用日志文字推断原生模块兼容性。
- 原始报错：下方为 [Actions run 41279519905 的 Gemini Job](https://github.com/newyorkthink/linux-packaging/actions/runs/41279519905/job/124775779381) 中与该失败直接相关的原始日志。未删改其错误文字。

```text
2026-11-01T06:45:39.8229000Z [Gemini] Gemini version: 1.17.0
2026-11-01T06:45:45.5193555Z [Gemini] Electron runtime: 44.5.1
2026-11-01T06:45:48.1008079Z [Gemini] 移除 Windows 原生 Node 模块：app.asar.unpacked/src/gemini_native.node
2026-11-01T06:45:48.1394270Z Gemini product layer no longer declares the safe fallback for the optional Windows native addon
2026-11-01T06:45:48.1459938Z ##[error]Process completed with exit code 1.
```

1.17.0 实际产品代码仍在 `try/catch` 中尝试加载模块，缺失时访问器返回空值；当前日志已经改为 `gemini_native addon unavailable; Will use fallbacks`，原先匹配 `STC will use safe fallbacks` 的判断因此失效。本次去掉的是这个过时的文字断言，不伪造原生模块，也不改写它的加载和回退逻辑。

## 官方 PNG、入口与中文

- 为什么固定：当前包内已有有效 PNG；既有大写入口与简体中文启动器已经确认有效。
- 固定内容：`resources/app.asar.unpacked/assets/icon.png`、`MAIN_BIN=Gemini`、`Gemini.AppImage`、`StartupWMClass=Gemini`；原样保留 `patches/Gemini` 的 `LANGUAGE=zh_CN:zh` 和 `--lang=zh-CN`；按标准增加包内 `zh_CN.UTF-8` 及对应 `LOCPATH`。
- 作用：图标直接交给 quick-sharun，退出 ICO 转换链；保留原有入口、中文界面和输入支持。PNG 原始 SHA-256 为 `1545adfcb69b9c46b9239473f93434dda85d6c8733217b7c4455e9715adcfa8b`，仅作本次检查记录，不参与固定版本选择。
- 原始报错：既有 ICO 路径曾报 `incorrect total size of bitmap` 和 `Gemini ICO does not contain a usable embedded PNG frame`，详细原始场景与已完成的旧修复继续保留在 README。官方 PNG 读取不经过这条转换链，也不恢复任务切换器图标注入。

## 其他保留的既有配置

- 为什么固定：保留现有运行环境和依赖收集范围，不借本次修复调整无关行为。
- 固定内容：`NO_STRIP=1`、删除包内 `chrome-sandbox`、`/usr/bin/hostname`、`/usr/lib/libnss*`、`/usr/lib/libsoftokn3.so`、`/usr/lib/libfreeblpriv3.so`、`/usr/lib/pkcs11/*`。
- 作用：保持原有二进制、启动与系统动态依赖处理；这些是本仓库既有配置，不冒称 pkgforge 的原样参数。`hostname`、NSS、IBus 及基础工具继续由 `--base` 覆盖，Fcitx5 GTK 模块由原有运行依赖行提供。
- 原始报错：README 已记录 `/usr/bin/hostname is NOT present`。`NO_STRIP`、沙盒文件及其余库列表未留存可补全的原始故障日志，本次不编造原因或把这些配置推广成通用模板，仅保留已确认基线。

## 适用范围

以上处理只作用于 GitHub Actions 的本项目构建目录；普通用户运行 AppImage 不执行构建目录清理或系统依赖安装。对应上游原文、未启用项与验证边界见 [pkgforge-differences.md](pkgforge-differences.md) 和 [template-deviations.md](template-deviations.md)。
