# quick-sharun 说明

这里记录已经核对过的 quick-sharun 行为，避免以后再判错。

新的结论往下面追加，不要另开一篇，也不要改掉旧条目让它看起来从未错过。具体应用的脚本和验收记录不写在这里。

## 不会自动加更新 hook

quick-sharun 不会自动加入更新 hook。

只有构建脚本自己把 `self-updater.hook` 写进 `ADD_HOOKS`，才会加入。仓库标准写法里没有这行，也没有 `unset ADD_HOOKS`、`unset UPINFO`、`unset GITHUB_REPOSITORY`。

GitHub Actions 自带的仓库名不会让 quick-sharun 自动加上更新 hook。

错误判定：曾认为打包时会因为这个仓库名自动写上更新，所以脚本里要取消那三个变量。这个判定是错的。不要为此在脚本里加这三行。

## Qt 主题插件警告

quick-sharun 打入 Qt 后，主题插件没装就会警告。同一次打包里可以连续出现下面三段，正文相同，只有插件名不同：

```text
WARNING: Qt was deployed but there is no kvantum plugin!
This means the application will lack proper theme support!
Install the packages that provide theme support before deploying
In archlinux those are: qt6ct kvantum lxqt-qtplugin

WARNING: Qt was deployed but there is no qtlxqt plugin!
This means the application will lack proper theme support!
Install the packages that provide theme support before deploying
In archlinux those are: qt6ct kvantum lxqt-qtplugin

WARNING: Qt was deployed but there is no qt6ct plugin!
This means the application will lack proper theme support!
Install the packages that provide theme support before deploying
In archlinux those are: qt6ct kvantum lxqt-qtplugin
```

In archlinux those are 后面的三个包名是固定的，不表示三个都缺。实际缺少的是 there is no 后面的那个插件。

安装要求见 [Anylinux / quick-sharun 规范的 Qt 主题插件一节](../../anylinux_projects.md#qt-主题插件)。

## 默认缓存目录 AppImage-Cache

quick-sharun 封装时会自动生成 `AppDir/AppRun.sh` 和 `AppDir/AppRun.lib`。沿用默认 `AppRun.sh` 的 AppImage 在启动时会加载 `AppRun.lib`，将 `XDG_CACHE_HOME` 重定向到 `${XDG_CACHE_HOME:-~/.cache}/AppImage-Cache`（默认即 `~/.cache/AppImage-Cache`），并把宿主原缓存目录下的 `thumbnails` 软链接到 `AppImage-Cache/thumbnails` 以共享缩略图。

这是上游 `pkgforge-dev/Anylinux-AppImages` 在 `useful-tools/quick-sharun.sh` 中统一注入的默认行为，不是本仓库在单个应用构建脚本里写死的。上游这么做主要是避免 AppImage 内置 `fontconfig` 与宿主版本不一致、共用宿主缓存导致字体异常（见上游 issue #657）。

适用范围：使用 quick-sharun 且沿用默认 `AppRun.sh` / `AppRun.lib` 的 AppImage，只要程序或运行库遵守 `XDG_CACHE_HOME`，缓存都会共用这个目录；外部用同一工具打包的 AppImage 也会共用。

不会落入该目录的常见情况：

- 未使用 quick-sharun 的打包路线（如 `linuxdeploy`、直接 `appimagetool`、`electron-builder`、原样同步官方包以及 RunImage）。
- 自定义覆盖了 `AppRun.sh` 且未加载 `AppRun.lib`。
- 程序本身不读取 `XDG_CACHE_HOME`，而是直接写入固定目录（如 `~/.config` 或 `~/.cache` 下的固定子路径）。
- 启用了 AppImage 便携缓存模式（`XDG_CACHE_HOME` 已包含当前 `APPIMAGE` 路径），或启动时显式设置 `USE_HOST_XDG_CACHE_HOME=1`（关闭隔离后可能重新遇到与宿主 `fontconfig` 缓存冲突，默认保持上游行为即可）。
