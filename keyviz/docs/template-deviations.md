# Keyviz 专用打包流程与模板差异

## 分类与两项来源核实

本项目登记在[专用打包流程](../../docs/packaging-classification.md#专用打包流程)，不新增第 14 份标准模板。本次按仓库本地工作区直接交付最终版的授权，手动对齐 `alttab`、`st`、`webcamoid` 等源码编译类专用流程及 [quick-sharun 固定注释标准](../../docs/quick-sharun-comments.md)。

两项前置核实结果：

1. **`pkgforge-dev` 官方打包**：检索 `keyviz`，未查到对应打包仓库。
2. **官方及 AUR 现成包核实**：
   - 英文原版 `mulaRahul/keyviz` 最新正式版 `v2.1.2` 仅提供 `macos.dmg` 与 `windows.msi`，无 Linux DEB 或 AppImage。
   - 汉化分支 `zetaloop/keyviz` 最新正式版 `v2.1.0` 提供 `keyviz_2.1.0_amd64.deb` 等包，AUR 也存在 `keyviz`、`keyviz-zh` 等包，但均无法直接用于本仓库的 Linux/X11/i3 目标环境：
     - 上游 `src-tauri/src/app/window.rs` 只有 Windows 与 macOS 平台分支，缺少 Linux `override-redirect`、禁焦与 `show()` 后鼠标穿透处理，覆盖层会被窗口管理器接管并拦截鼠标点击。
     - 上游锁定的 `tao 0.34.5` 在 Linux 会触发 `event_loop unwrap` 崩溃，必须在编译前升级至 `tao 0.34.8`。
     - 上游默认过滤普通按键，需通过源码补丁调整默认配置与独立配置键。

因此不能改用现成 DEB 模板（`tauri-gtk-deb.sh`），必须保留源码打补丁编译流程。

## 公共阶段对齐

| 阶段 | 当前处理 | 依据与影响 |
| --- | --- | --- |
| 初始化 | 严格模式，定位并切换至 `keyviz/` 目录。 | 相对路径和产物均落在应用目录内。 |
| 依赖安装 | `common/arch/install_packages.sh --base` 加一行应用编译与运行依赖。 | 逐项核对原脚本显式包名：`base-devel`、`wget`、`binutils`、`patchelf`、`coreutils`、`appstream-glib`、`desktop-file-utils`、`util-linux`、`zsync`、`git`、`python`、`pkgconf`、`openssl`、`xdg-utils`、`ibus`、`jq`、`file` 已由 `--base` 覆盖；第二行保留其余全部原有包（`dwarfs-bin`、`nodejs-lts-jod`、`npm`、`rust`、`gtk3`、`webkit2gtk-4.1`、`libayatana-appindicator`、`libx11`、`libxi`、`libxtst`），并按仓库 GTK 3 GUI 规范补充 `fcitx5-gtk`。 |
| 工作区 | `common/build/prepare_x86_64_workspace.sh "$SCRIPT_DIR" --skip-create AppDir work dist`。 | 替代原脚本根目录下 `.keyviz-build` 与 `dist` 的手工清理，输出统一到 `keyviz/dist/`。 |
| 源码获取 | `common/github/download_default_branch_source.sh zetaloop/keyviz` + `common/archive/extract_archive.sh`。 | 取代直接 `git clone` 并移除 `version.conf`；动态跟随 `zetaloop/keyviz` 默认分支，同时保留 5 份补丁的严格上下文及 `window.rs` SHA-256 校验，上游改动相关文件时编译前直接中止。 |
| 版本读取 | `common/build/read_app_version.sh package-json "$SOURCE_DIR/src-tauri/tauri.conf.json"`。 | 直接从当次源码配置动态读取软件版本，不再硬编码 `2.1.0`。 |
| 中文环境 | 收集依赖后生成 `AppDir/lib/locale/zh_CN.utf8` 并写入 `AppDir/.env`。 | 按 `anylinux_projects.md` 补齐 GTK 3 GUI 的包内中文 locale。 |
| 封装与版本保存 | `quick-sharun --make-appimage` 后调用 `common/build/save_appimage_version.sh`。 | 统一产物非空检查、执行权限和 `dist/version.txt` 写入。 |

## 保留的专属处理

以下处理均在 [build_keyviz.sh](../build_keyviz.sh) 中以 `# 本程序专属处理：` 标注：

| 处理 | 代码位置 | 保留原因与影响 |
| --- | --- | --- |
| 5 份独立源码补丁与静态核对 | `patches/01_key_event.py` ~ `05_linux_overlay.py` 及 [build_keyviz.sh](../build_keyviz.sh#L23-L47) | 维持普通按键默认显示、独立配置键、Overlay 窗口标题、Linux GTK 直接依赖及 X11/i3 禁焦置顶与鼠标穿透；核对防止回退到旧 `set_pass_through` 或 `i3-msg`。 |
| 前端安装与 Linux/X11 检查 | [build_keyviz.sh](../build_keyviz.sh#L49-L55) | 按上游锁文件执行 `npm ci`，并在编译前确认 `rdev` 的 Linux/X11 依赖配置仍在。 |
| `tao 0.34.8` 锁定与锁文件校验 | [build_keyviz.sh](../build_keyviz.sh#L57-L67) | 规避 `tao 0.34.5` 的 Linux `event_loop unwrap` 崩溃，并在生成元数据后执行 `cargo metadata --locked` 校验；依据见 [hardcoded.md](./hardcoded.md)。 |
| Tauri 无打包编译与系统路径安装 | [build_keyviz.sh](../build_keyviz.sh#L69-L93) | 仅编译 release 二进制（不调用 Tauri 自带 AppImage bundler），安装二进制、图标及通过 `desktop-file-validate` 校验的 `keyviz.desktop` 到 `/usr` 供 quick-sharun 收集。 |
| WebKitGTK / OpenGL 导出与辅助命令收集 | [build_keyviz.sh](../build_keyviz.sh#L109-L120) | 保留 `DEPLOY_OPENGL=1`、`DEPLOY_WEBKIT2GTK=1`、`WEBKIT2GTK_DIR=/usr/lib/webkit2gtk-4.1`，并同次收集 `/usr/bin/keyviz`、`/usr/bin/xdg-open` 与 `/usr/bin/xdg-mime`。 |

## 工作流说明

`.github/workflows/build.yml` 中的独立 `build_keyviz` Job 继续保留已验证的 `anylinux-setup-action` v2 环境，仅将脚本与产物路径同步为 `keyviz/` 与 `keyviz/dist/`，并在构建步骤显式传入 `GITHUB_TOKEN` 供公共 GitHub API 入口认证。
