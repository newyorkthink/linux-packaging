# Cursor 写死的路径

本文记录当前构建使用的固定路径和参数。实际软件版本由公共入口动态读取。

## `/usr/share/cursor`

- 为什么写死：官方 DEB 在这个目录保存完整程序和相邻资源，构建脚本保持该布局。
- 写死的内容：`cursor-unpacked/usr/share/cursor/`
- 作用：把目录中的全部内容原样复制到 `AppDir/bin`。
- 当初报错：没有。这是官方安装包的程序目录，不是扫描失败后增加的兼容路径。

## `/usr/share/pixmaps/co.anysphere.cursor.png`

- 为什么写死：已安装的 AUR `cursor-bin` 保留官方 DEB 的图标布局，直接使用安装结果。
- 写死的内容：`/usr/share/pixmaps/co.anysphere.cursor.png`
- 作用：作为 `ICON` 交给 quick-sharun，由工具将图标放进 AppImage。
- 当初报错：没有。这是包装使用的资源路径。

## `/usr/share/applications/cursor.desktop`

- 为什么写死：已安装的 AUR `cursor-bin` 保留官方 DEB 的 desktop 布局，直接使用安装结果。
- 写死的内容：`/usr/share/applications/cursor.desktop`
- 作用：作为 `DESKTOP` 交给 quick-sharun，并通过公共版本入口的 `--desktop` 参数保留缺少 `X-AppImage-Version` 时追加版本的处理。上游 `Exec`、`Icon` 和 Desktop Actions 参数保持原样。
- 当初报错：没有。这是包装使用的资源路径。

## `MAIN_BIN=cursor`

- 为什么写死：官方主程序的文件名为 `cursor`，与 desktop 和完整程序目录对应。
- 写死的内容：`MAIN_BIN=cursor`
- 作用：显式指定 quick-sharun 的主程序入口 `AppDir/bin/cursor`。
- 当初报错：没有。这是当前标准模板的显式入口设置。

## 版本读取参数

- 为什么写死：当前官方程序在 `resources/app/package.json` 的根对象中保存版本；原有构建还需要 `~/version` 和 desktop 版本字段。
- 写死的内容：`package-json AppDir/bin/resources/app/package.json --version-file "$HOME/version" --desktop "$DESKTOP"`
- 作用：通过 `common/build/read_app_version.sh` 返回实际版本，并在原有位置保留两项构建元数据处理。`~/version` 位于 CI 的构建 HOME 中。
- 当初报错：没有。本次是公共入口替换，版本来源和元数据用途保持不变。

## `/usr/bin/hostname`

- 为什么写死：既有构建脚本将该运行命令作为 quick-sharun 输入显式部署。
- 写死的内容：`/usr/bin/hostname`
- 作用：让 AppImage 携带原有构建已要求的运行命令。
- 当初报错：未提供对应的原始报错；本次保留既有参数。

## 依据与适用范围

AUR `cursor-bin` 的 [PKGBUILD](https://github.com/archlinux/aur/blob/cursor-bin/PKGBUILD) 从官方 DEB 提取资源时，没有排除或改写 `usr/share/applications/` 与 `usr/share/pixmaps/`。上述路径用于 CI 构建；最终程序仍取自另行下载的官方 DEB。
