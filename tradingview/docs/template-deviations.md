# TradingView 标准模板差异

`build_tradingview.sh` 按 [Electron 直接下载标准](../../anylinux_projects.md#直接下载安装包的标准模板) 和 [固定注释](../../docs/quick-sharun-comments.md) 整理。公共阶段与 Cursor / WorkBuddy 对齐；下列专属参数和处理保留在各自阶段，不加入通用模板。

## 来源核实与两阶段安装

- 2026-11-02 在 pkgforge-dev 中按 `tradingview`、`trading-view` 查找，未查到专属打包仓库；因此没有直接复用的应用专属命令，也不创建空的 pkgforge 取舍清单。
- AUR `tradingview-bin-latest` 的所读 commit 为 `e9bacc953aa4ff3fa74da8079c477863030c7c2b`，已核对 [PKGBUILD](https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=tradingview-bin-latest&id=e9bacc953aa4ff3fa74da8079c477863030c7c2b) 和 [.SRCINFO](https://aur.archlinux.org/cgit/aur.git/tree/.SRCINFO?h=tradingview-bin-latest&id=e9bacc953aa4ff3fa74da8079c477863030c7c2b)。它下载官方当前 DEB，读取实际 control 版本，仅解包及整理安装内容，不编译 TradingView 或 Electron 源码。
- [第一阶段](../build_tradingview.sh#L13) 安装该 AUR 包及原有运行依赖，用于系统依赖、图标和 desktop；[第二阶段](../build_tradingview.sh#L20) 从官方签名 APT 仓库独立取得最终程序包，不从系统安装目录复制程序。
- AUR 配方本身使用 `sha256sums=('SKIP')`；它只承担隔离构建系统的安装阶段。最终打包的 DEB 必须经过公共 APT 入口的官方签名、SHA-256、大小和身份检查，不能因为 AUR 使用 SKIP 而取消这一步。
- 官方安装来源见 [TradingView Linux 安装说明](https://www.tradingview.com/support/solutions/43000728898-how-to-install-and-update-desktop-app-on-linux/)。仓库、suite、component、包名、架构、公钥和两个输出位置全部作为参数交给已有公共入口，不在 build 中重复解析索引。

## 原有依赖覆盖

| 原脚本依赖 | 当前提供位置 |
| --- | --- |
| SquashFS 工具、OpenSSL、NSS、IBus | 原有 `install_packages.sh --base` 已包含 `squashfs-tools openssl nss ibus`，继续保留。 |
| GTK3、Fcitx5 GTK 输入模块、libsecret、libnotify | 独立安装行继续明确列出 `gtk3 fcitx5-gtk libsecret libnotify`。 |
| 应用安装与 DEB 读取 | 新增 `tradingview-bin-latest dpkg`；公共基础包提供 GnuPG、Python、curl、归档工具。 |

GTK3 输入模块仍交给 `DEPLOY_GTK=1` 的 quick-sharun 自动收集。没有把 GTK4 / Qt 输入模块或其他项目的整组库加进来；也没有更改宿主输入法变量。

## 完整程序目录与库路径

[解包和复制阶段](../build_tradingview.sh#L25) 把同一 DEB 的 `opt/TradingView/.` 原样放入 `AppDir/bin/`。与旧 Snap 路线相比，不再提前解到 `shared/bin`、清理 Snap 平台目录或在收集后逐项创建 Electron 资源链接；资源在第一次 quick-sharun 前已经完整相邻。

[依赖收集命令](../build_tradingview.sh#L60) 保留临时私有库目录和两个明确的额外输入：

```bash
# 收集程序及其运行依赖。
LD_LIBRARY_PATH="$SCRIPT_DIR/AppDir/bin${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" quick-sharun AppDir/bin/* AppDir/bin/resources/app.asar.unpacked/keytar.node /usr/lib/libnotify.so.4
```

`keytar.node` 的实际 ELF 依赖包含 `libsecret-1.so.0`；保留显式输入可覆盖原生模块的依赖。`libnotify.so.4` 沿用原脚本按名称加载库的收集方式。主程序实际包含 `$ORIGIN` RPATH 和 `libffmpeg.so` 依赖，临时库路径只作用于这次 quick-sharun，不导出给后续打包命令。

运行时由 quick-sharun 写入 Electron 的 `SHARUN_EXTRA_LIBRARY_PATH=${SHARUN_DIR}/bin:${SHARUN_EXTRA_LIBRARY_PATH}`；本脚本仅在现有 `.env` 后 [追加工作目录](../build_tradingview.sh#L74)，不覆盖工具内容。已核对的通用机制来自 quick-sharun [当前源码快照](https://github.com/pkgforge-dev/Anylinux-AppImages/blob/1930c50cc7e0e524165afc67233f0693e5e73da8/useful-tools/quick-sharun.sh#L1301)，不是 TradingView 专属上游命令。

## 元数据、中文与原有运行行为

- 元数据按模板顺序配置；图标和 desktop 读取 AUR 已安装的真实系统路径。官方 DEB desktop 已有 `Icon=tradingview`、`%U` 和 `x-scheme-handler/tradingview`，不再执行旧的 Snap desktop 替换。
- [版本读取](../build_tradingview.sh#L55) 使用公共 `text` 来源，读取这次独立下载的 DEB 版本，而不是 AUR 静态 pkgver 或安装结果。继续导出 `VERSION`，保留原工具元数据行为。
- `NO_STRIP=1`、`STRACE_MODE=0` 沿用原脚本值，属于已保留的应用配置。
- [中文环境](../build_tradingview.sh#L62) 使用模板原文，在第一次 quick-sharun 后生成 locale，再追加 `LANG`、`LANGUAGE`、`LC_MESSAGES`、`LOCPATH`；只生成区域数据，不替代界面翻译或输入模块。
- [参数 hook](../build_tradingview.sh#L78) 中的 `set -- --no-sandbox "$@"` 逐字保留，仍在内置 hook 后处理固定参数。没有添加新的 Chromium 参数。
- [协议入口](../build_tradingview.sh#L83) 继续调用同一公共脚本，保留应用元数据和 `tradingview` 协议。协议 hook 不改用户参数，不接管 http / https，不改变系统默认浏览器。
- 最终仍执行 `quick-sharun --make-appimage`，随后单行调用公共保存入口。现有 matrix、资产名、版本上传及发布流程无需改写。

## 工作目录与验证边界

清理仅覆盖 `tradingview/` 中的 `AppDir`、`dist`、旧 `source`、下载 DEB、解包目录和来源版本文本；不涉及用户运行配置。正式 build 中没有新增测试、GUI 冒烟或自动重跑步骤。

原 Snap 产物的启动、图表、中文输入和登录回调已由用户确认。2026-11-02 用户继续提供新版 `3.5.0` AppImage 的实机日志和截图，确认启动、已有登录会话恢复、中文界面、图表及自选列表、中文候选和上屏均正常；本次 DEB 标准化与基本使用验收已完成，继续沿用 [94b1ce8 代码基线](https://github.com/newyorkthink/linux-packaging/commit/94b1ce8631cd69bf6203669f03d20df3d7bcdd8f)。

提交前的隔离组装检查与后续用户实机结果分别保留，详细范围及运行提示见 [新版实机确认](../README.md#2026-11-02新版-appimage-实机确认)。本次只补充文档，不调整脚本、公共入口、workflow 或运行参数。
