# Keyviz 固定配置

本页记录 Keyviz 构建脚本与补丁中的固定来源、固定依赖版本和关键路径依据。软件自身版本由公共入口从当次拉取的 `src-tauri/tauri.conf.json` 动态读取，不硬编码 Keyviz 版本号或打包工具版本；专用流程与模板差异见 [template-deviations.md](./template-deviations.md)。

## 固定配置清单

| 配置 | 当前取值 | 依据与用途 |
| --- | --- | --- |
| 上游源码仓库 | `zetaloop/keyviz`（默认分支） | 英文原版 `mulaRahul/keyviz` 未发布 Linux 构建且无完整中文界面；本仓库沿用汉化分支默认分支源码，通过 `common/github/download_default_branch_source.sh` 动态拉取，[构建位置](../build_keyviz.sh#L18-L21)。 |
| `tao` 升级目标版本 | `TAO_VERSION="0.34.8"` | 汉化分支 `Cargo.lock` 锁定 `tao 0.34.5`，在 Linux 下会触发 `event_loop unwrap` 崩溃；固定升级到同一 `0.34` 系列的稳定版本 `0.34.8` 并经 `cargo metadata --locked` 核对，[构建位置](../build_keyviz.sh#L57-L67)。 |
| Linux GTK 直接依赖 | `gtk = { version = "0.18", features = ["v3_24"] }` | 供 `05_linux_overlay.py` 访问 `gtk_window` 与 `GdkWindow` 接口以设置 `override-redirect` 和禁焦属性，仅作用于 `target_os = "linux"`，[补丁位置](../patches/04_linux_gtk.py)。 |
| `window.rs` 原文校验摘要 | SHA-256 `86565b3651f08b411ca61c439ba89978b824686d8172c9d91012dc637d15e670` | `05_linux_overlay.py` 覆写 Linux 窗口初始化逻辑前先校验上游 `window.rs` 原文摘要，避免上游改动后旧补丁静默覆盖新代码，[补丁位置](../patches/05_linux_overlay.py#L13-L18)。 |
| 独立配置键与默认过滤 | `key_event_store_anylinux_v1`、`filter: "none"` | 避免与宿主其他构建的旧配置冲突，并让普通按键默认直接显示，[补丁位置](../patches/01_key_event.py)、[后端同步](../patches/02_app_state.py)。 |
| 主覆盖层窗口标题 | `"Keyviz Overlay"` | 将透明覆盖层与设置窗口区分，便于窗口管理与排查，[补丁位置](../patches/03_window_title.py)。 |
| WebKitGTK 运行目录与部署开关 | `DEPLOY_GTK=1`、`DEPLOY_OPENGL=1`、`DEPLOY_WEBKIT2GTK=1`、`WEBKIT2GTK_DIR=/usr/lib/webkit2gtk-4.1` | 沿用仓库 Tauri / WebKitGTK 4.1 的 quick-sharun 基线，完整收集 GTK、OpenGL 与 WebKitGTK 子进程目录，[构建位置](../build_keyviz.sh#L107-L114)。 |
| 收集目标 | `/usr/bin/keyviz`、`/usr/bin/xdg-open`、`/usr/bin/xdg-mime` | 保留主程序及外链/MIME 打开辅助命令，[构建位置](../build_keyviz.sh#L119-L120)。 |
| 桌面入口与产物路径 | `STARTUPWMCLASS=keyviz`、`dist/keyviz.AppImage`、`dist/version.txt` | 对齐 `.github/appimage-apps.json` 中的 `keyviz` 资产名与统一软件版本清单接口，[构建位置](../build_keyviz.sh#L95-L106)、[保存位置](../build_keyviz.sh#L135-L136)。 |
