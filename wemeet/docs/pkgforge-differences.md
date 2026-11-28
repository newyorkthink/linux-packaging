# 腾讯会议上游打包差异

核对仓库 `pkgforge-dev/weemeet-AppImage` 的 `4fe291109b41c60a8e4c366473c7e86430ad387c`。其 [构建工作流](https://github.com/pkgforge-dev/weemeet-AppImage/blob/4fe291109b41c60a8e4c366473c7e86430ad387c/.github/workflows/appimage.yml#L20-L28)在 Arch 容器安装依赖并交给 quick-sharun 封装。

| 处理 | 决定 | 对应代码 | 当前依据、用途与影响 |
| --- | --- | --- | --- |
| AUR 安装、离线 DEB 替代和版本回退 | 未启用 | [依赖脚本](https://github.com/pkgforge-dev/weemeet-AppImage/blob/4fe291109b41c60a8e4c366473c7e86430ad387c/get-dependencies.sh#L20-L40) · [版本段](https://github.com/pkgforge-dev/weemeet-AppImage/blob/4fe291109b41c60a8e4c366473c7e86430ad387c/make-appimage.sh#L5-L12)。本仓库使用[官网 JSON 入口](../build_wemeet.sh#L38)。 | 上游注明本地 DEB 可避开特定网络下的 CDN 阻断。本项目每次从官网取得版本和资产，对安装及解包使用同一份文件。 |
| 私有 Qt、路径映射、模块与预加载 | 未启用 | [映射及收集](https://github.com/pkgforge-dev/weemeet-AppImage/blob/4fe291109b41c60a8e4c366473c7e86430ad387c/make-appimage.sh#L40-L99)。本仓库使用 [Qt5 扫描](../build_wemeet.sh#L141)及[包内程序](../build_wemeet.sh#L115)。 | 上游注明应用自带 Qt 和 QtWebEngine，也说明部署时的私有库查找、模块收集与预加载方式。本项目保留官方 `opt/wemeet` 布局，继续使用已实测的 linuxdeploy 路径。 |
| sharun 启动环境与额外 hook | 未启用 | [Hook 与更新设置](https://github.com/pkgforge-dev/weemeet-AppImage/blob/4fe291109b41c60a8e4c366473c7e86430ad387c/make-appimage.sh#L28-L37) · [运行环境](https://github.com/pkgforge-dev/weemeet-AppImage/blob/4fe291109b41c60a8e4c366473c7e86430ad387c/make-appimage.sh#L67-L83)。本仓库沿用 [根 AppRun](../build_wemeet.sh#L82)。 | 上游将 XWayland 等参数写入 sharun 的 `.env`，对该段具体取值未说明原因。当前保留旧 AppRun 按会话类型执行回退，并由 Qt 插件自动处理实际生成的 hook。 |
| 构建内短时运行检查 | 未启用 | [上游检查](https://github.com/pkgforge-dev/weemeet-AppImage/blob/4fe291109b41c60a8e4c366473c7e86430ad387c/make-appimage.sh#L107-L111)。 | 上游注释说明其用于 CI 环境的解包执行回退。本项目由公共 appimagetool 入口生成发布资产，并保留已有实机结果。 |

## 相关上游原文

来源与版本。

```sh
export PRE_BUILD_CMDS='for f in ../*.deb ../wemeet*.deb ../*TencentMeeting*.deb /tmp/*.deb /tmp/wemeet*.deb /tmp/*TencentMeeting*.deb; do [ -f "$f" ] && echo "Using local deb: $f" && cp -fv "$f" ./wemeet-3.26.10.401-'"$ARCH"'.deb && break; done || true'
$MAKE_AUR_PKG_BIN wemeet-bin
VERSION=$(pacman -Q wemeet-bin 2>/dev/null | awk '{print $2; exit}')
if [ -z "${VERSION:-}" ] && [ -f ~/version ]; then
	VERSION=$(cat ~/version)
fi
VERSION="${VERSION:-3.26.10.401}"
```

运行策略、库预加载与构建内检查。

```sh
export ADD_HOOKS="self-updater.hook:fix-namespaces.hook"
# Wemeet bundles its own private Qt and QtWebEngine (like Viber-AppImage-Enhanced)
export DEPLOY_QT=0
export DEPLOY_QML=0
export DEPLOY_QT_WEB_ENGINE=0

# Allow ldd to resolve wemeet's private libraries during deployment
export LD_LIBRARY_PATH="/usr/lib/wemeet:${LD_LIBRARY_PATH:-}"

# Map hardcoded wemeet library and binary directories
export PATH_MAPPING='
	/usr/lib/wemeet:${SHARUN_DIR}/lib/wemeet
	/opt/wemeet/bin:${SHARUN_DIR}/bin
'
cat << 'EOF' >> ./AppDir/.env
QT_AUTO_SCREEN_SCALE_FACTOR=1
QT_STYLE_OVERRIDE=fusion
IBUS_USE_PORTAL=1
QT_QPA_PLATFORM=xcb
XDG_SESSION_TYPE=x11
WEMEET_XWAYLAND=1
unset WAYLAND_DISPLAY
EOF

# Everything in lib/sharun-preload is preloaded by sharun automatically
mkdir -p ./AppDir/lib/sharun-preload
if [ -f /usr/lib/wemeet/libwemeetwrap.so ]; then
	cp -fv /usr/lib/wemeet/libwemeetwrap.so ./AppDir/lib/sharun-preload/
fi
# Test the AppImage (fallback to extract-and-run in CI environments without unprivileged userns/FUSE)
if [ -n "${CI:-}" ] || [ "${RUN_TEST:-0}" = "1" ]; then
	export APPIMAGE_EXTRACT_AND_RUN=1
	quick-sharun --simple-test ./dist/*.AppImage
fi
```

实际启用的 Qt5、官网 DEB 和启动环境见[专属差异](./template-deviations.md)。
