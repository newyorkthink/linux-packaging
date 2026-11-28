# Tencent Docs

将腾讯文档官方 Linux x86_64 Debian 包封装为 `tencent-docs.AppImage`。

## 构建来源

- 上游接口：`https://docs.qq.com/api/package/get?channel_id=30001&version_id=latest&package_name=TencentDocs-x64.deb`
- 构建阶段先通过公共 Arch 入口安装 `tencent-docs-bin`、DEB 解包工具及图形/音频依赖，再由 `Common/download/download_official_deb.sh`（开启 `--ipv4-fallback`）独立下载官网当前 DEB、核对包名 `tdappdesktop` 与架构 `amd64`，并记录版本至 `work/source-version.txt`。
- 解包后保留 `/opt/腾讯文档` 完整程序目录与 `resources/icon.png`，清除 `chrome-sandbox` setuid 位并取消 `.node` 模块执行位；不替换上游 Electron，也不修改 `app.asar`。

## 打包与运行

- 采用 Arch Linux x86_64 与 `quick-sharun` 封装（[build_tencent-docs.sh](./build_tencent-docs.sh)），在 `AppDir/.env` 内置 `zh_CN.UTF-8` locale 与 `SHARUN_WORKING_DIR=${SHARUN_DIR}/bin`、`SHARUN_EXTRA_LIBRARY_PATH=${SHARUN_DIR}/bin:${SHARUN_EXTRA_LIBRARY_PATH}`，并通过 `AppDir/bin/90-tencent-docs-arguments.hook` 固定 `--lang=zh-CN "$@"`, 替代自写 `AppRun.sh`。
- 产物路径：`tencent-docs/dist/tencent-docs.AppImage`（版本文件：`tencent-docs/dist/version.txt`）。
- 统一构建入口：`.github/workflows/build.yml` 中的标准矩阵构建流程（`build_standard`，`artifact_dir: tencent-docs/dist`）。
- 相关文档：[模板差异](./docs/template-deviations.md) · [固定配置](./docs/hardcoded.md)

## 统一软件版本元数据

### 2026-11-28：按 Electron DEB 标准整理并接入 `build_standard`

- 按标准结构重写 [build_tencent-docs.sh](./build_tencent-docs.sh)，改为公共安装、公共官方 DEB 下载与 `quick-sharun` 封装；移除自写 `AppRun.sh`、内联测试脚本及旧版 `tencent-docs-version.txt` 写出。
- 构建完成后直接通过 `Common/build/save_appimage_version.sh` 写入 `dist/version.txt`，并在 `.github/appimage-apps.json`、`.github/workflows/build.yml` 与 `.github/scripts/plan_appimage_jobs.py` 中将其切换为标准 `build_standard` Job。

### 2026-09-16：接入 `software_versions.json`

- 修改文件：`.github/workflows/build.yml`、本 README。
- 当时版本来源为旧版 `tencent-docs-version.txt` 中的 `version=`，由共享 workflow 步骤标准化为 `dist/version.txt`。
- 成功构建后上传 `software-version-tencent-docs` 元数据 artifact；当前 Build 仅在对应构建成功后更新 `latest` Release 中的 `software_versions.json`。
- `software_versions.json` 使用版本号判断是否需要更新，Release SHA-256 仅用于文件完整性与本地状态；相同版本的重复构建不会仅因 SHA-256 改变而触发客户端更新。
- 提交后按仓库规则不主动监控 Actions，实际新清单记录以下一次成功构建结果为准。
