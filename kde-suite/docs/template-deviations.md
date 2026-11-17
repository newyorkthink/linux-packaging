# KDE Suite 模板差异

本页说明已启用的 Filelight 菜单兼容处理，以及多应用套件对公共入口的复用。KDE Suite 继续采用已登记的专用打包流程；已有稳定逻辑与验证结果保留。

## Filelight 单程序样式包装

- **位置：** [`deploy_suite_apps.sh`](../deploy_suite_apps.sh) 中现有 Haruna 包装之后、最终完整性检查之前，所有 quick-sharun 依赖收集已完成。
- **原因：** 套件共享运行时将 Qt Quick Controls 设为 Breeze，覆盖了 Filelight 未指定样式时采用桌面样式的上游选择。修复前用户截图显示首页菜单动作与快捷键重叠；本目录 Haruna 已有同类布局修复并实机验收。
- **相对通用流程的差异：** 标准系统入口收集保持不变；仅在最终部署阶段增加单程序包装，按既有 Haruna 模式保留 sharun 所在目录和真实程序别名。套件级 `.env` 或公共 Hook 会影响多个应用，不能用它们全局改动本次单程序样式。
- **调用与影响：** AppRun、启动器和直接命令继续调用同名 `filelight`；包装用 `exec` 与 `"$@"` 传递扫描目录和参数。没有新增插件、源码补丁、软件渲染开关、自更新 Hook 或测试代码。
- **来源与固定值：** 本仓库兼容处理，复用本目录已有的 Haruna 入口方式。官方 Filelight 打包没有对应菜单专项代码，见 [官方取舍](./pkgforge-differences.md)；具体路径与样式依据见 [固定配置](./hardcoded.md)。
- **实机验证：** 菜单文字与快捷键布局已通过用户实机验证，见 [README 实机验证记录](../README.md#实机验证)。

新增代码：

```sh
# 本仓库兼容处理：恢复 Filelight 的上游桌面控件样式，避免中文菜单与快捷键重叠。
# 复用 Haruna 已验证的入口布局，原始 sharun 留在 bin，真实程序保留在 shared/bin。
mv -- AppDir/bin/filelight AppDir/bin/kde-suite-filelight
ln -s -- filelight AppDir/shared/bin/kde-suite-filelight
cat > AppDir/bin/filelight <<'EOF_FILELIGHT_WRAPPER'
#!/bin/sh

# 只为本次 Filelight 进程选择已打包的桌面控件样式。
export QT_QUICK_CONTROLS_STYLE=org.kde.desktop
# 通过同目录的原始 sharun 入口启动，原样传递扫描目录和其他参数。
exec "$(dirname -- "$0")/kde-suite-filelight" "$@"
EOF_FILELIGHT_WRAPPER
chmod +x AppDir/bin/filelight AppDir/bin/kde-suite-filelight
```

## 多应用套件的公共步骤复用

### 保留专用流程的依据

[专用打包分类](../../docs/packaging-classification.md#专用打包流程) 已登记本套件：多款 KDE 应用共享一个挂载和 Qt6/KF6 运行组件，按安装、基础收集、额外应用、集成和最终封装分阶段执行。单应用 Qt 模板的单一主包、版本及工作目录不能覆盖现有套件结构。本次按该专用流程维护，不运行生成器重建现有稳定脚本，也不新增模板。

### 当前调用入口

| 阶段 | 本套件入口 | 保留的差异与边界 |
| --- | --- | --- |
| 统一基础包 | `build_kde_suite.sh` 调用 `common/arch/install_packages.sh --base` | 保留原有调用。 |
| 原有依赖与额外应用 | `build_core.sh` 四次、`build_kde_suite.sh` 一次调用 `common/arch/install_packages.sh` | 原包名、顺序和阶段保持不变；公共入口自带 `--needed`，只跳过已安装且版本相同的包。 |
| 功能文件集成 | `deploy_suite_apps.sh` 加载 `deploy_app_integration.sh` | 原 `okular_ark.sh` 仅重命名，正文逐字保留；仍在 Activities 文件收集之后、Activities 服务接入之前加载。 |
| 更新器指纹 | `build_kde_suite.sh` 保留原包版本与功能文件哈希计算 | 保留所有组件和计算顺序；文件清单使用重命名后的真实路径，不改为某个单一程序的版本。 |
| 最终产物与版本保存 | `common/build/save_appimage_version.sh` | 产物非空检查、`0755` 权限和原版本字符串写入统一由公共入口完成，成功提示和临时指纹清理继续留在原位置。 |

版本保存的完整调用：

```sh
"$SCRIPT_DIR/../common/build/save_appimage_version.sh" "$SCRIPT_DIR/dist/kde-suite.AppImage" "$KDE_SUITE_UPDATE_VERSION" "$SCRIPT_DIR/dist/version.txt"
```

本次没有把阶段性的翻译恢复、MIME/KSycoca 更新或运行时 Hook 覆盖当作普通重复删除。`copy_support_files` 已由基础脚本定义并供集成脚本复用，未再新增相同 helper。应用集成文件的重命名不改变正文；Haruna 与 Filelight 的单程序样式包装继续保留，不改为全局样式。

### 验证与维护范围

本轮只做现有流程的公共步骤复用及文件职责整理，不增加依赖、补丁、测试脚本或 workflow。已进行只读源码与差异核对。DwarFS 缩略图等原待处理事项与当前整理分别记录，原始历史及失败尝试保持完整。

## 套件静态资源

套件自身的 desktop 文件和 SVG 图标集中放在 `resources/`，程序清单位于 `config/apps.ini`，启动器源码位于 `src/kde_suite_launcher.cpp`。构建入口通过 `$SCRIPT_DIR/resources/` 定位资源，功能文件指纹清单同步使用这两个相对路径：

```text
resources/org.kde.kdesuite.desktop
resources/kde-suite.svg
```

这里只调整仓库中的资源来源目录。成品中的根目录 `kde-suite.svg`、`share/icons/hicolor/scalable/apps/kde-suite.svg` 和 `share/applications/org.kde.kdesuite.desktop` 保持既有位置；启动器读取的包内路径、desktop 的 `Icon` 和 `Exec` 均保持原样。资源按原内容和 `0644` 权限移动，未改变资源生成方式或程序运行逻辑。

## 启动器配置与源码

`config/apps.ini` 保存应用清单，`src/kde_suite_launcher.cpp` 保存启动器 C++ 源码，两者不混入 desktop / 图标资源目录。文件按原内容和 `0644` 权限移动，基础脚本只调整编译输入和清单复制源；清单在成品内仍位于 `share/kde-suite/apps.ini`，启动器二进制输出和运行时路径保持原样。功能文件指纹清单同步使用新的仓库相对路径，保留原有指纹计算方式。
