# Joplin AppImage

本目录用于把 Joplin 官方当前稳定版 Linux x64 DEB 重新封装为 `joplin.AppImage`。

## 构建来源

- 构建脚本通过 Joplin 官方 GitHub Release API 动态读取最新稳定版，不选择 draft 或 prerelease。
- 下载仅接受官方仓库对应 tag 下的 `Joplin-<版本>.deb`，并校验 GitHub 提供的 SHA-256 digest。

## 打包与验证

- 保留官方 Electron 程序、资源、desktop、图标和 Node 原生模块，只补齐 AppImage 便携运行所需依赖。
- 构建时检查 ELF 动态依赖，并验证最终 AppImage 中的主程序、资源和原生模块完整。
- 使用隔离的 HOME、XDG 和 Xvfb 执行图形启动测试，不写入真实用户目录。
- 正式构建由 `.github/workflows/build.yml` 中独立的 `Build Joplin` Job 完成，发布文件名固定为 `joplin.AppImage`。
