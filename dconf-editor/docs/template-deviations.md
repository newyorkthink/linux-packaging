# dconf Editor 模板差异

## 当前模板

构建脚本以 [GTK Ubuntu 仓库模板](../../templates/appimage/linuxdeploy-gtk-apt.sh) 为基础。使用 Ubuntu 24.04 官方 APT 仓库的 dconf Editor 和 dconf CLI，产物版本以实际解包的主包为准。

AppRun 保留模板的 GIO 模块和共享数据路径配置。最终启动图形程序时用 `exec env -u GSETTINGS_SCHEMA_DIR` 清除该变量，绕开 45.0.1 读取 schema 路径的越界逻辑。该处理仅用于此应用，依据见[故障记录](./errors.md)。最终封装和版本保存使用公共入口的默认方式。

本次按模板移除了原有 CLI 软链接分派、Fcitx5 专用缓存、强制中文处理、专属运行检查和显式封装参数。已完成生成器的 Bash 语法检查，实际构建和运行待验证。

## 旧脚本的历史基线

1. 固定使用 Ubuntu 24.04 构建，直接采用发行版官方 dconf-editor 45.0.1。
2. 不打包 glibc 与动态加载器，最终 AppImage 的 GLIBC 运行基线不高于 Ubuntu 24.04 的 2.39。
3. 保留宿主 HOME、XDG_CONFIG_HOME、DBUS_SESSION_BUS_ADDRESS，实际读写宿主用户自己的 dconf 数据库。
4. XDG_DATA_DIRS 同时保留 AppImage 与宿主目录，使 dconf Editor 能读取自身和宿主 GSettings schemas。
5. 内置简体中文翻译和 zh_CN.UTF-8 locale 数据，并固定界面使用简体中文，避免依赖宿主语言包或宿主语言设置。
6. 内置 Fcitx5 GTK3 输入法模块并生成独立模块缓存，避免 GTK 加载宿主 IBus 模块导致 GLib ABI 冲突。
7. linuxdeploy、appimagetool 与 Type 2 runtime 均通过公共脚本从官方 continuous Release 动态取得，并按当前 Release digest 校验。
8. 同一个 AppImage 同时内置 dconf Editor GUI 和 dconf CLI；外部软链接名为 dconf 时由 Type 2 runtime 的 ARGV0 直接分派到 CLI。

### 旧脚本的专属处理

| 阶段 | 处理 | 依据与影响 |
| --- | --- | --- |
| 初始化与应用准备 | 保留 Ubuntu 24.04、dconf Editor 45.0.1 的检查，随包部署 dconf CLI。 | 保留发行版和 GLIBC 基线，Ubuntu 包修订号仍可变化。 |
| 桌面资源与运行库 | 保留图标选择、GSettings schema 编译、dconf backend 与 Fcitx5 GTK3 模块的部署和缓存检查。 | 两个模块都由运行时加载。Fcitx5 专用缓存用于避免加载宿主 IBus 模块引发的 GLib ABI 冲突。 |
| AppRun | 逐字保留现有正文，包括宿主路径与会话、`GIO_EXTRA_MODULES`、`ARGV0` 分派和 GUI 的中文环境。 | 保留宿主 schema 与 dconf 数据库访问、GUI 输入法以及同一 AppImage 的 CLI 入口。 |
| 整理产物 | 保留内联 ELF locale 路径补丁，放在依赖部署完成后、最终封装前。 | 保留包内中文翻译定位，现有补丁正文原样沿用。 |
| 整理产物 | 公共封装入口传入 `--no-appstream`，保留明确的 Type 2 runtime 与原参数顺序。 | 保留 AppStream 元数据，跳过新版校验器对 45.0.1 历史元数据的检查。 |
| 产物检查 | 保留 AppRun、GLIBC 2.39、库及资源、中文帮助、CLI 分派与 Xvfb 启动检查。 | 构建脚本通过这些检查后，现有 workflow 才上传产物与版本清单。 |

本次迁移完成脚本语法及工作流静态检查。Ubuntu 24.04 正式构建与实机运行待验证。
