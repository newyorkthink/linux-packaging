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
