# ripdrag AppImage

## 用途与产物

本目录从 crates.io 构建当前稳定 ripdrag，并生成版本化构建产物后由 workflow 发布为稳定资产 `ripdrag.AppImage`。

## 技术栈与打包方式

ripdrag 为 Rust / GTK4 文件拖放工具。构建脚本使用 `cargo install ripdrag --locked` 获取当前稳定版本，生成 desktop 与图标，通过 quick-sharun 收集 GTK4 / Glycin 运行依赖，并保持现有深色主题 Hook。

## 运行

```bash
./dist/ripdrag.AppImage
```

Release 中对外稳定资产名仍为 `ripdrag.AppImage`。

## 版本元数据

构建脚本复用已经从 `ripdrag --version` 解析得到的 `VERSION`，在现有流程结束后写入 `dist/version.txt`。workflow 使用 `SOFTWARE_KEY=ripdrag` 接入统一版本清单。

## 变更记录

### 2026-09-16：接入统一软件版本元数据

仅增加统一版本文件与发布映射，不改变 Cargo、GTK4、主题 Hook 或 quick-sharun 基线。
