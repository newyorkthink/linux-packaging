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

## 运行

下载 Release 中的 `feishu.AppImage` 后赋予执行权限并直接运行：

```bash
./feishu.AppImage
```

## 版本元数据

构建脚本复用本次官方 API 已解析出的 `VERSION`，在最终 AppImage 与图形启动检查成功后直接写入 `feishu/dist/version.txt`。workflow 上传该文件为 `software-version-feishu`，并增量写入 `latest/software_versions.json`。

### 2026-09-16：接入统一软件版本元数据

- 复用本次构建已经解析出的 `VERSION`，不重复请求或维护另一套固定版本。
- workflow 接入 `SOFTWARE_KEY=feishu` 与统一版本清单。
- 不修改现有飞书打包脚本和已验证兼容逻辑。
