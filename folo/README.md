# Folo AppImage

## 用途与产物

本目录从 Folo 官方稳定 Desktop Linux x64 AppImage 提取上游 Electron 程序并重新封装，最终资产固定为 `folo.AppImage`。

## 技术栈与打包方式

Folo 为 Electron 桌面应用。构建脚本通过官方 GitHub Releases 动态选择稳定 `desktop/v<version>`，校验官方 AppImage，保留 Electron 运行目录与 Node 原生模块，并使用 quick-sharun 补齐 GTK、图形和音频运行时。

## 版本元数据

构建脚本复用本次 Release 解析得到的 `VERSION`，在现有最终产物检查完成后写入 `dist/version.txt`。workflow 使用 `SOFTWARE_KEY=folo` 接入统一 `software_versions.json`。

## 运行

```bash
./folo.AppImage
```

## 变更记录

### 2026-09-16：接入统一软件版本元数据

仅增加 `dist/version.txt` 与 workflow 清单接入，不改变现有 Folo Electron 运行目录、音频依赖、输入法或启动逻辑。

### 2026-09-23：为 GitHub Releases API 接入统一认证

- 故障现象：构建读取 Folo Releases API 时收到 HTTP 403，在下载官方 AppImage 前退出。
- 根因：应用脚本直接发起未认证的 GitHub API 请求，容易触发匿名请求限额。
- 修改文件：`folo/build_folo.sh`、本 README。
- 修复内容：改用仓库现有 `common/github/github_api.sh` 请求 Release 元数据，自动使用 workflow 提供的 `GH_TOKEN`，并保留原有稳定版筛选、资产 URL 与摘要校验逻辑。
- 已知结果：API 请求已接入统一认证与重试入口；实际构建结果以下一次 Actions 为准。
