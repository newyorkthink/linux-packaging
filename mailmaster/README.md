# MailMaster AppImage

## 用途与产物

本目录使用当前 AUR `mailmaster` 配方提供的应用文件，通过 quick-sharun 重新封装为 `mailmaster.AppImage`。正式构建入口为 `.github/workflows/build.yml` 的 `Build MailMaster` Job。

## 打包方式

现有脚本保留 MailMaster 的 Qt5 / CEF 原始目录布局，并处理 libsasl2、NSS、GTK3 输入模块、OpenGL、Vulkan、PipeWire 等运行依赖。最终资产固定为 `mailmaster.AppImage`。

## 运行

下载 Release 中的 `mailmaster.AppImage` 后赋予执行权限并直接运行：

```bash
./mailmaster.AppImage
```

## 版本元数据

构建时从本次实际安装的 AUR `mailmaster` 包读取版本，去掉 Arch epoch 与 pkgrel；最终 AppImage 成功生成后写入 `mailmaster/dist/version.txt`。workflow 上传为 `software-version-mailmaster` 并增量写入 `latest/software_versions.json`。

## 维护说明

- 不写死 MailMaster 应用版本。
- 保持现有程序目录、Qt / CEF 路径和 quick-sharun 兼容逻辑。
- 版本元数据与资产 SHA-256 分离使用。

## 修改记录

### 2026-09-16：接入统一软件版本元数据

- 增加标准 `dist/version.txt`。
- workflow 接入 `SOFTWARE_KEY=mailmaster` 与统一版本清单。
