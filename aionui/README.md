# AionUi AppImage

## 用途与产物

本目录从 AionUi 官网分发渠道获取 Linux x86_64 DEB，重新封装为 `aionui.AppImage`。

## 技术栈与打包方式

AionUi 使用 Electron 和包内的 AionCore 后端。构建时先安装 AUR 的 `aionui-bin` 及所需依赖，再通过公共 Electron 更新清单入口独立获取官网 DEB。公共入口按同一份清单选择 amd64 资产并校验 SHA-512，解包前另核对 DEB 的架构。

构建保留官网 DEB 的完整程序目录、原生模块和 AionCore 后端。desktop 与图标来自本次下载的包，quick-sharun 收集 GTK3、图形和音频依赖。现有模板无法从 Electron 更新清单获取 DEB 和来源版本，因此按专用流程整理。处理依据见[模板差异](./docs/template-deviations.md)与[固定配置](./docs/hardcoded.md)。

## 版本元数据

版本取自校验本次 DEB 的同一份官网清单。AppImage 成功生成后，公共保存入口写入 `dist/version.txt`。workflow 按 `aionui` 接入统一版本清单。

## 运行

```bash
# 在下载目录启动 AionUi AppImage。
./aionui.AppImage
```

## 验证状态

本次静态核对了来源、构建步骤和路径。实际构建与桌面运行结果待验收。
