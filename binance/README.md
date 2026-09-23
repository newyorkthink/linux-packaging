# Binance AppImage

本目录把 Binance 官方桌面客户端的 Linux amd64 DEB 重新封装为 `binance.AppImage`。打包只处理启动路径、GTK / NSS / 动态库部署，不修改官方 `app.asar`，也不改登录、交易或更新逻辑。

## 用途与产物

- 应用：Binance Desktop，加密货币行情与交易客户端。
- 上游来源：[binance/desktop](https://github.com/binance/desktop) 正式 Release 中的 `binance-<版本>-amd64-linux.deb`。
- 稳定资产名：`binance.AppImage`。
- 版本不写死。`common/github/download_latest_stable_release_asset.sh` 读取最近正式 semver Release，忽略 draft / prerelease，只接受唯一匹配资产，并校验 GitHub SHA-256 digest 和 DEB 包名 `binance`、架构 `amd64`。

## 技术栈

- Electron / Chromium。2026-09-23 核对的官方包 `2.1.0` 把主程序放在 `/opt/Binance/binance`，同时带 `chrome-sandbox`、`resources/app.asar` 和 Linux x64 原生模块。
- 主程序直接链接 GTK 3、NSS、ATK、Cairo、Pango、ALSA、GBM 和 X11。
- `resources/app.asar.unpacked/node_modules/keytar/build/Release/keytar.node` 额外链接 `libsecret-1.so.0`。
- 主程序字符串中按文件名 `dlopen` `libnotify.so`。官方 `Depends` 还列出 `libxss1`、`libxtst6`、`libuuid1`；这几个名字没有出现在主程序 `NEEDED` 或已检索到的 `dlopen` 字符串里，构建环境仍安装它们以保持与官方依赖声明一致，但不额外用 `-l` 强塞。
- 同一包内还有 `windows_process_tree.node`。这是上游自带的 Windows 模块，脚本不删除、不替换。
- `libappindicator` 只在官方 `Recommends` 中出现，主程序和已检查的 Linux 原生模块都没有对应字符串，因此不安装、不追加 `-l`。

## 打包方式

- GitHub Actions 使用独立 Job，运行环境固定为 `ubuntu-22.04`。
- 路线是 linuxdeploy + 官方 GTK 插件，最后由 `appimagetool` 和 Type 2 runtime 封装。不发布 linuxdeploy 中间 AppImage。
- 标准 `source` / `AppDir` / `dist` / `source/tools` 由 `common/linuxdeploy/prepare_build_workspace.sh` 处理。
- 同一份官方 DEB 既安装到构建环境，也按上游布局解包到 `AppDir/opt/Binance`。不制造 `AppDir/usr/bin/binance` 转发脚本。
- 官方 desktop 的 `Exec=/opt/Binance/binance %U` 会在 AppImage 里指向宿主机路径，因此改为 `Exec=binance %U`，`Icon` 保持 `binance`。`MimeType=x-scheme-handler/binance` 原样保留。
- 根 `AppRun` 直接执行 `opt/Binance/binance`。`PATH`、`LD_LIBRARY_PATH`、`XDG_DATA_DIRS` 分别包含 `usr/bin`、`usr/lib`、`usr/share`。`/opt/Binance` 加入程序和库搜索路径，`LD_LIBRARY_PATH` 同时包含已确认存在的 `usr/lib/x86_64-linux-gnu`。
- `copy_nss_runtime.sh` 放入同一套 Ubuntu 22.04 NSS 核心库和 dlopen 模块，避免 AppImage 内 NSS 与宿主机 NSS 混用。
- 第二次 linuxdeploy 使用 `DEPLOY_GTK_VERSION=3`，并精确追加 `-l`：`libsecret-1.so.0`、`libnotify.so`。
- `ibus-gtk3` 只负责把 GTK3 IBus 输入模块带进 AppDir。AppRun 不写 `GTK_IM_MODULE`、`QT_IM_MODULE` 或 `XMODIFIERS`。
- Adwaita 图标和 GTK 主题包通过 `download_and_extract_packages.sh` 按原始布局放进 AppDir。不设置 `GTK_THEME`。
- 2026-09-23 的正式 `binance.AppImage` 已解包确认：当前官方 GTK 插件生成了 `apprun-hooks/linuxdeploy-plugin-gtk.sh`，顶层 `AppRun` 加载该 hook 后执行 `AppRun.wrapped`。构建脚本现在直接写入这份已核对的根 AppRun，不再调用 `normalize_apprun_paths.sh`。脚本仍不手工补 hook。

## 运行

在放有 `binance.AppImage` 的目录执行：

```bash
chmod +x ./binance.AppImage
./binance.AppImage
```

不需要额外后台服务，也不需要 `sudo`。官方 `postinst` 只在内核不支持 user namespace 时把 `chrome-sandbox` 设成 SUID；AppImage 里不能依赖这个 SUID。脚本因此不追加 `--no-sandbox`。这次实机已经能进入已登录界面，没有出现必须加 `--no-sandbox` 的现象。

## 稳定基线

- 不修改官方 `app.asar`，不删除上游 DEB 里的文件，包括 Windows 原生模块 `windows_process_tree.node`。
- 不设置 `GTK_THEME`，不强制输入法环境变量，不追加 `--no-sandbox`。
- 不手工创建 `apprun-hooks` 或 `AppRun.wrapped`。
- 已确认的根 AppRun、GTK3、NSS、`libsecret` 和 `libnotify` 处理视为稳定基线。没有新的实机故障前不改这些路径。
- 正式构建由 `.github/workflows/build.yml` 的 `Build Binance` Job 完成，发布文件名固定为 `binance.AppImage`。

## 检查记录

### 2026-09-23：新增官方 Linux DEB 的 AppImage 包装

- 检查对象：`binance/desktop` tag `v2.1.0` 资产 `binance-2.1.0-amd64-linux.deb`，以及仓库里 Joplin、百度网盘的 linuxdeploy GTK 路线。
- 证据：GitHub Release digest `sha256:8b05ddbeb15f0d40e9554d27a37bb0695ac01da3f96ab5626da2d9fb8cce560c`；`dpkg-deb -I/-c`；主程序和 `keytar.node` 的 `readelf -d`。
- 已确认：包名 `binance`，架构 `amd64`，版本 `2.1.0`，主程序 `./opt/Binance/binance`，desktop 与 512px 图标路径如上。资产名模板 `binance-{version}-amd64-linux.deb` 能对上 `v2.1.0`。
- 当时未确认：Actions 构建是否成功、AppImage 能否打开窗口、登录、中文输入、系统通知、密钥环和沙盒。随后的实机结果见下方记录，本条保留为当时的检查结论。

## 实际运行验证（2026-09-23）

- 用户实机运行当前 Release 的 `binance.AppImage`，主窗口可以打开。界面为简体中文，已登录后的总览和行情列表正常，客户端角标版本为 `2.1.0`。
- 同一资产已解包核对。GitHub Release digest 为 `sha256:86dafbc76f748998bc78f190163cb7e2346286e55363c9c8feee92f4ca4cd8c5`。顶层 `AppRun` 加载 `apprun-hooks/linuxdeploy-plugin-gtk.sh` 后执行 `AppRun.wrapped`。wrapped 中的路径型 export 与最终目录一致，并已原样写回构建脚本。
- 解包结果里有 `im-ibus.so`、`libnss3.so`、`libsoftokn3.so`、`usr/lib/libsecret-1.so.0` 和 `usr/lib/libnotify.so`。
- 仍未单独验证：输入框里的中文输入、系统通知、密钥环写入，以及无 user namespace 时的沙盒提示。没有这些新证据前不改 AppRun。

## 变更记录

### 2026-09-23：固化已确认的 AppRun

实机确认客户端可用后，解包正式 `binance.AppImage`，把 `AppRun.wrapped` 里已经生效的路径型 export 原样写回根 `AppRun`，并删除 `normalize_apprun_paths.sh` 调用。`LD_LIBRARY_PATH` 比初次写入多了实际存在的 `usr/lib/x86_64-linux-gnu`。GTK hook、`--no-sandbox` 和输入法环境变量都没有改。
