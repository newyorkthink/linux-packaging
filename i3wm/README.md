# i3wm AppImage

## 用途与产物

本目录将 Arch Linux 当前稳定 `i3-wm`、`i3status`、dmenu、xss-lock 与常用 i3 工具打包为 `dist/i3.AppImage`。锁屏程序不随主 AppImage 打包，避免认证与权限模型冲突。

## 技术栈与打包方式

i3 为 X11 窗口管理器，主体使用 C。构建脚本通过 Arch 软件包安装 i3 及相关工具，保留默认 `/etc/i3` 与 `/etc/i3status.conf`，使用 quick-sharun 收集程序和运行依赖并生成固定资产 `i3.AppImage`。

## 运行与兼容说明

在当前目录执行：

```bash
./dist/i3.AppImage
```

Perl 辅助脚本继续依赖宿主 Perl；i3lock/slock 不进入本 AppImage。现有 PATH_MAPPING、默认配置和 X11 工具集合保持当前稳定基线。

## 版本元数据

构建时从本次实际安装的 `i3-wm` 包读取版本，去掉 Arch epoch 与 pkgrel 后写入 `dist/version.txt`。统一版本清单键使用 `i3`，对应 Release 资产 `i3.AppImage`。

## 变更记录

### 2026-09-16：接入统一软件版本元数据

仅增加版本读取、`dist/version.txt` 与统一 `software_versions.json` 映射，不改变现有 i3 程序集合、配置映射或锁屏边界。
