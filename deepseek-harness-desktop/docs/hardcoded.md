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

## 官方 extra 的 simdjson

- 为什么写死：构建安装的 nodejs 26.12.1-2 需要 `libsimdjson.so.34`。镜像按软件包名安装的 `simdjson 1:5.0.8-1` 只提供 `libsimdjson.so.35`。
- 写死的内容：`https://archlinux.org/packages/extra/x86_64/simdjson/download/`
- 作用：用官方 extra 当前提供 `libsimdjson.so.34` 的 simdjson 换掉镜像里的那一版，再编译 AUR 包。
- 当初报错全文：

```text
.../esbuild@0.28.2/node_modules/esbuild postinstall: node: error while loading shared libraries: libsimdjson.so.34: cannot open shared object file: No such file or directory
.../node_modules/lefthook postinstall: node: error while loading shared libraries: libsimdjson.so.34: cannot open shared object file: No such file or directory
.../esbuild@0.28.1/node_modules/esbuild postinstall: node: error while loading shared libraries: libsimdjson.so.34: cannot open shared object file: No such file or directory
==> ERROR: A failure occurred in build().
 -> error making: deepseek-harness-desktop-exit status 4
```

当时镜像已经安装 `simdjson 1:5.0.8-1`，构建是 [40829950983](https://github.com/newyorkthink/linux-packaging/actions/runs/40829950983)。
