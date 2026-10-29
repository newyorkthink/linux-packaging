# Claude Desktop 模板参数与差异

## 当前采用的基础模板

`build_claude-desktop.sh` 使用用户批准的 69 行 [Electron 直接下载基础模板](../../anylinux_projects.md#直接下载安装包的标准模板)。通用代码、22 条通用注释及 13 处空行的位置保持一致，只替换允许变化的应用参数；没有增加额外命令块。

## 安装、下载与解包参数

- 安装：`claude-desktop fcitx5-gtk dpkg`。先在构建系统安装应用与依赖，原有基础工具由 `--base` 覆盖。
- 下载：`common/aur/download_deb_source.sh claude-desktop x86_64 claude-desktop.deb`，保持模板的三行调用。公共入口复用现有 AUR 解析与公共下载，不在应用脚本添加来源解析或校验代码。
- 解包和复制：公共解包入口提取到 `claude-desktop-unpacked`，完整复制其中 `usr/lib/claude-desktop/` 到 `AppDir/bin/`。程序文件不取自系统安装目录。

## 打包元数据与版本参数

- 应用名、主程序、窗口类、图标和 desktop 直接赋值，来源见 [固定配置说明](hardcoded.md)。
- 版本调用为 `read_app_version.sh pacman claude-desktop`，最终仍在成功生成 AppImage 后单行保存到 `dist/version.txt`。
- quick-sharun 输入为 `AppDir/bin/*`，未增加未经确认的辅助程序参数，也没有额外的 `NO_STRIP`、`STRACE_MODE` 或许可证复制段。

## 官方专属处理的状态

用户本次明确要求暂不采用 pkgforge-dev 的 QEMU / 固件部署、独立 NSPR hook、asar 修改及其他专属开关。相关代码只保存在 [pkgforge 差异记录](pkgforge-differences.md)，状态为“未启用”，不属于当前模板中已经生效的差异。

后续用户要求加入某项处理时，必须重新读取对应官方仓库的当前源码，确认它仍存在且适用，再取得本次加入的授权。固定 commit 的历史记录不能作为自动恢复依据。

## 验证边界

模板检查覆盖 69 行、通用注释、空行、执行顺序及允许变化的参数位置。公共下载入口通过临时目录中的调用与失败处理检查，不把测试代码加入正式构建；这些检查不等于新的 AppImage 或 Cowork 已经实机验证。
