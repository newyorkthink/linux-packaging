# 微信 AppImage

## 用途与产物

本目录从微信官方 Linux x86_64 DEB 动态取得程序并重新封装为 `wechat.AppImage`。正式构建入口为 `.github/workflows/build.yml` 的 `Build WeChat` Job。

## 上游来源与打包方式

构建脚本直接下载微信官方 x86_64 DEB，从 DEB control 元数据读取实际版本，保留官方程序、desktop、图标及内部相对布局，并通过 quick-sharun 补齐外部系统库和 PulseAudio 运行库。

## 运行

下载 Release 中的 `wechat.AppImage` 后赋予执行权限并直接运行：

```bash
./wechat.AppImage
```

## 版本元数据

现有构建脚本已把从官方 DEB 解析出的版本写入 `~/version`。workflow 在构建成功后复用该单行版本文件生成 `wechat/dist/version.txt`，上传为 `software-version-wechat`，并增量写入 `latest/software_versions.json`。

## 维护说明

- 继续使用微信官方 DEB 的 control 元数据作为版本来源，不手工写死应用版本。
- 最终 Release 资产名固定为 `wechat.AppImage`。
- 不因版本元数据接入改动现有运行依赖和程序布局。

## 修改记录

### 2026-09-16：接入统一软件版本元数据

- 不修改现有微信打包脚本。
- workflow 复用现有 `~/version` 输出，接入标准 `dist/version.txt` 与统一版本清单。
