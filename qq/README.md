# QQ AppImage

## 用途与产物

本目录从腾讯官方 Linux QQ x86_64 DEB 动态取得程序，并重新封装为 `qq.AppImage`。正式构建入口为 `.github/workflows/build.yml` 通过 `.github/appimage-apps.json` 调度的标准 matrix Job。

## 技术栈

- 上游：腾讯 QQ NT，Electron / Chromium 桌面客户端。
- 包格式：官方 `linuxqq_*_amd64.deb`，主程序位于 `/opt/QQ/qq`。
- 目标架构：x86_64。
- 运行时：GTK3、NSS、ALSA，以及 Electron 常见的 X11 / 通知 / 密钥环依赖。

## 打包方式

当前路线与微信、飞书、腾讯文档同类：下载官方 DEB，保留 `/opt/QQ` 相对布局，用 quick-sharun 补齐外部系统库。

1. 读取 AUR `linuxqq` 的 `.SRCINFO`，只取其中当前 `source_x86_64` 官方 DEB 地址和 `sha512sums_x86_64`。AUR 配方本身不作为二进制来源。
2. 下载腾讯 `qqdl.gtimg.cn` 上的 amd64 DEB，并按 AUR 声明的 SHA512 校验。
3. 从 DEB `control` 元数据解析 `Version`，用作 `X-AppImage-Version` 和 `dist/version.txt`。
4. 将 `/opt/QQ` 复制到 `AppDir/bin`，删除官方包内自带的 `libssh2.so.1`（与 AUR linuxqq 相同的已知冲突处理），并把 `chrome-sandbox` 降为普通可执行文件。
5. 使用官方 desktop / 最大尺寸 PNG 图标；`AppRun.sh` 从包内目录启动 `qq --no-sandbox --disable-setuid-sandbox --ozone-platform-hint=x11 --disable-features=SystemdCgroup`。
6. `quick-sharun` 收集主程序外部库后 `--make-appimage`，产物名为 `qq/dist/qq.AppImage`。

未采用“官方 AppImage 原样同步”：腾讯虽然也发布 AppImage，但本仓库对其他腾讯 Electron 客户端一律从官方 DEB 重打包并补齐运行库；QQ 按同一路线处理。

## 运行与兼容说明

下载 Release 中的 `qq.AppImage` 后赋予执行权限并直接运行：

```bash
./qq.AppImage
```

AppImage 无法保留 `chrome-sandbox` 的 setuid，因此启动参数包含 `--no-sandbox --disable-setuid-sandbox`。默认 Ozone 使用 X11，并关掉 Chromium 的 systemd 临时 scope，避免和宿主已有 `org.chromium.Chromium-*.scope` 撞名后黑屏卡住。不打包 `gjs` / `openjpeg2` / `openslide`，避免把 Glycin 图像沙箱带进 Electron 包。

## 版本元数据

构建脚本在最终 AppImage 生成后写入 `qq/dist/version.txt`，内容为本次官方 DEB 的 `Version` 字段。workflow 按统一约定上传并写入 `latest/software_versions.json`。

## 维护说明

- 继续通过 AUR `linuxqq` 动态发现官方 DEB 地址，不在仓库中写死版本号或 CDN 哈希路径。
- 最终 Release 资产名固定为 `qq.AppImage`。
- 不把 AUR 启动器里清理用户配置目录的逻辑带进 AppRun。

## 修复记录

### 2026-09-18：AppImage 启动后黑屏卡住

- 现象：`qq` 能进进程，preload 成功，随后窗口全黑并卡住；官方 deb / 官方包不卡。日志有 `Glycin running without sandbox`，以及 `systemd1.Manager.StartTransientUnit` 对 `app-org.chromium.Chromium-*.scope` 失败（already loaded / fragment file）。Browser LongTask 后无界面。
- 根因：构建依赖误带 `gjs` / `openjpeg2` / `openslide`，quick-sharun 会收集 Glycin；AppImage 里 Glycin 没有 bwrap。Electron 还按通用 Chromium 名字建 systemd scope，和宿主残留单元冲突。官方安装用系统库和自己的单元名，所以不复现。
- 修改文件：`qq/build_qq.sh`、`qq/README.md`。
- 处理：去掉上述 GTK 图像依赖；启动改为 `--no-sandbox --disable-setuid-sandbox --ozone-platform-hint=x11 --disable-features=SystemdCgroup`，并设置 `CHROME_DESKTOP=qq.desktop`。
- 已知结果：已提交构建，实机窗口是否恢复待新 `qq.AppImage` 验证。若仍黑屏，可临时追加 `--disable-gpu` 再试。

尚无更早的构建或运行故障修复。新增打包于 2026-09-17。
