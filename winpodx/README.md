# WinPodX AppImage

## 用途与产物

本目录基于 `kernalix7/winpodx` 官方 x86_64 AppImage 做最小兼容修复后重新封装，稳定产物名为 `winpodx.AppImage`。当前实现不重新编译或替换上游内置 FreeRDP。

## 技术栈与打包方式

WinPodX 采用 Python / PySide6 Qt 运行时并内置 FreeRDP 3。构建脚本下载上游正式 AppImage，保留官方 FreeRDP 二进制与核心库，在现有稳定基线上处理 Qt/XCB 私有运行库、Pulse/PipeWire-Pulse 音频回退和桌面图标入口，再用 appimagetool 生成最终 AppImage。

`fix_winpodx_qt_runtime.sh` 只为 PySide6 Qt xcb 平台插件补齐现有脚本明确需要的私有 XCB 运行库，并与 FreeRDP 公共运行库目录隔离。

## 版本元数据

构建脚本已有：

```text
dist/winpodx-release-version.txt
```

其中 `version=` 来自上游正式 tag。统一 workflow 从该字段生成标准：

```text
dist/version.txt
```

随后上传 `software-version-winpodx`，当前 Build 使用 `winpodx.AppImage` 的 Release SHA-256 更新 `software_versions.json`。

## 构建与运行

正式构建入口为 `.github/workflows/build.yml`。相关脚本：

```text
winpodx/build_winpodx_release.sh
winpodx/fix_winpodx_qt_runtime.sh
.github/scripts/ci_build_winpodx.sh
```

运行最终产物：

```bash
./winpodx.AppImage
```

## 变更记录

### 2026-09-16：接入统一软件版本元数据

- 修改文件：`.github/workflows/build.yml`、本 README。
- 仅在 workflow 中把现有 `winpodx-release-version.txt` 的 `version=` 标准化为 `dist/version.txt`。
- 不修改已确认的 WinPodX 音频、Qt/XCB、FreeRDP、图标补丁及 Release 资产名。
- 提交后不主动监控 Actions，实际新清单记录以下一次成功构建为准。
