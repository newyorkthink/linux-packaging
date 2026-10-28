# quick-sharun 说明

这里记录已经核对过的 quick-sharun 行为，避免以后再判错。

新的结论往下面追加，不要另开一篇，也不要改掉旧条目让它看起来从未错过。具体应用的脚本和验收记录不写在这里。

## 不会自动加更新 hook

quick-sharun 不会自动加入更新 hook。

只有构建脚本自己把 `self-updater.hook` 写进 `ADD_HOOKS`，才会加入。仓库标准写法里没有这行，也没有 `unset ADD_HOOKS`、`unset UPINFO`、`unset GITHUB_REPOSITORY`。

GitHub Actions 自带的仓库名不会让 quick-sharun 自动加上更新 hook。

错误判定：曾认为打包时会因为这个仓库名自动写上更新，所以脚本里要取消那三个变量。这个判定是错的。不要为此在脚本里加这三行。
