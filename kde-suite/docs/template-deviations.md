# KDE Suite 模板差异

本页仅说明本次新增的 Filelight 菜单兼容处理，不借此重写或重新登记套件其他已验证逻辑。

## Filelight 单程序样式包装

- **位置：** [`deploy_suite_apps.sh`](../deploy_suite_apps.sh) 中现有 Haruna 包装之后、最终完整性检查之前，所有 quick-sharun 依赖收集已完成。
- **原因：** 套件共享运行时将 Qt Quick Controls 设为 Breeze，覆盖了 Filelight 未指定样式时采用桌面样式的上游选择。用户截图显示首页菜单动作与快捷键重叠；本目录 Haruna 已有同类布局修复并实机验收。
- **相对通用流程的差异：** 标准系统入口收集保持不变；仅在最终部署阶段增加单程序包装，按既有 Haruna 模式保留 sharun 所在目录和真实程序别名。套件级 `.env` 或公共 Hook 会影响多个应用，不能用它们全局改动本次单程序样式。
- **调用与影响：** AppRun、启动器和直接命令继续调用同名 `filelight`；包装用 `exec` 与 `"$@"` 传递扫描目录和参数。没有新增插件、源码补丁、软件渲染开关、自更新 Hook 或测试代码。
- **来源与固定值：** 本仓库兼容处理，复用本目录已有的 Haruna 入口方式。官方 Filelight 打包没有对应菜单专项代码，见 [官方取舍](./pkgforge-differences.md)；具体路径与样式依据见 [固定配置](./hardcoded.md)。
- **验证边界：** 当前只进行了只读源码与差异核对，未运行 Filelight、构建或实机检查；不将此次样式选择描述为字体修复或实机验证通过。

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
