# Keyviz AppImage 构建维护

本目录专门维护 Keyviz 汉化版 AppImage，避免把版本、源码修补和打包逻辑全部堆在仓库根目录。

## 目录

```text
Keyviz/
├── build_keyviz.sh          # 实际构建脚本
├── version.conf             # 上游仓库、固定提交、版本号、tao 稳定版本
└── patches/
    ├── 01_key_event.py      # 普通按键默认显示 + anylinux 独立配置键
    ├── 02_app_state.py      # Rust 后端同步配置键
    ├── 03_window_title.py   # 主 Overlay 独立窗口标题
    ├── 04_linux_gtk.py      # Linux GTK/GDK 直接依赖
    └── 05_linux_overlay.py  # Linux/X11/i3 焦点、置顶和鼠标穿透修复
```

GitHub Actions 直接调用 `Keyviz/build_keyviz.sh`；真正构建逻辑均位于本目录。

## 后续升级 Keyviz

1. 先修改 `version.conf` 中的 `KEYVIZ_REF` 和 `KEYVIZ_VERSION`。
2. 不要直接删除补丁检查后硬编译；逐个核对 `patches/` 是否仍适配新源码。
3. 如果某个上游文件发生变化，对应补丁会主动报错并停止，避免旧修复误覆盖新版本。
4. Linux Overlay 修复单独放在 `05_linux_overlay.py`，后续重点检查 Tauri/tao/GTK 窗口逻辑。
5. 构建仍固定使用 anylinux + quick-sharun，最终产物保持 `dist/keyviz.AppImage`。

## 当前基线

- 汉化源码：`zetaloop/keyviz`
- Keyviz：`2.1.0`
- 固定提交：`abff97c6687e96736c63d4dad1c4bba06a1f8205`
- tao：`0.34.8`
- AppImage：anylinux + quick-sharun
