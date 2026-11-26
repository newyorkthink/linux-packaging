# GitKraken AppImage

## 用途与产物

GitKraken Desktop 是基于 Electron / Chromium 的图形化 Git 客户端。本项目使用官方 Linux AMD64 稳定版 DEB，在 Ubuntu 24.04 原生 runner 上重新封装 `gitkraken.AppImage`。

## 构建

统一 [Build AppImages](../.github/workflows/build.yml) 工作流调用 [build_gitkraken.sh](./build_gitkraken.sh)。公共入口下载、核对包名与架构、安装并解包同一份官方 DEB，版本取包内完整的 `Version` 字段。

构建保留 `usr/share/gitkraken` 程序目录以及官方桌面资源。linuxdeploy 显式部署主程序、crashpad 和 Node 原生模块需要的外部库，由 GTK3 插件准备运行资源，再由官方 appimagetool 使用 Type 2 runtime 封装。依赖、启动路径和主题配置见[模板差异](./docs/template-deviations.md)。

构建输出 `dist/gitkraken.AppImage` 和 `dist/version.txt`。原始 DEB 和最终 AppImage 的 SHA-256 由公共入口写入构建日志。成功后将 `gitkraken.AppImage` 上传到 `latest` Release，并更新 `software_versions.json` 的 `gitkraken` 条目。

## 运行

```bash
./gitkraken.AppImage
```

包内提供 `zh_CN.UTF-8` locale 和 GTK3 的 IBus、Fcitx5 输入模块。启动时沿用宿主的语言和输入法设置。宿主选用 `zh_CN.UTF-8` 但缺少对应 locale 时，使用包内数据。GitKraken 界面文字使用官方发行包的资源。

当前 GTK 插件生成启动钩子，linuxdeploy 生成的顶层 `AppRun` 加载钩子后执行 `AppRun.wrapped`。应用入口将原生 GTK 菜单默认设为 `Adwaita:dark`，显式设置的 `APPIMAGE_GTK_THEME` 优先。主界面主题由 GitKraken 的应用设置决定。

## 验证

- 静态核对已提供的 AMD64 DEB，确认真实程序、桌面入口、官方图标、crashpad、`libffmpeg.so` 及 Node 原生模块的布局，并读取主程序和原生模块的 ELF 依赖。
- 对照 GTK DEB 模板和仓库既有项目核对公共调用、专属参数、作业入口与发布路径。
- NSS 修复前，已核对用户提供的 AppImage 与当时 `latest` Release 资产的 SHA-256 一致。该产物在普通用户启动时因 NSS 初始化失败而退出。
- 公共封装入口会清除 `chrome-sandbox` 的 setuid 位，普通用户沙箱启动取决于宿主允许的用户命名空间。

## 实机验证

### 2026-11-26：用户实机验证通过

用户已确认 GitKraken `12.7.0` 实机验证通过。

| 实测项目 | 通过结果 |
| --- | --- |
| 窗口启动 | 补齐 NSS/NSPR 的 AppImage 正常打开主窗口。 |
| 中文输入 | 仓库搜索框可以输入中文，输入法候选词正常显示。 |
| 顶部菜单 | 原生 GTK 菜单显示为深色。 |

## 变更记录

### 2026-11-26 调整 GTK 菜单默认配色

实机显示 GitKraken 主界面为深色，顶部原生菜单为浅色。包内 GTK 钩子在未取得桌面配色偏好时回退到 `Adwaita:light`。`build_gitkraken.sh` 在应用入口将菜单默认设为 `Adwaita:dark`，并允许调用方通过 `APPIMAGE_GTK_THEME` 选择主题。

### 2026-11-26 补齐 linuxdeploy 产物的 NSS/NSPR

GitKraken 启动时出现以下致命报错。挂载路径已缩写。

