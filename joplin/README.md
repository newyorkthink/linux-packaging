# Joplin AppImage

本目录用于把 Joplin 官方已发布版本中版本号最高的 Linux x64 DEB 重新封装为 `joplin.AppImage`。

## 构建来源

- 构建脚本读取 Joplin 官方 GitHub Releases，忽略 draft，并在 stable / prerelease 中选择版本号最高且提供 `Joplin-<版本>.deb` 的 Linux x64 版本。
- 这样不会因为 GitHub `releases/latest` 只指向较旧稳定版，而把已经被较新 Joplin 迁移过的用户配置再次交给旧版本读取。
- 下载仅接受官方仓库对应 tag 下的 `Joplin-<版本>.deb`，并校验 GitHub 提供的 SHA-256 digest。

## 打包与验证

- 构建环境固定为 GitHub Actions `ubuntu-22.04`，使用 `linuxdeploy` 生成 AppImage，不再使用 Arch Linux / quick-sharun 路线。
- 保留官方 Electron 主程序、`resources/app.asar`、desktop、图标和 Node 原生模块，只补齐 AppImage 便携运行所需依赖；不修改 Joplin 官方 `app.asar`。
- 构建时检查官方运行目录全部 ELF 的动态依赖，并验证最终 AppImage 中的主程序、资源和原生模块完整。
- 使用隔离的 HOME、XDG 和 Xvfb 执行图形启动测试，不写入真实用户目录；测试会直接拦截 `Invalid layout component:` 等致命启动错误。
- 正式构建由 `.github/workflows/build.yml` 中独立的 `Build Joplin` Job 完成，发布文件名固定为 `joplin.AppImage`。
