# 百度网盘 AppImage

## 用途与产物

本目录将百度网盘官方当前稳定版 Linux x86_64 DEB 重新封装为 `baidunetdisk.AppImage`。正式构建入口为 `.github/workflows/build.yml` 的 `Build Baidu Netdisk` Job。

## 上游来源与打包方式

构建脚本通过百度网盘官方 Linux 客户端 API 动态读取当前版本，并从官方 CDN 下载对应 DEB。现有路线使用 Ubuntu 22.04、linuxdeploy 和 GTK plugin，保留官方程序、desktop 与图标，并补齐 GTKmm、AppIndicator、NSS 等运行组件。

## 版本元数据

workflow 在 AppImage 构建成功后从同一百度官方客户端 API 读取当前 Linux 版本，并写入 `baidunetdisk/dist/version.txt`。该文件上传为 `software-version-baidunetdisk`，成功构建后增量写入 `latest/software_versions.json`。

## 运行

下载 Release 中的 `baidunetdisk.AppImage` 后赋予执行权限并直接运行：

```bash
./baidunetdisk.AppImage
```

## 维护说明

- 应用版本必须继续从官方接口动态获取，不写死版本。
- 最终 Release 资产名固定为 `baidunetdisk.AppImage`。
- 版本元数据只描述软件版本；最终文件 SHA-256 继续用于完整性识别。

## 修改记录

### 2026-09-16：接入统一软件版本元数据

- 不修改现有百度网盘打包脚本。
- 在正式 workflow 中复用官方客户端 API 生成标准 `dist/version.txt` 并接入统一版本清单。
