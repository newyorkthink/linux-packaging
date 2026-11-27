# Keyviz 固定配置

本页记录 Keyviz 构建脚本与补丁中的固定来源、依赖约束和关键路径依据。Keyviz 软件版本由 `common/github/download_latest_stable_release_source.sh` 按官方最新正式 Release 标签动态获取，不硬编码应用版本号或打包工具版本；专用流程与模板差异见 [template-deviations.md](./template-deviations.md)。

## 固定配置清单

| 配置 | 当前取值 | 依据与用途 |
| --- | --- | --- |
| 上游源码仓库 | `mulaRahul/keyviz`（最新正式 Release） | 官方仓库已内置 `zh-CN` 简体中文界面与托盘翻译，且已升级至 `tao 0.37.2`；通过 `common/github/download_latest_stable_release_source.sh --archive` 动态获取对应提交源码归档，[构建位置](../build_keyviz.sh#L21-L25)。 |
| Linux GTK 直接依赖 | `gtk = { version = "0.18", features = ["v3_24"] }` | 供 `05_linux_overlay.py` 访问 `gtk_window` 与 `GdkWindow` 接口以设置 `override-redirect` 和禁焦属性，仅作用于 `target_os = "linux"`，直接复用官方 `Cargo.lock` 既有的 `gtk 0.18.2`，[补丁位置](../patches/04_linux_gtk.py)。 |
| Linux Overlay 锚点补丁 | 精确匹配 `config_window` 顶部与 `window.show()` 行，禁止源码已含 `#[cfg(target_os = "linux")]` | 保留上游 Windows / macOS 分支，仅向 Linux 注入 `override-redirect`、禁焦与 `show()` 后鼠标穿透；上游若变动窗口初始化逻辑或新增原生 Linux 分支则编译前主动停止，[补丁位置](../patches/05_linux_overlay.py)。 |
| 独立配置键与默认过滤 | `key_event_store_anylinux_v1`、`filter: "none"` | 避免与宿主其他构建的旧配置冲突，并让普通按键默认直接显示，[补丁位置](../patches/01_key_event.py)、[后端同步](../patches/02_app_state.py)。 |
| 主覆盖层窗口标题 | `"Keyviz Overlay"` | 将透明覆盖层与设置窗口区分，便于窗口管理与排查，[补丁位置](../patches/03_window_title.py)。 |
| WebKitGTK 运行目录与部署开关 | `DEPLOY_GTK=1`、`DEPLOY_OPENGL=1`、`DEPLOY_WEBKIT2GTK=1`、`WEBKIT2GTK_DIR=/usr/lib/webkit2gtk-4.1` | 沿用仓库 Tauri / WebKitGTK 4.1 的 quick-sharun 基线，完整收集 GTK、OpenGL 与 WebKitGTK 子进程目录，[构建位置](../build_keyviz.sh#L108-L115)。 |
| 收集目标 | `/usr/bin/keyviz`、`/usr/bin/xdg-open`、`/usr/bin/xdg-mime` | 保留主程序及外链/MIME 打开辅助命令，[构建位置](../build_keyviz.sh#L117-L118)。 |
| 桌面入口与产物路径 | `STARTUPWMCLASS=keyviz`、`dist/keyviz.AppImage`、`dist/version.txt` | 对齐 `.github/appimage-apps.json` 中的 `keyviz` 资产名与统一软件版本清单接口，[构建位置](../build_keyviz.sh#L96-L107)、[保存位置](../build_keyviz.sh#L133-L134)。 |
