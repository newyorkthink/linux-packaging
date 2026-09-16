# Tencent Docs

将腾讯文档官方 Linux Debian 包封装为 AppImage。

- 上游包：`https://docs.qq.com/api/package/get?channel_id=30001&version_id=latest&package_name=TencentDocs-x64.deb`
- 保留官方 `/opt/腾讯文档` Electron 运行时及 resources（含 app.asar 和原生模块）
- 不替换上游 Electron，不修改 app.asar
- 仅补齐 AppImage 运行时依赖和入口
- 产物：`tencent-docs.AppImage`
- 统一构建入口：`.github/workflows/build.yml`

## 统一软件版本元数据

### 2026-09-16：接入 `software_versions.json`

- 修改文件：`.github/workflows/build.yml`、本 README。
- 版本来源：`tencent-docs-version.txt` 中的 `version=`，由共享 workflow 步骤标准化为 `dist/version.txt`。
- 成功构建后上传 `software-version-tencent-docs` 元数据 artifact；汇总 Job 仅在对应构建成功后更新 `latest` Release 中的 `software_versions.json`。
- `software_versions.json` 使用版本号判断是否需要更新，Release SHA-256 仅用于文件完整性与本地状态；相同版本的重复构建不会仅因 SHA-256 改变而触发客户端更新。
- 本次不改应用打包、运行时、补丁和 Release 资产名；提交后按仓库规则不主动监控 Actions，实际新清单记录以下一次成功构建结果为准。
