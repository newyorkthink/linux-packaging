# Antigravity

采用 [Electron 直接下载标准模板](../anylinux_projects.md#直接下载安装包的标准模板)：先在隔离的 Arch 构建环境安装 `antigravity` 和依赖，再从官网下载页独立下载 Linux x64 tar 包，将完整程序目录放入 `AppDir/bin/`。图标和主 desktop 使用已安装包提供的文件，版本取自本次实际下载链接，不用 AUR 版本代替。

保留 OpenGL、Vulkan、运行时 NSS 模块及 bwrap 收集，对应代码逐字复用 [pkgforge-dev 的 make-appimage.sh](https://github.com/pkgforge-dev/Antigravity-AppImage/blob/0aebfce24807ec0b6c2388305e604da5102ea4f8/make-appimage.sh)；保留依据是原构建的图形部署和动态加载依赖范围，官方未说明这些选择的具体原因。没有接入官方自动更新 hook、上游测试启动或精简包安装流程。两份脚本均不强制设置 `DEPLOY_LOCALE=1`，继续按标准模板生成包内中文 locale。

- [构建脚本](build_antigravity.sh)
- [模板差异与依赖覆盖](docs/template-deviations.md)
- [固定配置依据](docs/hardcoded.md)
- [官方处理的采用与不采用记录](docs/pkgforge-differences.md)

本次完成静态检查；没有安装软件、构建 AppImage 或进行应用实机、沙箱和协议回调测试。打包脚本供仓库现有 Arch 构建流程使用，不在 Kali 宿主机直接执行。
