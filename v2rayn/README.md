# v2rayN AppImage

## 用途与产物

本目录从 v2rayN 官方 GitHub 最新稳定 Release 下载 Linux x64 自包含包，并重新封装为 `v2rayn.AppImage`。

## 技术栈与打包方式

v2rayN Linux 客户端使用 .NET/Avalonia。构建脚本校验官方 Release SHA-256，保留自包含运行目录，通过 quick-sharun 处理 ELF 和桌面集成。

## 版本元数据

构建脚本复用官方稳定 Release tag 解析出的 `VERSION`，在现有最终产物检查完成后写入 `dist/version.txt`。workflow 使用 `SOFTWARE_KEY=v2rayn` 接入统一版本清单。

## 运行

```bash
./v2rayn.AppImage
```

## 变更记录

### 2026-09-16：接入统一软件版本元数据

仅增加统一版本输出与发布映射，不改变现有官方包校验、Avalonia 自包含目录或启动环境。

### 2026-09-17：修复 GitHub Actions 下载官方 Release 资产 403

- 故障现象：全量 Actions Run `35159519188` 的 `Build v2rayN` 在读取官方最新 Release 信息成功后，下载 `v2rayN-linux-64.zip` 时收到 HTTP 403，构建在正式打包前退出。
- 根因范围：失败发生在 GitHub Release 的 `browser_download_url` 直链下载阶段；现有 Release API、版本解析和 SHA-256 digest 读取均已成功，因此不修改 v2rayN 打包、Avalonia runtime 或版本元数据逻辑。
- 修改文件：`v2rayn/build_v2rayn.sh`、本 README。
- 修复：继续优先使用官方 `browser_download_url`；如果该直链下载失败，则使用同一 Release asset 的 GitHub API asset ID，并通过 workflow 已提供的 `GH_TOKEN` 以 `application/octet-stream` 方式下载。两条路径最终仍使用 GitHub Release 返回的同一个 SHA-256 digest 校验。
- 已知结果：本次仅修复下载入口；完整构建结果以对应 Actions Job 为准。
