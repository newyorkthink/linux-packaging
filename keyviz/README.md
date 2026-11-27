# Keyviz AppImage 构建维护

本目录维护官方 Keyviz AppImage，采用上游正式 Release 源码打补丁编译加 quick-sharun 封装的[专用打包流程](../docs/packaging-classification.md#专用打包流程)。模板差异见 [template-deviations.md](./docs/template-deviations.md)，固定配置见 [hardcoded.md](./docs/hardcoded.md)。

## 目录

```text
keyviz/
├── build_keyviz.sh          # 构建脚本（专用打包流程）
├── README.md                # 本说明
├── docs/
│   ├── template-deviations.md  # 专用流程依据与模板差异
│   └── hardcoded.md            # 固定来源与配置依据
└── patches/
    ├── 01_key_event.py      # 普通按键默认显示 + anylinux 独立配置键
    ├── 02_app_state.py      # Rust 后端同步配置键
    ├── 03_window_title.py   # 主 Overlay 独立窗口标题
    ├── 04_linux_gtk.py      # Linux GTK/GDK 直接依赖
    └── 05_linux_overlay.py  # Linux/X11/i3 焦点、置顶和鼠标穿透修复
```

GitHub Actions 由独立 `build_keyviz` Job 调用 `keyviz/build_keyviz.sh`，最终产物为 `keyviz/dist/keyviz.AppImage`，版本元数据写入 `keyviz/dist/version.txt`。

## 构建来源与升级说明

1. 构建通过 `common/github/download_latest_stable_release_source.sh` 的 `--archive` 模式动态拉取官方仓库 `mulaRahul/keyviz` 最新正式 Release 对应提交的源码归档，版本号取自该 Release 标签（去掉 `v` 前缀）。官方源码已自带 `zh-CN` 简体中文界面与托盘翻译，本仓库不修改官方翻译文件。
2. 不要删除补丁检查后硬编译；如果上游改动了被修补文件或新增了原生 Linux 分支，对应补丁会在编译前主动报错并停止，避免旧修复误覆盖新版源码。
3. Linux Overlay 修复单独放在 `patches/05_linux_overlay.py`，仅针对 `config_window` 精确锚点插入 Linux 处理，保留上游 Windows 与 macOS 代码。
4. 构建保持 `anylinux-setup-action` v2 与 quick-sharun 封装，并按仓库 GTK 3 GUI 规范内置中文 locale 与 `fcitx5-gtk` 输入模块。

## 当前基线

- 官方源码：`mulaRahul/keyviz`（最新正式 Release 动态获取，原生含 `zh-CN` 与 `tao 0.37.x`）
- AppImage：anylinux + quick-sharun

## 2026-09-16：接入统一软件版本元数据

- 当时版本以旧 `version.conf` 中经过源码与补丁基线核对的 `KEYVIZ_VERSION` 为准。
- `build_keyviz.sh` 在 AppImage 构建完成后写入 `version.txt`，不改变源码补丁、`tao` 或 quick-sharun 基线。
- 自定义 Keyviz Job 上传 `software-version-keyviz` artifact，成功后将 `keyviz.AppImage` 写入统一 `software_versions.json`。

## 2026-11-27：目录统一小写、按专用流程标准化并切换至官方源码

- 目录由 `Keyviz/` 统一改为小写 `keyviz/`，移除旧 `version.conf`，依赖安装、工作区准备、源码获取与版本保存全部接入 `common/` 公共入口。
- 核实官方 `mulaRahul/keyviz`（`v2.1.2`）已内置 `zh-CN` 简体中文界面与托盘翻译、并将 `tao` 升级至 `0.37.2`；因此从停更的汉化分支 `zetaloop/keyviz` 切换回官方最新正式 Release 源码，移除旧的 `tao 0.34.8` 变通，将 `05_linux_overlay.py` 适配为精确锚点注入（保留上游 Windows / macOS 分支与原样翻译），详见 [template-deviations.md](./docs/template-deviations.md)。
