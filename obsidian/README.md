# Obsidian AppImage

## 用途与产物

本目录从 Obsidian 官方 Desktop Releases 动态选择最近一个包含 Linux x64 tar 包的版本，并重新封装为 `obsidian.AppImage`。

## 技术栈与打包方式

Obsidian 为 Electron 桌面应用。脚本保留官方 Linux x64 程序目录和资源，通过 quick-sharun 补齐 GTK、NSS、X11、OpenGL、PipeWire 与 IBus 运行组件。

## 版本元数据

构建脚本复用从官方 tar 包 URL 解析出的 `VERSION`，AppImage 成功生成后写入 `dist/version.txt`。workflow 使用 `SOFTWARE_KEY=obsidian` 接入统一版本清单。

## 运行

```bash
./obsidian.AppImage
```

## 变更记录

### 2026-09-16：接入统一软件版本元数据

仅增加统一版本输出与发布映射，不改变现有 Obsidian 上游选择、Electron 依赖或输入法逻辑。

## 独立标准化构建脚本

`build_obsidian_new.sh` 使用现有 Electron GitHub Release DEB 标准模板的主体流程，并补充本应用的图形、音频和 NSS 运行组件。原 `build_obsidian.sh` 及其正式构建入口均未改变。

新脚本先安装 `obsidian-bin` 和运行依赖，再独立下载并校验 Obsidian 官方正式 Release 的 AMD64 DEB；将完整程序目录放入 `AppDir/bin`。使用公共版本接口和 quick-sharun 生成 AppImage，并生成包内中文 locale。

应用专属处理包括 OpenGL、Vulkan、PipeWire 部署及 `hostname`、NSS、GTK3 IBus 扫描，按原应用脚本与相关已标准化项目核对。详细说明见 [模板差异](./docs/template-deviations.md) 和 [固定配置](./docs/hardcoded.md)。

正式清单 `.github/appimage-apps.json` 仍使用 `obsidian/build_obsidian.sh`，新脚本不参与正式构建和发布。
