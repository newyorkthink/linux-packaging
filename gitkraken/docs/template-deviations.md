# GitKraken 模板差异

构建脚本沿用 [GTK DEB 模板](../../templates/appimage/linuxdeploy-gtk-deb.sh) 的公共阶段。官网 DEB 来源和私有程序目录参考 [WeChat](../../wechat/build_wechat.sh)，Electron 原生模块补库参考 [Binance](../../binance/build_binance.sh)。

| 阶段 | 专属处理与依据 |
| --- | --- |
| 来源与版本 | 使用 GitKraken 官方 `production/linux/x64/active` 的 AMD64 DEB。公共入口核对 `Package=gitkraken` 和 `Architecture=amd64`，安装并按原布局解包同一文件，返回完整 control `Version`。构建日志记录源文件 SHA-256。 |
| 桌面资源 | DEB 提供一个主桌面入口和两个隐藏的 URI 入口，部署时明确选择 `gitkraken.desktop`。主入口使用 `Exec=gitkraken %U` 和 `Icon=gitkraken`，两个 URI desktop 保留在包内。将 `usr/bin/gitkraken` 的绝对链接改为指向官方 CLI launcher 的相对链接。 |
| AppRun | 保留完整 `usr/share/gitkraken` 目录、相邻 `libffmpeg.so`、应用资源和官方 `chrome-sandbox` 文件。AppRun 将真实程序目录加入库搜索路径，直接执行主 ELF。 |
| 依赖 | 对真实程序和 `chrome_crashpad_handler` 使用 `--deploy-deps-only`。显式部署 `libssl.so.3`、`libgssapi_krb5.so.2` 和 `libxkbfile.so.1`，由 linuxdeploy 继续收集传递依赖。包内 `*.node` 保留原布局，依赖扫描仅选已确认的 ELF 和库。 |
| NSS/NSPR | 用户实测启动因包内 `libnssutil3.so` 与宿主 `libsoftokn3.so` 的符号版本不匹配而退出。显式安装 `libnss3` 和 `libnspr4`，在 linuxdeploy 结束后调用 `copy_nss_runtime.sh` 将同一构建环境的 NSS、动态模块、`.chk` 和 NSPR 部署到 `AppDir/usr/lib`。放在最终封装前可保留模块原始字节。 |
| 主题与输入法 | GTK3 插件部署桌面运行资源并按宿主浅色或深色偏好选择 Adwaita 变体。Ubuntu 24.04 的 `gtk-query-immodules-3.0` 位于 `libgtk-3-0t64` 私有目录，构建调用临时补充 `PATH`，以便生成 IBus/Fcitx5 缓存。 |
| 中文环境 | 公共入口在 AppDir 内生成 `zh_CN.UTF-8`，AppRun 设置 `LOCPATH`、`LANG`、`LANGUAGE`。GTK 输入法沿用宿主会话的选择。 |
| 封装与发布 | Ubuntu 24.04 独立任务继续使用 `gitkraken.AppImage` 和 `gitkraken` 软件键，沿用按分页列表精确匹配资产名的发布方式。公共封装入口使用 Type 2 runtime，输出最终 SHA-256，并写入 `dist/version.txt`。 |

## 核对依据

- 官方下载说明给出稳定 AMD64 DEB 的下载入口。静态检查样本 DEB 中的 `usr/share/gitkraken/gitkraken` 确认其通过 `$ORIGIN` 定位相邻的 `libffmpeg.so`。NodeGit 链接 OpenSSL 3 和 Kerberos，`native-keymap` 链接 `libxkbfile.so.1`。 [GitKraken 官方下载说明](https://help.gitkraken.com/gitkraken-desktop/windows-subsystem-for-linux/)
- linuxdeploy 的默认扫描范围以 `usr/bin` 和 `usr/lib` 为主，并跳过入口软链接。显式扫描可在原位置部署依赖，保持 Electron 资源相邻。旧 quick-sharun 将部分 `*.node` 包装后无法启动的记录见 [README](../README.md#2026-09-02修复-gitkraken-node-原生模块被-quick-sharun-wrapper-替换)。 [linuxdeploy 扫描实现](https://github.com/linuxdeploy/linuxdeploy/blob/07333c6e942c7d71782b66be924c5d867f9dfdfc/src/core/appdir.cpp#L793)
- 公共封装准备步骤统一清除 setuid 位。GitKraken 的普通启动参数保持上游行为，沙箱和图形运行的实际验收范围见 [README](../README.md#验证)。 [公共封装准备](../../common/appimage/prepare_appdir_for_appimagetool.sh#L30)
