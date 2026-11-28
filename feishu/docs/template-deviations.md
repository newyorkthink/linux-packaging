# Feishu 模板差异

Feishu 采用 Arch Linux x86_64 和 `quick-sharun`。现有 [Electron DEB 模板](../../Templates/quick-sharun/electron-deb.sh) 通过 `download_deb_source.sh` 从 AUR 来源取包并从 `package.json` 读取版本；Feishu 由官方 Linux API 动态返回下载链接与版本摘要，因此沿用标准公共阶段，下载与版本读取接入公共 JSON DEB 入口，并按实际官方包布局调整。

| 构建阶段 | 专属处理与依据 |
| --- | --- |
| 安装与来源 | 公共 Arch 安装入口先安装 AUR `feishu-bin`、DEB 解包工具及 GTK3/Fcitx5/托盘/音频等运行依赖；随后调用 `Common/download/download_json_deb_asset.sh` 从官方 `package_info` JSON 接口独立下载 DEB，校验路径正则、MD5 摘要、包名 `bytedance-feishu-stable` 与架构 `amd64`，并输出源版本至 `work/source-version.txt`。 [构建位置](../build_feishu.sh#L11-L21) |
| 程序与桌面资源 | 将 `opt/bytedance/feishu` 完整复制到 `AppDir/bin/`；若存在 `chrome-sandbox` 则改为 `0755` 清除 setuid 位。从同一份 DEB 复制 `bytedance-feishu.desktop` 与 `product_logo_256.png`，调整 `Exec=bytedance-feishu %U`、`Icon=bytedance-feishu` 后执行 `desktop-file-validate`。 [布局与权限](../build_feishu.sh#L24-L32) · [桌面与图标](../build_feishu.sh#L35-L38) |
| 运行依赖 | 在同一次 `quick-sharun` 调用中收集 `AppDir/bin/*`、`hostname`、NSS、GTK 输入模块以及 `libappindicator3`、`libdbusmenu-gtk3` 系统托盘库，保留 `DEPLOY_GTK=1`、`DEPLOY_OPENGL=1`、`DEPLOY_VULKAN=1`、`DEPLOY_PIPEWIRE=1`、`STRACE_MODE=0` 和 `NO_STRIP=1`。 [部署选项](../build_feishu.sh#L57-L59) · [依赖收集](../build_feishu.sh#L68) |
| 启动与版本 | 版本通过 `read_app_version.sh` 读取 `work/source-version.txt` 并在缺少 `X-AppImage-Version` 时写入 desktop 副本。`.env` 固定 `zh_CN.UTF-8` locale、`SHARUN_EXTRA_LIBRARY_PATH` 与 `SHARUN_WORKING_DIR=${SHARUN_DIR}/bin`（替代自写 `AppRun.sh`），封装完成后由 `save_appimage_version.sh` 写出 `dist/version.txt`。 [版本读取](../build_feishu.sh#L62) · [启动与封装](../build_feishu.sh#L82-L91) |

相关路径及参数见 [固定配置](./hardcoded.md)，应用说明见 [README](../README.md)。
