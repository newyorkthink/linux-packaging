# Binance 标准模板参数与内联处理

## 标准入口

正式脚本以现有 [linuxdeploy-gtk-deb.sh](../../templates/appimage/linuxdeploy-gtk-deb.sh) 为底稿，由统一远端生成工作流生成初始标准脚本后，按本次明确要求将三项已有核验依据的专属处理直接内联至 [build_binance.sh](../build_binance.sh) 对应分区，`AppRun` 保持标准模板原样。

初始底稿生成记录：提交 `4889902edd63595688222ba90e17c3b1d09a1a91`，[运行 45347274483 / 1](https://github.com/newyorkthink/linux-packaging/actions/runs/45347274483)。该次原始输出 SHA-256 为 `b023633047b8bba14f4977ecabce35d2786bfdaa1829fbafc1b16560a0a05f0e`，作为内联整理前的标准底稿依据。

| 参数或位置 | 本应用取值与原因 |
| --- | --- |
| 来源 | 官方 GitHub 正式 Release 资产 `binance-{version}-amd64-linux.deb`（`binance/desktop`），公共入口动态选择最新正式版、校验官方 SHA-256，并将同一份 DEB 安装到构建环境并按原布局解包到 AppDir。 |
| 依赖 | 沿用现有 47 个 Ubuntu 22.04 APT 构建及运行依赖包清单。 |
| 目录与入口 | 完整保留 `opt/Binance`，主程序为 `opt/Binance/binance`。 |
| GTK | 主程序直接链接 GTK 3，使用 `gtk` 插件与 `DEPLOY_GTK_VERSION=3`；成品解包确认包内仅含唯一的 `binance.desktop` 与 `512x512/apps/binance.png`，无需额外传 `--desktop-file` / `--icon-file`。 |
| AppRun | 保留模板标准内联 AppRun，设置 `PATH`、`LD_LIBRARY_PATH`、`XDG_DATA_DIRS`、`GSETTINGS_SCHEMA_DIR` 和 `GIO_MODULE_DIR`，直接执行 `opt/Binance/binance` 并传递参数；成品解包确认 `usr/lib/x86_64-linux-gnu` 下仅含 `gio` 模块目录，无需在 `LD_LIBRARY_PATH` 中额外追加。 |
| 构建与封装 | 沿用 `.github/workflows/build.yml` 中的 Ubuntu 22.04 独立 Job，最终由公共入口使用官方 `appimagetool` 与 Type 2 runtime 封装；中间 AppImage 不发布。 |

## 主脚本中的必要处理

| 位置 | 处理与依据 |
| --- | --- |
| 下载并准备应用：desktop | 将解包后的 `usr/share/applications/binance.desktop` 规范为 `Exec=binance %U`、`Icon=binance`。官方包默认 `Exec=/opt/Binance/binance %U` 指向宿主机绝对路径（2026-09-23 `dpkg-deb -c` 核验）。 |
| 下载并准备应用：NSS | 调用公共入口 `common/linuxdeploy/copy_nss_runtime.sh "$APPDIR/usr/lib"`，部署与构建环境同版本的 NSS 核心库及 `dlopen` 模块，避免 Electron/Chromium 运行时与宿主 NSS 混用。 |
| 核心打包：隐式动态库 | 第二次 `linuxdeploy` 按 `dpkg-architecture -qDEB_HOST_MULTIARCH` 追加 `-l libsecret-1.so.0` 与 `-l libnotify.so`。依据：`keytar.node` 链接 `libsecret-1.so.0`、主程序按文件名 `dlopen` `libnotify.so`，二者均不在主程序 `NEEDED` 中。 |

## 未带入的历史处理

本次未带入显式 `--desktop-file` / `--icon-file`、Adwaita 主题包解包及 `AppRun` 的 `usr/lib/x86_64-linux-gnu` 库路径；后续待正式构建及实机运行结果核验后再决定是否需要调整。
