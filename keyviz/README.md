# Keyviz AppImage 构建维护

本目录维护 Keyviz 汉化版 AppImage，采用源码补丁编译加 quick-sharun 封装的[专用打包流程](../docs/packaging-classification.md#专用打包流程)。模板差异见 [template-deviations.md](./docs/template-deviations.md)，固定配置见 [hardcoded.md](./docs/hardcoded.md)。

## 目录

```text
keyviz/
├── build_keyviz.sh          # 构建脚本（专用打包流程）
├── README.md                # 本说明
├── docs/
│   ├── template-deviations.md  # 专用流程依据与模板差异
│   └── hardcoded.md            # 固定版本与配置依据
└── patches/
    ├── 01_key_event.py      # 普通按键默认显示 + anylinux 独立配置键
    ├── 02_app_state.py      # Rust 后端同步配置键
    ├── 03_window_title.py   # 主 Overlay 独立窗口标题
    ├── 04_linux_gtk.py      # Linux GTK/GDK 直接依赖
    └── 05_linux_overlay.py  # Linux/X11/i3 焦点、置顶和鼠标穿透修复
```

GitHub Actions 由独立 `build_keyviz` Job 调用 `keyviz/build_keyviz.sh`，最终产物为 `keyviz/dist/keyviz.AppImage`，版本元数据写入 `keyviz/dist/version.txt`。

## 构建来源与升级说明

1. 构建通过 `common/github/download_default_branch_source.sh` 动态获取 `zetaloop/keyviz` 默认分支当前提交并解包，通过 `common/build/read_app_version.sh` 直接从 `src-tauri/tauri.conf.json` 读取软件版本，不再单独维护 `version.conf`。
2. 不要删除补丁检查后硬编译；如果上游改动了被修补文件，对应补丁会在编译前主动报错并停止，避免旧修复误覆盖新版源码。
3. Linux Overlay 修复单独放在 `patches/05_linux_overlay.py`，后续若上游更新，重点核对 Tauri / `tao` / GTK 窗口逻辑以及 `tao` 版本要求。
4. 构建保持 `anylinux-setup-action` v2 与 quick-sharun 封装，并按仓库 GTK 3 GUI 规范内置中文 locale 与 `fcitx5-gtk` 输入模块。

## 当前基线

- 汉化源码：`zetaloop/keyviz`（默认分支动态获取）
- `tao` 固定版本：`0.34.8`（见 [hardcoded.md](./docs/hardcoded.md)）
- AppImage：anylinux + quick-sharun

## 2026-09-16：接入统一软件版本元数据

- 当时版本以旧 `version.conf` 中经过源码与补丁基线核对的 `KEYVIZ_VERSION` 为准。
- `build_keyviz.sh` 在 AppImage 构建完成后写入 `version.txt`，不改变源码补丁、`tao` 或 quick-sharun 基线。
- 自定义 Keyviz Job 上传 `software-version-keyviz` artifact，成功后将 `keyviz.AppImage` 写入统一 `software_versions.json`。

## 2026-11-27：目录统一小写并按专用流程标准化

- 目录由 `Keyviz/` 统一改为小写 `keyviz/`，并移除静态 `version.conf`。
- 依赖安装、工作区准备、源码拉取、版本读取与版本保存全部切换至仓库 `common/` 公共入口，产物路径统一到 `keyviz/dist/`，同时保留全部 5 份源码补丁、`tao 0.34.8`、桌面入口与 quick-sharun 收集配置，并补齐包内中文 locale 与 `fcitx5-gtk`。
- 完成两项前置来源核实后登记至 [专用打包流程](../docs/packaging-classification.md#专用打包流程)，详见 [template-deviations.md](./docs/template-deviations.md)。