```text
<AppDir>/usr/lib/libnssutil3.so: version `NSSUTIL_3.108' not found (required by /usr/lib/x86_64-linux-gnu/libsoftokn3.so)
FATAL:crypto/nss_util.cc:146] nss_error=-5925, os_error=0
```

只读核对发布产物发现，包内缺少 `libsoftokn3.so`，`libnssutil3.so` 最高只提供 `NSSUTIL_3.94`。NSS 回退加载宿主的 `libsoftokn3.so` 后遇到符号版本冲突。

构建依赖增加 `libnss3` 与 `libnspr4`。linuxdeploy 完成后，通过公共入口把同一 Ubuntu runner 的 NSS 核心库、动态加载模块、配套 `.chk` 和 NSPR 放入 `AppDir/usr/lib`，随后统一封装。该顺序保留动态模块与 `.chk` 的对应关系。修复版的启动和中文输入结果见[实机验证](#实机验证)。


### 2026-09-02：首次加入 GitKraken AppImage 与中文环境

- 新增 `gitkraken/build_gitkraken.sh` 和本 README。
- 以 GitKraken 官方 production release 为唯一应用二进制来源，版本动态获取，不锁定当前版本。
- 参照 AUR `gitkraken` 核对官方 tar.gz 布局、GTK3 / NSS / libsecret / libxkbfile 依赖和 `chrome-sandbox` 权限。
- 加入 `LANG=zh_CN.UTF-8`、`LANGUAGE=zh_CN:zh`，并带入 GTK3 的 Fcitx5 / IBus 输入模块；不覆盖宿主输入法选择。
- 明确不注入第三方中文 UI，不修改 GitKraken 授权或订阅逻辑。
- 接入仓库统一 `build.yml`，并增加归档安全、ELF / `ldd`、desktop、最终 AppImage 提取和隔离 Xvfb 冒烟检查。

### 2026-09-02：修复构建环境缺少 hostname

- 故障现象：GitHub Actions 在进入 GitKraken 构建脚本后报 `构建环境缺少命令：hostname`，尚未进入正式 AppImage 封装。
- 根因：脚本需要把 `/usr/bin/hostname` 一并交给 quick-sharun，但 Arch Linux 构建容器中该命令由 `inetutils` 提供，原依赖列表没有安装该包。
- 修改文件：`gitkraken/build_gitkraken.sh`。
- 修复内容：仅在构建依赖中增加 `inetutils`，不改变 GitKraken 下载、中文环境、输入法、sandbox 或打包逻辑。
- 对应提交：`d9a1627dd9c3f5547fecab7aa6216d9e2dd73435`。
- 验证结果：后续 Actions 已通过原 `hostname` 故障点并完成约 269.7 MiB AppImage 的 DwarFS 封装，随后暴露出更靠后的 GTK 输入模块最终校验问题。

### 2026-09-02：修正 GTK 输入模块最终校验并补齐真实 zh_CN locale

- 故障现象：AppImage 已成功完成 DwarFS 封装，但最终提取验证报 `最终 AppImage 缺少 IBus GTK3 输入模块`。
- 根因：Actions 日志已确认 quick-sharun 在打包输入阶段把 `im-ibus.so` 与 `im-fcitx5.so` 部署到 GTK3 immodules 目录；原验证却使用 `find -type f`，只接受普通文件，与 quick-sharun 对共享库原名可保留为指向有效 ELF 的符号链接这一部署语义不一致。
- 同步核实：quick-sharun 对 glibc 默认只保证 `C.UTF-8` 与 `en_US.UTF-8` fallback；此前虽然设置了 `LANG=zh_CN.UTF-8`，但没有显式生成 AppImage 内的 `zh_CN` glibc locale 数据。
- 修改文件：`gitkraken/build_gitkraken.sh`、`gitkraken/README.md`。
- 修复内容：按确定的 GTK3 最终路径使用 `-e` 与 `readelf` 验证 IBus / Fcitx5 module，同时验证 `immodules.cache` 注册项；使用 `localedef --no-archive` 生成 `zh_CN.utf8` 并加入 AnyLinux locale 目录；最终提取后再验证 locale 数据并用 `locale charmap` 确认实际为 `UTF-8`。
- 验证结果：以对应 GitHub Actions 最终运行结果为准；本记录不把尚未完成的 CI 描述为已成功。

### 2026-09-02：修复 GitKraken Node 原生模块被 quick-sharun wrapper 替换

- 故障现象：Actions 构建显示成功，但实际运行 `gitkraken.AppImage` 没有任何 GUI；终端报 `find-git-repositories/build/Release/findGitRepos.node: 无法动态加载位置无关可执行文件`，随后出现 `UnhandledPromiseRejectionWarning`。
- 根因：Run `33616739549` 的完整构建日志已经显示 quick-sharun 把 `findGitRepos.node`、`nodegit.node`、`pty.node`、`nsfw.node` 等 `*.node` 文件识别为 nested executable，并执行 `Wrapped nested bin executable ... with sharun`。Node/Electron 需要通过 `dlopen()` 加载这些原生模块，文件被替换为 sharun executable wrapper 后就会触发该错误。
- 原验证缺陷：同一个 Run 的 Xvfb 日志其实已经出现完全相同的 `findGitRepos.node` 错误，但旧验证只接受进程存活到 25 秒并允许 `timeout` 返回 `124`，致命错误正则也没有覆盖 Node 原生模块 `dlopen()` 失败，因此产生了错误的绿色 CI。
- 修复内容：`*.node` 不再作为 quick-sharun executable 输入；仍对其执行 `ldd`，并把解析到的 AppDir 外部动态库依赖交给 quick-sharun；quick-sharun 前后和最终 AppImage 提取后均逐个比对官方 `*.node` 的 SHA-256 与文件模式。
- GUI 验证增强：新增 `xorg-xwininfo`，Xvfb 测试必须实际检测到 GitKraken X11 顶层窗口；同时显式拦截 `UnhandledPromiseRejectionWarning` 的 `.node` 错误和中英文 `cannot dynamically load position-independent executable` 报错。
- `libva` / VA-API 初始化警告不是此次无界面的根因，因此没有用 `--no-sandbox`、禁用 VA-API 或其他无关参数去掩盖该问题。

## 统一软件版本元数据

### 2026-09-16：接入 `software_versions.json`

- 修改文件：`.github/workflows/build.yml`、本 README。
- 版本来源：构建脚本已有的 `dist/version.txt`，内容来自 GitKraken 官方 production `RELEASES` 元数据。
- 成功构建后上传 `software-version-gitkraken` 元数据 artifact；当前 Build 仅在对应构建成功后更新 `latest` Release 中的 `software_versions.json`。
- `software_versions.json` 使用版本号判断是否需要更新，Release SHA-256 仅用于文件完整性与本地状态；相同版本的重复构建不会仅因 SHA-256 改变而触发客户端更新。
- 本次不改应用打包、运行时、补丁和 Release 资产名；提交后按仓库规则不主动监控 Actions，实际新清单记录以下一次成功构建结果为准。
