# Antigravity IDE

采用 [Electron 直接下载标准模板](../anylinux_projects.md#直接下载安装包的标准模板)：先在隔离的 Arch 构建环境安装 `antigravity-ide` 和依赖，再从官网下载页独立下载 Linux x64 tar 包，将完整程序目录放入 `AppDir/bin/`。图标和主 desktop 使用已安装包提供的文件，版本取自本次实际下载链接，不用 AUR 版本代替。

保留 OpenGL、Vulkan 和运行时 NSS 模块收集，对应代码逐字复用 [pkgforge-dev 的 make-appimage.sh](https://github.com/pkgforge-dev/Antigravity-IDE-AppImage/blob/d4297876ff865da85f0dff592cc6ab39b51563f0/make-appimage.sh)；保留依据是原构建的图形部署和动态加载依赖范围，官方未说明这些选择的具体原因。没有接入官方自动更新 hook、上游测试启动或精简包安装流程。未加入单独的协议 desktop 收集，也未增加宿主协议登记；仅复制该文件不能实现宿主回调。旧脚本的自定义压缩设置已移除。两份脚本均不强制设置 `DEPLOY_LOCALE=1`，继续按标准模板生成包内中文 locale。

- [构建脚本](build_antigravity-ide.sh)
- [模板差异与依赖覆盖](docs/template-deviations.md)
- [固定配置依据](docs/hardcoded.md)
- [官方处理的采用与不采用记录](docs/pkgforge-differences.md)

本次完成静态检查；没有安装软件、构建 AppImage 或进行应用实机、沙箱和协议回调测试。打包脚本供仓库现有 Arch 构建流程使用，不在 Kali 宿主机直接执行。
