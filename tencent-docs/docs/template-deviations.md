# Tencent Docs 模板差异

Tencent Docs 采用 Arch Linux x86_64 和 `quick-sharun`。现有 [Electron DEB 模板](../../Templates/quick-sharun/electron-deb.sh) 通过 `download_deb_source.sh` 从 AUR 来源取包并读取 `package.json` 版本；Tencent Docs 直接经官网 API 取得最新 DEB 并复用官方 DEB 元数据版本，因此沿用标准公共阶段，按实际接口与包内布局调整来源及启动设置。 [腾讯文档下载页](https://docs.qq.com/home/download) · [AUR 配方](https://aur.archlinux.org/packages/tencent-docs-bin)

| 构建阶段 | 专属处理与依据 |
| --- | --- |
| 安装与来源 | 公共 Arch 安装入口先安装 AUR `tencent-docs-bin`、DEB 解包工具及运行依赖；随后调用 `Common/download/download_official_deb.sh`（传入 `--ipv4-fallback`）直接请求腾讯文档官网接口，核对包名 `tdappdesktop` 与架构 `amd64`，并将官方 DEB 版本写入 `work/source-version.txt`。 [构建位置](../build_tencent-docs.sh#L11-L21) |
| 程序与桌面资源 | 将 `opt/腾讯文档` 完整复制到 `AppDir/bin/`，若存在 `chrome-sandbox` 则改为 `0755`，并取消所有 `.node` 原生模块执行位避免被误扫为主入口。从同一份 DEB 复制 `tdappdesktop.desktop` 与 `resources/icon.png`，改写 `Exec=tdappdesktop %U` 与 `Icon=tencent-docs`。 [布局与权限](../build_tencent-docs.sh#L24-L34) · [桌面与图标](../build_tencent-docs.sh#L36-L38) |
| 运行依赖 | 在同一次 `quick-sharun` 调用中收集 `AppDir/bin/*`、`hostname`、NSS 与 GTK 输入模块，保留 `DEPLOY_GTK=1`、`DEPLOY_OPENGL=1`、`DEPLOY_VULKAN=1`、`DEPLOY_PIPEWIRE=1`、`STRACE_MODE=0` 和 `NO_STRIP=1`。 [部署选项](../build_tencent-docs.sh#L57-L59) · [依赖收集](../build_tencent-docs.sh#L68) |
| 启动与版本 | 版本通过 `read_app_version.sh` 读取 `work/source-version.txt` 并在缺少 `X-AppImage-Version` 时写入 desktop 副本。`.env` 固定 `zh_CN.UTF-8` locale、`SHARUN_EXTRA_LIBRARY_PATH` 与 `SHARUN_WORKING_DIR=${SHARUN_DIR}/bin`，通过 `90-tencent-docs-arguments.hook` 传递 `--lang=zh-CN`，封装完成后由 `save_appimage_version.sh` 写出 `dist/version.txt`。 [版本读取](../build_tencent-docs.sh#L62) · [启动与封装](../build_tencent-docs.sh#L82-L96) |

相关路径及参数见 [固定配置](./hardcoded.md)，应用说明见 [README](../README.md)。
