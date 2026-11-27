# QQ AppImage

## 用途与产物

本目录同步腾讯官方 Linux QQ x86_64 AppImage，并以稳定资产名 `qq.AppImage` 发布。正式构建入口为 `.github/workflows/build.yml` 通过 `.github/appimage-apps.json` 调度的标准 matrix Job。

## 技术栈

- 上游：腾讯 QQ NT，Electron / Chromium 桌面客户端。
- 包格式：官方 `QQ_*_x86_64_01.AppImage`。
- 目标架构：x86_64。
- 本仓库不二次封装、不补运行库、不改启动参数。

## 打包方式

当前路线是「官方 AppImage 原样同步」，不用 quick-sharun、linuxdeploy 或 appimagetool 重打包。

1. 公共入口优先使用 `linuxqq-appimage` 配方中的下载地址和 SHA-256。配方来源不可用时，按顺序查询腾讯官方下载配置，从 x86_64 AppImage 文件名提取版本号和构建日期，并与已校验清单中的完整版本核对。首个配置请求失败、链接无效或版本不匹配时，尝试备用接口。两个接口均无匹配版本时停止。
2. 公共入口通过腾讯 `UrlSign` 取得签名地址并下载。使用腾讯配置取包时，必须有本仓库 `latest` 中同版本 `qq.AppImage` 的已发布摘要，且与版本清单一致。SHA-256 校验通过后原样写入 `qq/dist/qq.AppImage`。
3. 公共产物收尾入口设置执行权限，并将本次版本写入 `dist/version.txt`。

不再从官方 DEB 用 Arch 库重封。该路线会把构建容器里的 Fontconfig / GTK / Glycin 打进包，在滚动发行版上与宿主缓存冲突，实机窗口全黑卡住；官方安装包和官方 AppImage 都不走这条路径。

## 运行与兼容说明

下载 Release 中的 `qq.AppImage` 后赋予执行权限并直接运行：

```bash
./qq.AppImage
```

运行行为、sandbox、输入法和图形栈均保持官方 AppImage 原状。宿主需要能跑腾讯官方 Linux QQ AppImage（通常需要 FUSE）。

## 版本元数据

构建脚本在校验官方 AppImage 之后写入 `qq/dist/version.txt`。workflow 按统一约定上传并写入 `latest/software_versions.json`。

## 维护说明

- 腾讯下载配置提供备用取链。新版本在取得对应的可信摘要后才可下载并发布。
- 最终 Release 资产名固定为 `qq.AppImage`。
- 官方 AppImage 没有已确认需要修复的内容时，不得再拆包重封装。

## 修复记录

### 2026-09-18：改为官方 AppImage 原样同步

- 现象：仓库重打包的 `qq.AppImage` 启动后窗口全黑卡住；官方 QQ 不卡。preload 成功。日志有 `Glycin running without sandbox`、`StartTransientUnit` 对 `org.chromium.Chromium-*.scope` 失败，以及 Fontconfig 缓存由更新版本生成（宿主 `0x20120003`，包内 `0x20110001`）。
- 根因：从官方 DEB 用 Arch 容器 + quick-sharun 收集 GTK / Fontconfig / Glycin 后二次封装。包内旧 Fontconfig 读到宿主新缓存，Electron 再与宿主 Chromium systemd scope 撞名。官方 deb/AppImage 使用官方自己的运行库，不复现。
- 修改文件：`qq/build_qq.sh`、`qq/README.md`。
- 处理：改为同步腾讯官方 x86_64 AppImage，校验 SHA-256 后以 `qq.AppImage` 发布。不再使用 quick-sharun / linuxdeploy。
- 已知结果：2026-09-18 实机确认官方同步的 `qq.AppImage` 可打开会话列表，不再黑屏卡住。终端里 `StartTransientUnit` / `GLib-GObject` / `linux-bugly` 日志仍会出现，与官方一致，不影响窗口。

### 2026-09-18：AppImage 启动后黑屏卡住

- 现象：同上。当时仍走 DEB + quick-sharun。
- 处理：去掉 `gjs` / `openjpeg2` / `openslide`，启动加上 `--no-sandbox --disable-setuid-sandbox --ozone-platform-hint=x11 --disable-features=SystemdCgroup`。
- 已知结果：新包仍黑屏，Fontconfig 版本冲突仍在。已被上一条覆盖。

新增打包于 2026-09-17，当时从官方 DEB 重封装，无实机成功记录。
