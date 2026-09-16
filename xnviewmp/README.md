# XnView MP AppImage

## 用途与产物

本目录按当前已验证兼容基线构建 XnView MP，Release 资产固定为 `xnviewmp.AppImage`。

## 技术栈与打包方式

XnView MP 为 Qt5 桌面应用。当前稳定基线固定使用 XnView MP `1.11.5` 的已知工作包，并在 Ubuntu 22.04 环境中复现对应 Qt/MDK/FFmpeg 与媒体运行时组合；本任务不改变该固定兼容基线。

## 版本元数据

构建成功后直接把现有 `STABLE_VERSION` 写入 `dist/version.txt`。统一清单键使用 `xnview`，实际 Release 资产仍为 `xnviewmp.AppImage`，供本机 `xnview.AppImage` 映射使用。

## 运行

```bash
./xnviewmp.AppImage
```

## 变更记录

### 2026-09-16：接入统一软件版本元数据

仅增加版本元数据和发布映射，不升级或更换当前 XnView MP 1.11.5 稳定兼容基线。
