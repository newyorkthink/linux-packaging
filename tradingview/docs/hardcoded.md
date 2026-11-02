# TradingView 固定参数与来源依据

本页记录当前构建的固定配置及选择依据；应用版本、DEB 文件名、摘要和打包工具版本均动态取得，不在 build 中锁定。维护流程和实际差异见 [模板差异](template-deviations.md)。

## 软件来源与构建环境

| 配置 | 当前值 | 依据和用途 |
| --- | --- | --- |
| 系统应用包 | `tradingview-bin-latest` | AUR 配方使用官方当前 DEB，准备系统应用、依赖、图标和 desktop；只安装在 Arch 构建环境。 |
| 官方仓库 | `https://tvd-packages.tradingview.com/ubuntu/stable` | [官方 Linux 安装说明](https://www.tradingview.com/support/solutions/43000728898-how-to-install-and-update-desktop-app-on-linux/) 公布的稳定仓库。 |
| suite / component | `jammy / multiverse` | 同一官方安装说明的源配置；这是读取的软件仓库布局，不代表在 Ubuntu 上执行 quick-sharun。 |
| DEB 包名 / 架构 | `tradingview / amd64` | 已核对真实 control 信息；当前标准 matrix 使用 x86_64 Arch 容器。 |
| 官方公钥 | `https://tvd-packages.tradingview.com/keyring.gpg` | 官方公布的签名密钥入口，交给公共脚本验证 InRelease。 |
| 来源版本 | `tradingview-source-version.txt` | 记录同一份已校验 DEB 的完整 Version，不读取 AUR 静态版本。 |
| 最终产物 / 版本 | `dist/tradingview.AppImage`、`dist/version.txt` | 与原应用清单、Release 名称及版本发布 Action 保持一致。 |

所读 AUR commit 为 `e9bacc953aa4ff3fa74da8079c477863030c7c2b`；其 PKGBUILD 的 `pkgver()` 从实际 DEB control 读取版本。`.SRCINFO` 中的静态版本和 AUR 使用的 SKIP 都不能替代最终 DEB 的签名、摘要和身份校验。固定源码入口见 [模板差异](template-deviations.md#来源核实与两阶段安装)。

## 程序与桌面资源

| 配置 | 当前值 | 依据和用途 |
| --- | --- | --- |
| DEB 内程序目录 | `opt/TradingView/` | 真实官方 DEB 的完整 Electron bundle；解包后原样复制其全部内容。 |
| 收集前完整程序目录 | `AppDir/bin/` | Electron 直接下载模板要求；保持相邻资源，无额外资源链接。 |
| 程序名 / 窗口类 | `tradingview / TradingView` | 主 ELF、官方 desktop 的 Exec 与 StartupWMClass；交给 quick-sharun 生成入口。 |
| 图标 | `/usr/share/icons/hicolor/512x512/apps/tradingview.png` | AUR 安装同源 DEB 提供的图标。 |
| desktop | `/usr/share/applications/tradingview.desktop` | 同源官方 desktop 已包含 %U、图标名及 tradingview 协议。 |
| 原生模块 | `resources/app.asar.unpacked/keytar.node` | 实际 ELF 需要 libsecret；沿用显式依赖输入。 |
| 通知库 | `/usr/lib/libnotify.so.4` | 原脚本已显式收集的动态加载库，继续由 Arch 的 libnotify 包提供。 |
| 构建库路径 | `$SCRIPT_DIR/AppDir/bin` | 只在 quick-sharun 调用前临时设置，保留原有 LD_LIBRARY_PATH 后备值。 |
| 运行工作目录 | `${SHARUN_DIR}/bin` | 跟随完整程序与资源；额外运行库路径由工具生成，已有 .env 保留。 |

`NO_STRIP=1` 和 `STRACE_MODE=0` 沿用已存在的构建配置，不作为所有 Electron 程序的强制参数。标准的 `DEPLOY_GTK=1` 用于 GTK3 与对应输入模块部署；本次没有新增 OpenGL、Vulkan 或其他应用的专属开关。

## 中文与协议参数

包内 locale 按 quick-sharun 模板生成到 `AppDir/lib/locale/zh_CN.utf8`，运行环境使用 `LANG=zh_CN.UTF-8`、`LANGUAGE=zh_CN:zh`、`LC_MESSAGES=zh_CN.UTF-8`、`LOCPATH=${SHARUN_DIR}/lib/locale`。它提供区域数据和语言选择，应用翻译、用户账号语言和输入法模块仍各自负责。

固定启动参数继续为 `--no-sandbox`，通过 `90-tradingview-arguments.hook` 保留；该参数来自既有已实测路线，本次不另加其他 Chromium 开关。`20-tradingview-protocol.hook` 仍由公共入口生成，使用 `tradingview.desktop`、`TradingView` 名称 / 窗口类、`Finance;Office;` 分类及 `tradingview` 协议。公共 hook 按运行时实际 AppImage 路径生成用户级 desktop，并以 %U 保留浏览器回调 URI，不固定安装位置或浏览器。

## 原始下载故障与验证范围

[Build TradingView，run 41420975694 / job 125196247712](https://github.com/newyorkthink/linux-packaging/actions/runs/41420975694/job/125196247712) 在安装依赖之后遇到 HTTP 429、连接重置和多次连接超时，最终退出码为 28；当时尚未进入 quick-sharun 收集和封装。这是原 Snap 下载链路的失败证据，不能据此判断程序本身或打包工具出错。

本次改用官方签名 APT 仓库中的 DEB，仍保留 quick-sharun 路线。具体实现与旧 Snap 实测历史见 [README](../README.md)。下载或校验失败仍会停止构建，不绕过摘要或回退旧产物。

2026-11-02 实际来源检查取得 DEB `3.5.0-1`，大小 `132897210` 字节，SHA-256 为 `0e4fca319c63c77cf92d1ca1fad96380707bf6a464b88956e880f7554693607d`；官方 InRelease 签名、Packages 与 DEB 摘要、包身份均已核对。此处版本和摘要仅是历史证据，未写入生产脚本。当前完整构建与实机状态以 README 为准。
