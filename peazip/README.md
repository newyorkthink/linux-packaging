# PeaZip AppImage

## 用途与产物

本目录把 PeaZip 官方最新稳定版 Qt6 Linux x86_64 DEB 重新封装为 AppImage。

- 上游项目：<https://github.com/peazip/PeaZip>
- 上游来源：官方 GitHub Release 中的 `peazip_<版本>.LINUX.Qt6-1_amd64.deb`
- 稳定产物名：`peazip.AppImage`
- 构建入口：`peazip/build_peazip.sh`
- 正式 workflow：`.github/workflows/build.yml` 的 `Build PeaZip` 独立 Job

## 当前打包方案

当前固定采用 Ubuntu 24.04 + linuxdeploy + 官方 appimagetool Type 2 路线。

1. 工作区、架构检查、APT 安装、GitHub Release 下载校验、DEB 解包、linuxdeploy 环境和最终 appimagetool 封装均复用仓库 `common/` 公共入口。
2. linuxdeploy、Qt 插件、appimagetool 和 Type 2 runtime 均从各自官方动态来源取得，不固定旧版本。
3. 动态取得 PeaZip 最新正式 Qt6 amd64 DEB；GitHub digest、DEB 包名 `peazip` 和 `amd64` 架构由公共下载入口统一校验。
4. 同一个官方 DEB 同时安装到隔离构建环境并解包到 AppDir，保持上游 `/usr/lib/peazip` 与 `/usr/share/peazip` 布局。
5. `zh-cn.txt` 仅在缺失 UTF-8 BOM 时补入 BOM，不改写上游中文正文。
6. 构建 `peazip_utf8_fix.c` 为 `usr/lib/peazip/libpeazip-utf8-fix.so`，只在 PeaZip 主进程中处理当前 Qt6Pas 字符串边界的可逆 UTF-8 乱码。
7. 完整根 `AppRun` 直接把真实主程序目录 `usr/lib/peazip` 加入 `PATH`，并保留当前已经确认的 XCB、Adwaita Dark、缩放和字体 DPI 设置。
8. 第二次 linuxdeploy 前临时移出官方 `res/bin` 归档后端，完成 Qt6 依赖部署后原样恢复。
9. 最终封装前删除 `usr/bin/peazip` 转发链接，并把 `usr/lib/peazip/res/share` 物化为真实目录副本；最终 SquashFS 不依赖跨层级 `..` 符号链接。
10. linuxdeploy 生成的中间 AppImage 不发布；正式资产始终由 `common/linuxdeploy/package_appimage.sh` 调用官方 appimagetool + Type 2 runtime 生成。

当前第二次 linuxdeploy 命令保持为：

```bash
# 使用已经准备好 AppRun、Qt6 资源和应用文件的 AppDir 完成 Qt 部署与中间封装
export ARCH=x86_64; linuxdeploy --appdir AppDir --plugin qt --output appimage
```

## 稳定约束

- `peazip_utf8_fix.c`、生成 `libpeazip-utf8-fix.so` 的 GCC 命令以及 AppRun 中的 `PEAZIP_ORIGINAL_LD_PRELOAD` / `LD_PRELOAD` 两行属于已经确认有效的同一套中文兼容实现，不得在普通整理或公共化时改写。
- 不重新加入 locale-only 中文修复，不注入 `-peaziplanguage`，不通过额外字体掩盖编码问题。
- 不手工创建 `apprun-hooks`、hook 或 `AppRun.wrapped`；当前官方 Qt 插件未生成 hook 时，完整根 `AppRun` 就是最终入口。
- 官方归档后端必须完整保留；32 位旧后端是否可运行仍取决于宿主的 32 位兼容运行库。
- 最终包不依赖 `usr/bin/peazip` 相对链接；desktop `Exec=peazip` 通过 AppRun 的真实程序目录 `PATH` 解析。

## 已确认状态

2026-09-21 当前正式产物已经完成实际使用确认：

- PeaZip GUI 可正常启动。
- 简体中文界面显示正常，原 UTF-8 乱码已消失。
- 归档测试正常并返回 `Everything is Ok`。
- PeaZip 可直接打开并解压 AppImage，最终包不再出现危险符号链接解压错误。
- RPM 可以正常打开并解出 CPIO payload 及 `etc/`、`usr/`、`var/` 等内容。

设置页左侧导航的点击区域属于上游界面行为，不是 AppImage 打包回归：上游 `peazip-sources/dev/peach.lfm` 中每个导航行由 `TPanel` 承载，但只有 `LabelTitleOptions1..8` 绑定 `OnClick`，对应 Panel 和图标没有点击事件，因此可点击区域集中在文字标签附近。若要改变该行为，需要修改 PeaZip/Lazarus 界面源码并重新编译应用本体，不属于本仓库当前的二进制重打包层。

## 运行

```bash
# 启动 PeaZip
./peazip.AppImage
```
