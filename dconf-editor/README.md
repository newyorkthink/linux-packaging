# dconf Editor AppImage

## 用途与产物

本目录在 Ubuntu 24.04 构建 dconf Editor AppImage，固定产物为 `dist/dconf-editor.AppImage`；同一个 AppImage 同时保留 dconf Editor GUI 与 dconf CLI。

## 技术栈与打包方式

dconf Editor 为 GTK3 / GLib 应用。构建脚本固定使用 Ubuntu 24.04 的 dconf Editor 45.0.1，配合 linuxdeploy、固定 appimagetool 与 Type 2 runtime，内置简体中文 locale、dconf GSettings backend 和 Fcitx5 GTK3 输入模块，同时保持宿主 dconf 数据库与 D-Bus 会话。

## 运行

```bash
./dist/dconf-editor.AppImage
```

需要 CLI 时可将同一 AppImage 建立名为 `dconf` 的软链接，由现有 AppRun 按 ARGV0 分派。

## 版本元数据

软件版本继续以构建脚本中的 `EXPECTED_DCONF_EDITOR_VERSION` 为唯一基线。workflow 在正式构建完成后读取该值并生成 `dist/version.txt`，随后上传 `software-version-dconf-editor` artifact；不修改现有打包脚本中的运行与兼容逻辑。

## 变更记录

### 2026-09-16：接入统一软件版本元数据

仅在正式 workflow 中增加版本文件生成、artifact 上传与统一 `software_versions.json` 映射；现有 Ubuntu、GLIBC、中文 locale、Fcitx5、dconf backend 和固定打包工具基线均保持不变。
