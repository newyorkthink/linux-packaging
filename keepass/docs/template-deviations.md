# KeePass 模板差异

KeePass 使用 Arch 官方发行的 Mono 程序，在独立 Arch Linux 容器构建。公共安装、下载、解包和版本入口按仓库标准调用。现有模板没有 GTK2 分层依赖和扫描前后的插件与运行环境部署，因此采用专用流程。

| 阶段 | 处理与依据 |
| --- | --- |
| 工作目录 | 从仓库根目录构建。`PrecompilePlgx.cs` 从当前目录下的 `keepass/` 读取兼容补丁；`AppDir` 和 `dist` 也位于仓库根目录。 |
| 依赖安装 | 先安装 GTK2，再安装 `gtk-sharp-2`、`gtk-engine-murrine` 和 `gtk-engines`，最后安装 KeePass、主题和其余依赖。`makepkg` 只检查已安装依赖，同一批次中尚未安装的编译结果会导致依赖检查失败。已验证的分层处理见 [README](../README.md#gtk2-依赖分层安装修复2026-10-18)。KPScript 由 AUR 安装，重试依据见[固定配置](./hardcoded.md#kpscript-重试间隔)。 |
| 扫描前 | 改用 Keebuntu 的 GTK2 XEmbed 托盘插件，替代旧的 `keepass2-plugin-tray-icon`，无需全局启动 `snixembed`。`GtkStatusIcon.dll` 放在功能插件之前加载的位置，避免 KeePassOTP 调整托盘菜单后影响初始化。KeePassOTP 和 GlobalSearch 的正式 PLGX 在构建时预编译。 |
| Mono 补丁 | 编译 KeePassOTP 时，`PrecompilePlgx.cs` 编译 `MonoMessageBoxFix`、`MonoMainTreeFix`、`MonoListViewFormLayoutFix` 和 `MonoI3TabFocusFix`。`patches/prepare_plugins.sh` 单独编译 `MonoMouseWheelFix` 和 `KeePassWindowLayoutFix`。各兼容补丁独立维护。窗口布局补丁保留插件管理器单选处理。 |
| 依赖收集 | 收集现有参数列出的 Mono、GTK2、GTK3 和运行库。GTK2 使用 Materia Light 浅色主题，避免 Raleigh 灰色界面和淡黄色内置配色。`gnome-themes-extra-gtk2` 和 `gtk-engine-murrine` 提供该主题引用的 Adwaita 和 Murrine 引擎。`gtk-sharp-2` 是 Keebuntu 托盘插件运行依赖，`libappindicator`、`libdbusmenu` 和 `libnotify` 用于托盘指示器。KeePass 由 Mono 动态加载 Argon2 和 AES-KDF 原生加速库，需显式收集 `libargon2`、`libgcrypt` 和 `libgpg-error`。 |
| 扫描后 | `patches/prepare_appdir.sh` 复制简体中文语言文件、思源黑体及其许可证，配置包内 Fontconfig，以避免中文在查找框中被裁切以及备注文字基线不一致，检查 AppDir 内容并写入 KeePass 与 KPScript 的两个启动脚本。 |
| 封装 | 在仓库根目录生成 `dist/keepass.AppImage`。版本由公共入口从本次实际安装的 Arch `keepass` 包读取，并写入 `dist/version.txt`。 |

最新实机结果见 [README 的实机验证记录](../README.md#实机验证)。历史验证见[稳定基线](../KEEPASS_STABLE.md)。
