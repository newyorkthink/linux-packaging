# Cursor 写死的路径

## `/usr/share/pixmaps/co.anysphere.cursor.png`

- 为什么写死：构建脚本已安装 AUR `cursor-bin`；该包保留官方 DEB 的图标布局，按用户本次明确指定直接使用安装结果，不再把图标复制到脚本目录。
- 写死的内容：`/usr/share/pixmaps/co.anysphere.cursor.png`
- 作用：作为 `ICON` 交给 quick-sharun，由工具将图标放进 AppImage。
- 当初报错：没有。本次是用户指定的资源来源调整，没有对应的运行报错或日志，不虚构故障记录。

## `/usr/share/applications/cursor.desktop`

- 为什么写死：构建脚本已安装 AUR `cursor-bin`；该包保留官方 DEB 的 desktop 布局，按用户本次明确指定直接使用安装结果，不再复制并改写本地 desktop。
- 写死的内容：`/usr/share/applications/cursor.desktop`
- 作用：作为 `DESKTOP` 交给 quick-sharun；原有 `X-AppImage-Version` 检查和缺失时追加版本的逻辑也使用同一个 `DESKTOP` 路径，保留上游的 `Exec`、`Icon` 和 Desktop Actions 参数。
- 当初报错：没有。本次是用户指定的资源来源调整，没有对应的运行报错或日志，不虚构故障记录。

## 依据与适用范围

AUR `cursor-bin` 的 `PKGBUILD` 从官方 DEB 提取文件时，只排除 `usr/share/cursor/` 中由系统 Electron 替代的部分程序文件，没有排除或改写 `usr/share/applications/` 与 `usr/share/pixmaps/` 中的资源。配方可从 [Arch Linux AUR 镜像](https://github.com/archlinux/aur/blob/cursor-bin/PKGBUILD) 核对。

上述路径只在 CI 构建环境中读取或用于补充版本字段，最终程序仍取自另行下载的官方 DEB。本次不将 AUR 安装的程序文件替换进 `AppDir/bin`，也不改动官方程序。

## `MAIN_BIN=cursor`

- 为什么写死：按用户要求，与 WorkBuddy 使用相同的显式主程序设置。官方 DEB 的主程序文件名为 `cursor`，复制完整程序目录后，入口位于 `AppDir/bin/cursor`。
- 写死的内容：`MAIN_BIN=cursor`
- 作用：告诉 quick-sharun 使用 `cursor` 作为主程序，替代未设置 `MAIN_BIN` 时从 desktop 的 `Exec` 字段推导文件名的默认行为。
- 当初报错：没有。本次是用户要求的模板对齐，此前脚本使用 quick-sharun 的默认入口推导逻辑，没有对应的运行报错或日志。
