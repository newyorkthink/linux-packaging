# ripdrag AppImage

## 用途与产物

本目录从 crates.io 构建当前稳定版 ripdrag，生成 `dist/ripdrag.AppImage`，由 workflow 发布为同名资产 `ripdrag.AppImage`。

## 技术栈与打包方式

ripdrag 为 Rust / GTK4 文件拖放工具。构建脚本通过公共 Cargo 安装入口以 `--locked` 安装到 `source/`，复用仓库中的 desktop 和 SVG。quick-sharun 扫描本次安装的二进制，收集 GTK4、GdkPixbuf 和 Glycin 运行依赖。扫描完成后复制原有深色主题 Hook，再封装 AppImage。

Cargo 暂存安装和资源接入方式见[模板差异](./docs/template-deviations.md)。

## 运行

```bash
./dist/ripdrag.AppImage
```

Release 中对外稳定资产名仍为 `ripdrag.AppImage`。

## 版本元数据

构建脚本通过公共入口读取本次 Cargo 安装的二进制的 `--version` 输出。AppImage 封装成功后，公共保存入口检查产物并写入 `dist/version.txt`。workflow 使用 `SOFTWARE_KEY=ripdrag` 接入统一版本清单。

## 实机验证

### 2026-11-28：用户实机验证通过

用户已确认 Ripdrag `0.4.13` 实机验证通过。

| 实测项目 | 通过结果 |
| --- | --- |
| 下载与更新 | 更新器重新下载 `ripdrag.AppImage`，SHA-256 校验通过，完成 `0.4.13` 更新。 |
| 启动与主题 | 从终端启动 `ripdrag`，深色窗口正常显示。 |
| 多文件面板 | 多个 PNG 文件在拖放面板中显示缩略图，并出现 `Drag All Items` 入口。 |

## 变更记录

### 2026-11-28 按 quick-sharun 规范整理

接入公共依赖安装、工作区、Cargo 和版本入口，使用已提取的桌面资源和深色主题 Hook，统一产物名为 `ripdrag.AppImage`。已静态核对模板格式、调用顺序、资源引用和 Git 文件模式。`0.4.13` 已完成构建、发布，并写入统一版本清单。[构建记录](https://github.com/newyorkthink/linux-packaging/actions/runs/46109295044/job/140869072321)

### 2026-09-16：接入统一软件版本元数据

仅增加统一版本文件与发布映射，不改变 Cargo、GTK4、主题 Hook 或 quick-sharun 基线。
