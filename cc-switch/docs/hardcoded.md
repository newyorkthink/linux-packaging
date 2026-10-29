# CC Switch 固定配置依据

本文说明当前脚本的固定来源参数及布局。模板参数不是虚构的故障修复；没有新的报错时如实注明，不补造原始日志。

## 官方包核对依据

- [官方 Release](https://github.com/farion1231/cc-switch/releases/tag/v4.0.21) 的 `CC-Switch-v4.0.21-Linux-x86_64.deb` 大小为 18,403,900 字节，SHA-256 为 `ea2f6ca82da004820e09e0c473ca7254bf9291282f00272e9e2adf8f114e3e61`，与 GitHub 资产 digest 一致。
- 同一文件的 MD5 为 `cbdc6ca24d9a0804379f9a13061a8276`，与本次读取的 [AUR PKGBUILD](https://github.com/archlinux/aur/blob/cc-switch-bin/PKGBUILD) 和 [.SRCINFO](https://github.com/archlinux/aur/blob/cc-switch-bin/.SRCINFO) 一致。对应 blob 分别为 `02d4ae2aa28f9fd830bde1bda01051083e0a720e`、`274462a68544313caea4e7b32359d002cbe64dba`。
- 实际 DEB 的 `Package` 为 `cc-switch`、`Architecture` 为 `amd64`，`usr/bin` 只有 `cc-switch` ELF；桌面文件给出的 `StartupWMClass` 和 `Icon` 均为 `cc-switch`。

以上版本、大小和摘要仅为本次核对证据。构建继续从当前官方正式 Release 动态解析，不把这些数值写成固定下载版本或摘要。

## 来源、目录和元数据

| 固定内容 | 选择依据及作用 | 原始故障记录 |
| --- | --- | --- |
| `farion1231/cc-switch`、`CC-Switch-v{version}-Linux-x86_64.deb` | 当前官方仓库和 x86_64 DEB 命名模板；公共入口选择正式 Release 并校验 SHA-256。 | 无新增故障，属于来源参数。 |
| DEB 身份 `cc-switch amd64` | 来自已校验 DEB 的 control 元数据；阻止误用其他包或架构。 | 无新增故障，属于输入身份校验。 |
| `cc-switch.deb`、`cc-switch-unpacked`、`AppDir/bin`、`dist` | 应用工作目录与标准输出布局；清理只涉及当前应用目录中的这些构建文件和目录，以及版本中间文件。 | 无新增故障，沿用标准工作目录。 |
| `cc-switch-unpacked/usr/bin/.` | 当前 DEB 的完整程序目录，只有真实 `cc-switch` ELF；复制到 `AppDir/bin/` 后交给工具。 | 无新增故障，来自实际包内容。 |
| `APPNAME=cc-switch`、`MAIN_BIN=cc-switch` | 沿用原有应用名，主程序名对应实际 DEB 的可执行文件。 | 无新增故障，属于模板元数据。 |
| `STARTUPWMCLASS=cc-switch` | 来自已校验 DEB 的 desktop，保持窗口与菜单入口匹配。 | 无新增故障，原有取值保留。 |
| `/usr/share/icons/hicolor/128x128/apps/cc-switch.png` | 当前 DEB 包含该图标，AUR 配方直接安装 DEB 内容；继续使用已安装包的原路径。 | 无新增故障，原有取值保留。 |
| `/usr/share/applications/CC Switch.desktop` | 当前 DEB 的实际桌面文件；路径含空格，脚本保留完整双引号。 | 无新增故障，原有取值保留。 |
| `OUTPATH="$SCRIPT_DIR/dist"`、`OUTNAME=cc-switch.AppImage` | 保持清单中 `cc-switch/dist` 与稳定发布资产名。 | 无新增故障，发布接口不变。 |
| `DEPLOY_GTK=1` | 实际 ELF 依赖 GTK 3；输入模块和 WebKitGTK 资源按工具机制部署。 | 无新增故障，保留原 GTK 部署选项。 |
| `cc-switch.version`、`dist/version.txt` | 前者接收公共下载入口输出的同一 Release 版本；公共 `text` 入口读取后，在最终 AppImage 成功且非空时保存后者。 | 无新增故障，本次统一版本来源和公共接口。 |

## 托盘动态库

- 为什么保留：应用通过运行时动态加载托盘库，原先仅扫描主程序不能保证该库进入 AppImage。
- 固定内容：`/usr/lib/libayatana-appindicator3.so.1`。
- 作用：继续作为同一次 quick-sharun 的显式输入，保留已有修复；该路径由原脚本已使用的 `libayatana-appindicator` 包提供。
- 既有故障记录：原 [README](../README.md#修复记录) 记录 CC Switch 3.20.3 启动 panic，错误为 `Failed to load ayatana-appindicator3 or appindicator3 dynamic library`，并报告 `libayatana-appindicator3.so.1`、`libappindicator3.so.1` 无法打开。原记录未附完整终端日志，本次不把摘要写成原始日志全文，也不声称已经重新复现。

## 中文环境及输入模块

包内 locale 和四项语言环境沿用标准，具体代码见 [构建脚本](../build_cc-switch.sh#L55-L63)。IBus 继续由公共基础包安装，Fcitx5 GTK 模块通过应用安装行补充。

已读取 quick-sharun 的 GTK 部署代码和 WebKitGTK 依赖识别分支，源码 blob 为 `7053bbb3fac3dc51ab93e7c232de6899b5399028`。相关机制及依赖覆盖见 [模板差异说明](template-deviations.md)，不将工具可自动完成的行为重复写成专属环境开关。
