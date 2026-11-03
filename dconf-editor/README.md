# dconf Editor AppImage

## 用途与产物

本目录在 Ubuntu 24.04 构建 dconf Editor AppImage，固定产物为 `dist/dconf-editor.AppImage`；同一个 AppImage 同时保留 dconf Editor GUI 与 dconf CLI。

## 技术栈与打包方式

dconf Editor 为 GTK3 / GLib 应用，使用 Ubuntu 24.04 仓库的 dconf Editor 45.0.1。公共 APT 入口下载并解包与构建环境已安装版本一致的 dconf Editor 和 dconf CLI。linuxdeploy 部署依赖并通过 GTK 插件生成中间 AppImage，公共封装入口再调用官方 appimagetool 和 Type 2 runtime 生成最终产物。

AppImage 继续内置简体中文 locale、dconf GSettings backend 和 Fcitx5 GTK3 输入模块，并使用宿主 dconf 数据库及 D-Bus 会话。专属处理、保留理由及验证范围见 [模板差异](./docs/template-deviations.md)。

## 运行

```bash
./dist/dconf-editor.AppImage
```

需要 CLI 时可将同一 AppImage 建立名为 `dconf` 的软链接，由现有 AppRun 按 ARGV0 分派。

## 版本元数据

构建脚本保留 45.0.1 版本基线。公共 APT 解包入口返回实际主包版本，公共封装入口将它写入 `dist/version.txt`。GitHub Actions 在构建脚本成功退出后直接使用该文件上传版本元数据和更新发布清单。

## 变更记录

### 2026-10-30：安装 rsvg-convert

- 故障依据：[Actions run 41022743379](https://github.com/newyorkthink/linux-packaging/actions/runs/41022743379) 的 Build dconf Editor。日志原文：`错误：没有可用的 SVG 转 PNG 工具，需要 rsvg-convert、magick 或 convert。` 已安装的是 `librsvg2-2` 和 `librsvg2-common`，没有 `rsvg-convert`。
- 处理：安装列表增加 `librsvg2-bin`。原 appimagetool 命令未改。
- 验证范围：只做了 `bash -n`。这次构建结果尚未验证。

### 2026-10-30：补齐 appimagetool 要求的 PNG 图标

- 故障依据：[Actions run 41010671616](https://github.com/newyorkthink/linux-packaging/actions/runs/41010671616) 的 Build dconf Editor。appimagetool continuous build 333（git `b082d2e`，2026-10-29）报根目录没有 `ca.desrt.dconf-editor.png`，`.DirIcon` 无效，退出码 1。发行版图标是 SVG。
- 处理：封装前调用 `common/appimage/prepare_appdir_for_appimagetool.sh`。原命令仍是 `"$APPIMAGETOOL" --no-appstream --runtime-file "$RUNTIME" "$APPDIR" "$OUTPUT_FILE"`。AppRun 未改。
- 验证范围：公共脚本做过语法检查和临时目录检查。没有重打 dconf Editor，没有重跑 Actions。构建环境需要 `rsvg-convert`、`magick` 或 `convert` 才能把 SVG 转成 PNG；本次没有在正式构建里确认该工具是否已安装。

### 2026-09-16：接入统一软件版本元数据

仅在正式 workflow 中增加版本文件生成、artifact 上传与统一 `software_versions.json` 映射；现有 Ubuntu、GLIBC、中文 locale、Fcitx5、dconf backend 和固定打包工具基线均保持不变。

### 2026-09-29：改为动态工具摘要并处理 continuous 更新竞态

- 现象：Build dconf Editor Job `109289404260` 下载 `runtime-x86_64` 后在 SHA-256 校验阶段失败；下载本身已经完成，因此普通 curl 网络重试不会处理这类错误。
- 根因：dconf Editor 项目脚本直接使用 `continuous/runtime-x86_64` 可变资产，同时把旧 SHA-256 写死在项目内；上游 continuous 资产更新后，下载内容已经变化，但项目仍按旧摘要校验。项目内还重复维护了 linuxdeploy、appimagetool 和 runtime 的下载逻辑，没有复用仓库现有公共入口。
- 修复：删除项目内三项工具的固定 URL / SHA 与重复 curl 逻辑，统一调用 `common/linuxdeploy/prepare_linuxdeploy_tools.sh` 动态解析官方 continuous Release 的资产 URL 和当前 digest。公共入口同时把“重新获取 Release 元数据 → 下载资产 → 按当前 digest 校验”作为一个整体最多重试 3 次，用于处理 continuous 资产替换期间的短暂元数据 / CDN 错配；SHA-256 校验继续保留，不固定旧版本。
- 验证边界：本次只修改 dconf Editor 项目脚本、公共 linuxdeploy 工具准备脚本和本 README；不修改 workflow，不手动触发或重跑 Actions。正式构建结果以后续正常 workflow 为准。
