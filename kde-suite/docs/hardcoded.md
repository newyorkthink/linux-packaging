# KDE Suite 固定配置依据

本页记录 Filelight 菜单兼容处理及现有打包流程维护涉及的固定内容；既有稳定配置和修复历史仍以 [README](../README.md) 为准。

## Filelight 专用桌面控件样式与入口

### 故障原始记录

本项原始证据为用户提供的图形界面截图，没有随附终端报错、日志或命令输出，不能补造文本日志。截图中三项菜单的文字为：

```text
配置                  Ctrl+Shift+,
打开使用手册
关于 Filelight
```

上面的文本仅转录菜单内容，空格不能还原原图的像素布局；原图中第一行动作文字与快捷键重叠。本页不发布用户截图、主机信息或附件路径。已确认的故障范围是这处菜单布局，不是缺少中文字符或整个字体配置失效。

### 具体内容、原因与作用

| 固定内容 | 依据与用途 |
| --- | --- |
| `QT_QUICK_CONTROLS_STYLE=org.kde.desktop` | [Filelight 上游默认选择](https://github.com/KDE/filelight/blob/176cce0b6ac61127a2d41b0fe26b8f7675d694e4/src/main.cpp#L61)。公共 Hook 指定 Breeze，因此在 Filelight 专用入口恢复桌面样式；仅影响这个进程，不修改用户字体或配色配置。 |
| `AppDir/bin/filelight` | 保留现有 AppRun 与 `apps.ini` 的同名命令入口，内容改为专用包装。 |
| `AppDir/bin/kde-suite-filelight` | 原始 sharun 启动器留在 `bin`，沿用已验证 Haruna 的目录布局。 |
| `AppDir/shared/bin/kde-suite-filelight -> filelight` | 为改名后的 sharun 入口保留匹配的真实程序别名，原始 Filelight ELF 内容与位置不变。 |

完整代码位于 [部署入口](../deploy_suite_apps.sh)。这组值来自已核实的程序名称、上游样式与现有 AppDir 结构，不是固定应用版本。Filelight 本次未完成实机验证，不能把 Haruna 的既有验收扩大为 Filelight 已通过。

## 公共入口与应用集成文件的维护命名

本项是维护整理，没有新的故障、终端报错或命令输出，不虚构故障日志。原实现依据为本仓库 [`ba88afe97ec8f4b2e42cdc0d99274d2f242ec537`](https://github.com/newyorkthink/linux-packaging/tree/ba88afe97ec8f4b2e42cdc0d99274d2f242ec537/kde-suite) 的实际调用：

```sh
# 原安装调用形式，原有全部包名在当前公共调用中保留
yay -S --noconfirm <原有软件包参数>

# 原应用集成文件引用
. "$SCRIPT_DIR/okular_ark.sh"

# 原最终产物检查和版本保存
test -s "$SCRIPT_DIR/dist/kde-suite.AppImage"
printf '%s\n' "$KDE_SUITE_UPDATE_VERSION" > "$SCRIPT_DIR/dist/version.txt"
```

上面第一行用占位符表示多组不同的原包名，具体完整原文保留在该源码快照中，不将占位符写入实际构建。

| 固定内容 | 选择原因与作用 |
| --- | --- |
| `$SCRIPT_DIR/../common/arch/install_packages.sh` | 仓库已有公共安装入口，相对当前软件目录定位；原包名、安装顺序和阶段保留。公共入口增加 `--needed` 跳过相同版本的重复安装。 |
| `$SCRIPT_DIR/../common/build/save_appimage_version.sh` | 仓库已有产物与版本保存入口，检查非空产物、统一执行权限并写入调用方提供的版本。 |
| `$SCRIPT_DIR/dist/kde-suite.AppImage` 与 `$SCRIPT_DIR/dist/version.txt` | 既有产物与版本文件路径，继续传入公共入口；不迁移 AppDir 或输出目录。 |
| `deploy_app_integration.sh` | 原 `okular_ark.sh` 的职责已覆盖多款应用和共享运行环境，新名称反映实际职责；仅重命名，文件内容、调用顺序和执行权限保留，source 与版本指纹清单同步更新。 |

这些路径来自当前仓库结构和已存在的公共接口，不锁定应用或打包工具版本。配置文件不会写入宿主系统目录。

## 静态资源来源目录

本项为静态文件归类，没有新的故障日志。原构建脚本从当前软件目录直接读取 `kde-suite.svg` 与 `org.kde.kdesuite.desktop`；本次原样移动后，源路径对应改为：

```sh
export ICON="$SCRIPT_DIR/resources/kde-suite.svg"
export DESKTOP="$SCRIPT_DIR/resources/org.kde.kdesuite.desktop"
```

`resources/` 只用于仓库内静态资源归类，选择依据是这两份文件属于套件入口与图标资源，不是构建脚本。复制源路径和功能文件指纹使用同一组真实相对路径；文件内容、成品中的资源位置、desktop 文件名、`Icon=kde-suite` 和 `Exec=kde-suite-launcher` 保持不变。没有固定用户主目录、临时挂载目录或应用版本。
