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
