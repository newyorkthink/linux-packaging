# Joplin AppImage

本目录用于把 Joplin 官方已发布版本中版本号最高的 Linux x64 DEB 重新封装为 `joplin.AppImage`。

## 构建来源

- 构建脚本读取 Joplin 官方 GitHub Releases，忽略 draft，并选择版本号最高且提供 `Joplin-<版本>.deb` 的 Linux x64 版本。
- 下载官方 DEB，并校验 GitHub Release 提供的 SHA-256 digest。
- 保留 Joplin 官方 `/opt/Joplin` 程序、`resources/app.asar`、Node 原生模块、desktop 和图标，不修改官方 `app.asar`。

## 打包

- 构建环境固定为 GitHub Actions `ubuntu-22.04`。
- DEB 直接解包为 `AppDir`，只补一个 `usr/bin/joplin` 启动入口。
- 使用本目录的 `linuxdeploy-plugin-gtk`；该插件保留 GTK 部署逻辑并补齐 GIO modules。
- Electron/NSS 会动态加载 NSS 模块，因此构建时额外把 Ubuntu 的 NSS modules 放入 `AppDir/usr/lib`。
- 最终打包命令固定为：`export ARCH=x86_64; linuxdeploy --appdir AppDir --plugin gtk --output appimage`。
- 不执行 Xvfb / GUI smoke test，不再加入额外的解包、ELF 遍历或图形启动测试。
- 正式构建由 `.github/workflows/build.yml` 中独立的 `Build Joplin` Job 完成，发布文件名固定为 `joplin.AppImage`。
