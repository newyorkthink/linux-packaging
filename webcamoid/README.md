# Webcamoid AppImage

## 用途与产物

本目录从 Webcamoid 官方最新稳定 Release 源码构建 x86_64 AppImage，稳定产物名为 `webcamoid.AppImage`。构建不拉取私有 ExtraPlugins 子模块。

## 技术栈与打包方式

Webcamoid 为 C++ / Qt 6 / QML 摄像头与多媒体应用。当前脚本在 Arch Linux 环境中使用 CMake + Ninja 构建上游源码，并用 quick-sharun 收集 Qt Multimedia、FFmpeg、PipeWire、V4L2、v4l-utils、libuvc 与 Qt 6 主题等运行依赖。

源码获取统一调用 [公共源码下载入口](../common/github/download_latest_stable_release_source.sh)，通过公共 GitHub API 认证查询 `webcamoid/webcamoid` 的最新非草稿、非预发布 Release，并按该标签浅克隆到 `.work/source`。公共入口成功后只向 stdout 返回原始标签，克隆日志写入 stderr；不递归拉取 ExtraPlugins 子模块。

现有源码适配保持深色主题、真实摄像头优先、忽略 Dummy / v4l2loopback 设备以及禁用不可靠的 QSharedMemory 单实例检测；本次版本元数据接入不修改这些行为。

## 版本元数据

构建脚本使用公共源码入口返回的最新稳定 tag 作为 `WEBCAMOID_REF`，并写入：

```text
dist/version.txt
```

统一 workflow 在成功构建后上传 `software-version-webcamoid`，当前 Build 使用 `webcamoid.AppImage` 的 Release SHA-256 更新 `software_versions.json`。

## 构建与运行

正式构建入口为 `.github/workflows/build.yml`，构建脚本为：

```text
webcamoid/build_webcamoid.sh
```

运行最终产物：

```bash
./webcamoid.AppImage
```

## 变更记录

### 2026-11-05：源码获取改用公共入口

- [f99c379](https://github.com/newyorkthink/linux-packaging/commit/f99c3792bb33457a0ff0a48facf5b8e13d031661) 新增 `common/github/download_latest_stable_release_source.sh`，统一正式 Release 查询、标签格式校验与对应源码浅克隆。
- [93103ef](https://github.com/newyorkthink/linux-packaging/commit/93103ef4eaecc6551df063dc46bca4e4dcd9a174) 在 `build_webcamoid.sh` 中接入该入口，替代原匿名 Release 请求、单独的 JSON 解析和 `git clone`。
- 返回标签继续用于 `WEBCAMOID_REF` 和 `dist/version.txt`；现有源码补丁、CMake 参数、依赖收集、封装和发布入口保持原样。

### 2026-09-16：接入统一软件版本元数据

- 修改文件：`.github/workflows/build.yml`、本 README。
- 复用既有 `dist/version.txt`，不修改 Webcamoid 构建脚本、现有源码补丁和 Release 资产名。
- 提交后不主动监控 Actions，实际新清单记录以下一次成功构建为准。
