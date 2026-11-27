# Keyviz 专用打包流程与模板差异

## 分类与两项来源核实

本项目登记在[专用打包流程](../../docs/packaging-classification.md#专用打包流程)，不新增第 14 份标准模板。本次手动对齐 `alttab`、`st`、`webcamoid` 等源码编译类专用流程及 [quick-sharun 固定注释标准](../../docs/quick-sharun-comments.md)。

两项前置核实结果：

1. **`pkgforge-dev` 官方打包**：检索 `keyviz`，未查到对应打包仓库。
2. **官方与 AUR 来源核实**：
   - 官方仓库 `mulaRahul/keyviz` 最新正式版 `v2.1.2` 仅发布 `macos.dmg` 与 `windows.msi`，没有官方 Linux DEB 或 AppImage。
   - 官方源码已接入 `i18next` 并内置 `src/locales/zh-CN/translation.json` 与 Rust 托盘中文文案，同时 `Cargo.lock` 已升级至 `tao 0.37.2`、`tauri 2.12.5`、`gtk 0.18.2`，且 `src-tauri/crates/rdev/Cargo.toml` 完整保留 Linux X11（`xlib`、`xrecord`、`xinput`）支持。因此不再需要旧版依赖的第三方汉化分支 `zetaloop/keyviz` 与 `tao 0.34.8` 变通，直接切换为官方最新正式 Release 源码，官方翻译文件保持原样不改。
   - 官方 `src-tauri/src/app/window.rs` 仍只有 Windows 与 macOS 分支、缺少 Linux 处理，且在 `window.show()` 前调用 `set_ignore_cursor_events(true)`；在 X11 / i3 环境下覆盖层会被窗口管理器接管并拦截鼠标点击。AUR 现有包也不含该 Linux 窗口修复。

因此不能改用现成 DEB 模板（`tauri-gtk-deb.sh`），必须保留源码打补丁编译流程。

## 公共阶段对齐

| 阶段 | 当前处理 | 依据与影响 |
| --- | --- | --- |
| 初始化 | 严格模式，定位并切换至 `keyviz/` 目录。 | 相对路径和产物均落在应用目录内。 |
| 依赖安装 | `common/arch/install_packages.sh --base` 加一行应用编译与运行依赖。 | 逐项核对原脚本显式包名：`base-devel`、`wget`、`binutils`、`patchelf`、`coreutils`、`appstream-glib`、`desktop-file-utils`、`util-linux`、`zsync`、`git`、`python`、`pkgconf`、`openssl`、`xdg-utils`、`ibus`、`jq`、`file` 已由 `--base` 覆盖；第二行保留其余全部原有包（`dwarfs-bin`、`nodejs-lts-jod`、`npm`、`rust`、`gtk3`、`webkit2gtk-4.1`、`libayatana-appindicator`、`libx11`、`libxi`、`libxtst`），并按仓库 GTK 3 GUI 规范补充 `fcitx5-gtk`。 |
| 工作区 | `common/build/prepare_x86_64_workspace.sh "$SCRIPT_DIR" --skip-create AppDir work dist`。 | 替代原脚本根目录下 `.keyviz-build` 与 `dist` 的手工清理，输出统一到 `keyviz/dist/`。 |
| 源码与版本 | `common/github/download_latest_stable_release_source.sh mulaRahul/keyviz "$SOURCE_DIR" --archive`，版本取 `${KEYVIZ_TAG#v}`。 | 通过认证 API 按正式 Release 标签解析完整提交并下载解包源码归档；以 Release 标签作为实际版本（核实 `v2.1.2` 源码内的 `src-tauri/tauri.conf.json` 仍写着旧值 `2.1.1`，故不以该字段为准）。 |
| 中文环境 | 收集依赖后生成 `AppDir/lib/locale/zh_CN.utf8` 并写入 `AppDir/.env`。 | 按 `anylinux_projects.md` 补齐 GTK 3 GUI 包内中文 locale，使官方内置 `zh-CN` 翻译在未预装宿主中文 locale 的系统上也能自动生效。 |
| 封装与版本保存 | `quick-sharun --make-appimage` 后调用 `common/build/save_appimage_version.sh`。 | 统一产物非空检查、执行权限和 `dist/version.txt` 写入。 |

## 保留的专属处理

以下处理均在 [build_keyviz.sh](../build_keyviz.sh) 中以 `# 本程序专属处理：` 标注：

| 处理 | 代码位置 | 保留原因与影响 |
| --- | --- | --- |
| 5 份独立源码补丁与静态核对 | `patches/01_key_event.py` ~ `05_linux_overlay.py` 及 [build_keyviz.sh](../build_keyviz.sh#L27-L51) | `01`–`04` 与官方 `v2.1.2` 源码完全匹配原样沿用；`05_linux_overlay.py` 改为精确锚点注入（先确认源码不含 `#[cfg(target_os = "linux")]`，保留上游 Windows / macOS 逻辑，仅为 Linux 注入 `override-redirect`、禁焦与 `show()` 后鼠标穿透）。核对防止回退到旧 `set_pass_through` 或 `i3-msg`。 |
| 前端安装与 Linux/X11 检查 | [build_keyviz.sh](../build_keyviz.sh#L53-L59) | 按上游锁文件执行 `npm ci`，并在编译前确认 `rdev` 的 Linux/X11 依赖配置仍在。 |
| Linux GTK 依赖锁文件同步与校验 | [build_keyviz.sh](../build_keyviz.sh#L61-L68) | `04_linux_gtk.py` 向 `Cargo.toml` 增加 `gtk 0.18` 直接依赖（复用 `Cargo.lock` 既有 `gtk 0.18.2`）后同步并校验 `cargo metadata --locked`；因官方已使用 `tao 0.37.2`，不再执行旧的 `tao 0.34.8` 锁定命令。 |
| Tauri 无打包编译与系统路径安装 | [build_keyviz.sh](../build_keyviz.sh#L70-L94) | 仅编译 release 二进制（不调用 Tauri 自带 AppImage bundler），安装二进制、图标及通过 `desktop-file-validate` 校验的 `keyviz.desktop` 到 `/usr` 供 quick-sharun 收集。 |
| WebKitGTK / OpenGL 导出与辅助命令收集 | [build_keyviz.sh](../build_keyviz.sh#L110-L118) | 保留 `DEPLOY_OPENGL=1`、`DEPLOY_WEBKIT2GTK=1`、`WEBKIT2GTK_DIR=/usr/lib/webkit2gtk-4.1`，并同次收集 `/usr/bin/keyviz`、`/usr/bin/xdg-open` 与 `/usr/bin/xdg-mime`。 |

## 工作流说明

`.github/workflows/build.yml` 中的独立 `build_keyviz` Job 继续保留已验证的 `anylinux-setup-action` v2 环境，脚本与产物路径统一为 `keyviz/` 与 `keyviz/dist/`，并在构建步骤显式传入 `GITHUB_TOKEN` 供公共 GitHub API 入口认证。
