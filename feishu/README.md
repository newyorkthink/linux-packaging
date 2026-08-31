# Feishu AppImage

本目录用于把飞书官方当前稳定版 Linux x86_64 DEB 重新封装为 `feishu.AppImage`。

## 构建来源

- 构建脚本通过飞书官方 Linux API 动态读取当前版本、下载地址和校验值，不写死应用版本。
- 下载仅接受飞书官方 CDN 的 x86_64 DEB，并核对文件名、版本、架构和官方 MD5 / SHA-256。

## 打包与验证

- 保留官方飞书程序、资源、desktop 和图标，只补齐 AppImage 便携运行所需依赖。
- 构建时检查全部 ELF 的动态依赖，并验证最终 AppImage 可提取且包含主程序和启动器。
- 使用隔离的 HOME、XDG、D-Bus 和 Xvfb 执行图形启动测试，不写入真实用户目录。
- 正式构建由 `.github/workflows/build.yml` 中独立的 `Build Feishu` Job 完成，发布文件名固定为 `feishu.AppImage`。
