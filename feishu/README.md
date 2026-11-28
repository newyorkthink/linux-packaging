# Feishu AppImage

本目录用于把飞书官方当前稳定版 Linux x86_64 DEB 重新封装为 `feishu.AppImage`。

## 构建来源

- 构建阶段先通过公共 Arch 入口安装 AUR `feishu-bin`、DEB 解包工具与 GTK3/音频运行依赖，再通过 `Common/download/download_json_deb_asset.sh` 请求飞书官方 Linux API（`https://www.feishu.cn/api/package_info?platform=10`），动态解析当前版本、下载链接和 MD5 摘要，不写死应用版本。
- 下载仅接受飞书官方 CDN 域名（`feishucdn.com`）的 x86_64 DEB，并核对文件名、版本、包名（`bytedance-feishu-stable`）、架构（`amd64`）及官方 MD5 摘要，同时将源版本写入 `work/source-version.txt`。

## 打包与运行

- 采用 Arch Linux x86_64 与 `quick-sharun` 封装（[build_feishu.sh](./build_feishu.sh)），完整保留 `opt/bytedance/feishu/` 程序目录、官方 `bytedance-feishu` 启动脚本及 `product_logo_256.png` 图标，不修改应用本体，并在 `bytedance-feishu.desktop` 副本通过 `desktop-file-validate` 校验后改写 `Exec` 与 `Icon`。
- 在 `AppDir/.env` 内置 `zh_CN.UTF-8` locale 与 `SHARUN_WORKING_DIR=${SHARUN_DIR}/bin`、`SHARUN_EXTRA_LIBRARY_PATH=${SHARUN_DIR}/bin:${SHARUN_EXTRA_LIBRARY_PATH}`，替代旧版自写 `AppRun.sh`。
- 正式构建由 `.github/workflows/build.yml` 中的标准矩阵构建流程（`build_standard`，`artifact_dir: feishu/dist`）完成，发布文件名固定为 `feishu.AppImage`。
- 相关文档：[模板差异](./docs/template-deviations.md) · [固定配置](./docs/hardcoded.md)

## 运行

下载 Release 中的 `feishu.AppImage` 后赋予执行权限并直接运行：

```bash
# 运行飞书 AppImage
./feishu.AppImage
```

## 版本元数据

构建脚本复用本次官方 API 已解析出的 `VERSION`（通过 `Common/build/read_app_version.sh` 读取 `work/source-version.txt` 并在缺少 `X-AppImage-Version` 时写入 desktop 副本），在最终 AppImage 生成成功后直接写入 `feishu/dist/version.txt`。workflow 上传该文件为 `software-version-feishu`，并增量写入 `latest/software_versions.json`。

### 2026-11-28：按 Electron DEB 标准重写构建脚本

- 按标准结构重写 [build_feishu.sh](./build_feishu.sh)，切至 `Common/arch/install_packages.sh`、`Common/download/download_json_deb_asset.sh`、`Common/archive/extract_archive.sh` 与 `quick-sharun` 标准封装。
- 移除自写 `AppRun.sh` 与内联 Xvfb 冒烟测试，改由 `AppDir/.env` 固定 `SHARUN_WORKING_DIR`、`SHARUN_EXTRA_LIBRARY_PATH` 与 `zh_CN.UTF-8` locale。

### 2026-09-16：接入统一软件版本元数据

- 复用本次构建已经解析出的 `VERSION`，不重复请求或维护另一套固定版本。
- workflow 接入 `SOFTWARE_KEY=feishu` 与统一版本清单。
- 不修改现有飞书打包脚本和已验证兼容逻辑。
