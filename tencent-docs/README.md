# Tencent Docs

将腾讯文档官方 Linux Debian 包封装为 AppImage。

- 上游包：`https://docs.qq.com/api/package/get?channel_id=30001&version_id=latest&package_name=TencentDocs-x64.deb`
- 保留官方 `/opt/腾讯文档` Electron 运行时及 resources（含 app.asar 和原生模块）
- 不替换上游 Electron，不修改 app.asar
- 仅补齐 AppImage 运行时依赖和入口
- 产物：`tencent-docs.AppImage`
- 统一构建入口：`.github/workflows/build.yml`
