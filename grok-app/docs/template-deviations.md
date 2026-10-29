# Grok App 模板差异

核对日期：2026-10-30。通用阶段、注释和空行沿用 [quick-sharun 标准](../../anylinux_projects.md#直接下载安装包的标准模板)。本应用属于 Tauri / GTK；用户已批准无同源 AUR 应用安装的 DEB 路线例外。下载主体保持三行，版本读取位于第一次 quick-sharun 前，成功保存位于最后。

## 采用与不采用

| 处理 | 决定 | 对应代码 | 当前依据、用途与影响 |
| --- | --- | --- | --- |
| 安装阶段 | 采用已批准的 DEB 例外 | [基础和应用依赖安装](../build_grok-app.sh#L11-L13) | 尚未核实同源 Arch/AUR 应用包，按用户确认只安装真实依赖；程序和桌面资源从官方 DEB 取得，不使用其他同名聊天壳。 |
| 下载和版本来源 | 采用公共入口 | [三行下载命令](../build_grok-app.sh#L20-L22)；[读取实际下载版本](../build_grok-app.sh#L56) | 独立选择正式 Release 的 semver DEB，并核对 GitHub 摘要、包名和架构；使用同次下载返回的版本。 |
| 完整程序目录 | 采用标准布局 | [复制程序目录](../build_grok-app.sh#L28) | DEB 的 usr/bin 完整复制到 AppDir/bin；本应用是 Tauri / WebKitGTK，不按 Electron 目录推断。 |
| GTK 输入与中文 | 采用标准步骤 | [GTK 部署](../build_grok-app.sh#L47)；[生成中文环境](../build_grok-app.sh#L62-L69) | 依赖安装后由工具收集 GTK 输入模块；按模板生成包内中文 locale，不在收集命令中重复列 im-ibus.so / im-fcitx5.so。 |
| 托盘动态库 | 保留专属输入 | [完整收集命令](../build_grok-app.sh#L59)；原文见下方代码块。 | libayatana-appindicator3.so.1 由程序运行时加载，继续显式携带。 |
| WebKitGTK 与 OpenGL | 保留既有部署 | [部署设置](../build_grok-app.sh#L49-L53) | 主程序直接依赖 WebKitGTK 4.1；保留既有库目录和部署开关，不引入 Electron 专用参数。 |
| 选目录工具 | 保留已有修复 | [静态工具下载与安装](../build_grok-app.sh#L76-L84) | 针对 2026-10-14 添加项目无窗口：portal 不可用，回退又缺 zenity。保留已核对的静态工具版本、摘要、filechooser 路径及相对链接，不交给 quick-sharun。 |
| 宿主 bwrap | 保留已实测修复 | [完整运行时 hook](../build_grok-app.sh#L90-L94) | 2026-10-07 已实测使用宿主 /usr/bin/bwrap，解决 unknown cap: --proc。正文逐字保留，filechooser 优先、宿主命令随后、包内 bin 最后。 |
| 协议与回调 | 保留实际宿主登记 | [公共协议 hook 参数](../build_grok-app.sh#L97-L106) | 继续登记 grok:// 和 application/vnd.grok.skin；不能用仅复制包内 desktop 代替宿主登记。 |
| 构建期目录变量 | 不采用 | 未启用 APPDIR / SOURCE_DIR 构建变量。 | 构建路径直接写 AppDir/...、source/...；quoted heredoc 里的运行时 $APPDIR 与 HOSTPATH 原样保留。 |
| 重复 desktop 改写 | 不采用 | 未启用。 | 直接使用 DEB desktop；MAIN_BIN 提供真实程序名，回调另由公共 hook 写宿主 desktop。 |

## 当前完整收集命令

[构建脚本](../build_grok-app.sh#L59)：

```bash
quick-sharun AppDir/bin/* /usr/lib/libayatana-appindicator3.so.1
```

## 已确认的运行时 hook

以下正文与原脚本逐字一致。构建脚本不声明 APPDIR，不影响 quoted heredoc 在应用启动时读取运行环境的 APPDIR：

```sh
if [ -x /usr/bin/bwrap ]; then
  export PATH="$APPDIR/bin/filechooser:/usr/bin:/bin${HOSTPATH:+:$HOSTPATH}:$APPDIR/bin"
fi
```

## 来源与验证边界

本次按 grok-app、RongleCat 及同名候选核实，未发现可确认同一应用的 pkgforge-dev 打包。AUR 的 grok-desktop-bin 指向 Ash-Bash/Grok-Desktop-Wrapper，grok 指向 Grokking 论文代码，均不用于本应用。没有采用 pkgforge 专属代码，不创建空的 pkgforge 差异清单，也不把本仓库旧修复标成官方原命令。

正式 DEB 来自 [RongleCat/grok-app](https://github.com/RongleCat/grok-app/releases/tag/v0.2.50)。选目录与 bwrap 修复的原始报错、不同验证阶段和实机结果继续保存在 README。固定值见 [配置依据](hardcoded.md)，完整历史见 [README](../README.md)。

本次只做语法、接口、代码原文与行号、依赖覆盖和文档核对，没有进行新的 AppImage 构建或实机运行；已有用户确认的功能仍按各自原记录维护。
