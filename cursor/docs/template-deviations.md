# Cursor 标准模板差异

`build_cursor.sh` 遵守 [Electron 直接下载安装包标准模板](../../anylinux_projects.md#直接下载安装包的标准模板)。本文件记录允许变化的程序参数及其依据，通用注释、执行位置、代码结构和空行与另一份标准脚本逐行一致。

## 下载入口与程序布局

- 位置：清理构建目录之后、设置打包元数据之前。
- 参数：使用 `common/download/download_file.sh` 获取官方当前 x64 DEB；通过公共解包入口提取 `cursor-unpacked/usr/share/cursor/` 并完整复制到 `AppDir/bin`。
- 依据与影响：官方当前版本入口直接返回 DEB，使用现有普通下载入口；AUR 安装结果提供依赖、图标和 desktop，不替换最终官方程序。

## 版本与构建元数据

- 位置：`DEPLOY_GTK` 设置之后、第一次 quick-sharun 之前。
- 参数：`read_app_version.sh package-json AppDir/bin/resources/app/package.json --version-file "$HOME/version" --desktop "$DESKTOP"`。
- 依据与影响：版本取自官方程序的 `package.json`；可选参数保留原有构建版本文件和缺少 desktop 版本字段时追加版本的行为。调用本身保持单行，功能只在公共入口实现。

## 额外运行命令

- 位置：原有 quick-sharun 调用。
- 参数：保留 `/usr/bin/hostname`。
- 依据与影响：保留既有输入，不复制其他应用的运行命令。固定配置说明见 [hardcoded.md](hardcoded.md)。

## 验证边界

模板核对覆盖总行数、注释、空行、命令结构和执行顺序；程序名、软件包、路径、下载与版本参数及额外运行命令按上述真实差异保留。公共入口的语法和行为检查不等于 AppImage 构建或实机运行验证。
