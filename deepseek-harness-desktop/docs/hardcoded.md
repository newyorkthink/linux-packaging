# DeepSeek Harness 桌面版写死的路径

## `/usr/lib/deepseek-harness-desktop`

- 为什么写死：AUR 包把程序装在这个目录。`/usr/bin/deepseek-harness-desktop` 是 shell，不是入口。脚本不在构建时再查询安装位置。
- 写死的内容：`/usr/lib/deepseek-harness-desktop`
- 作用：把这个目录里的全部内容放进 `AppDir/bin`。
- 当初报错：没有。这是包装进去的目录，不是扫描失败后补的路径。

## 内置 Python 的库目录

- 为什么写死：这些库不在系统路径上，quick-sharun 不会自己找到。
- 写死的内容：`AppDir/bin/resources/runtime/primary-runtime/dependencies/python/lib`
- 作用：只在第一次 quick-sharun 扫描时加入 `LD_LIBRARY_PATH`。
- 当初报错：仓库记录写的是，2026-10-07 的构建在扫描 `_tkinter` 时找不到 `libtcl9tk9.0.so` 和 `libtcl9.0.so`，构建中止，未生成 AppImage。当时的 Actions 日志已经取不到。