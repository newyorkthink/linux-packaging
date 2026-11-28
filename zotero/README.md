# Zotero AppImage

## 用途与产物

本目录从 Zotero 官方 release Linux x86_64 tar 包重新封装 `zotero.AppImage`。

## 技术栈与打包方式

Zotero Linux 客户端使用 Mozilla/Firefox 系桌面运行时。构建时先安装 Arch Extra 的 `zotero` 及所需依赖，再通过公共入口独立下载和解包官网 tar 包。构建脚本保留完整程序目录和官方启动器，并通过 quick-sharun 部署 GTK3、NSS、X11、OpenGL 和中文输入依赖。

官网 tar 包和包内 `application.ini` 的版本来源超出固定模板的适用范围，因此按专用流程整理。处理依据见[模板差异](./docs/template-deviations.md)与[固定配置](./docs/hardcoded.md)。

## 版本元数据

构建时从同一份官网 tar 包的 `app/application.ini` 读取 `Version` 字段。AppImage 成功生成后，公共保存入口写入 `dist/version.txt`。workflow 使用 `SOFTWARE_KEY=zotero` 接入统一版本清单。

## 运行

```bash
# 在下载目录启动 Zotero AppImage。
./zotero.AppImage
```

## 实机验证

### 2026-11-28：用户实机验证通过

用户已确认 Zotero `10.0.8` 实机验证通过。

| 实测项目 | 通过结果 |
| --- | --- |
| AppImage 更新 | 通过 `software_update` 更新到 `10.0.8`。 |
| 启动与界面 | 正常启动并显示简体中文文库界面。 |
| 中文输入 | 搜索栏可输入中文并显示候选词。 |
| PDF 阅读 | 内置阅读器可打开 PDF 并显示页面。 |

## 变更记录

### 2026-11-28：整理官网归档打包流程

构建脚本已接入公共依赖安装、下载、解包和版本入口，并加入包内中文 locale 与 Fcitx5 GTK 输入模块。现有 `zotero -url %U` 桌面入口和官方启动器继续使用。 [脚本整理提交](https://github.com/newyorkthink/linux-packaging/commit/8ceb4c9e6d714e219c00631a4468336113bf181d)

### 2026-09-16：接入统一软件版本元数据

仅增加版本读取、`dist/version.txt` 与发布映射，不改变现有 Zotero 官方 tar 包、NSS、GTK、X11、OpenGL 或 IBus 打包逻辑。
