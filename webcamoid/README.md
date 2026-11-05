# Webcamoid AppImage

## 用途与产物

本目录从 Webcamoid 官方最新稳定 Release 源码构建 x86_64 AppImage，稳定产物名为 `webcamoid.AppImage`。构建不拉取私有 ExtraPlugins 子模块。

## 技术栈与打包方式

Webcamoid 为 C++ / Qt 6 / QML 摄像头与多媒体应用。当前脚本在 Arch Linux 环境中使用 CMake + Ninja 构建上游源码，并用 quick-sharun 收集 Qt Multimedia、FFmpeg、PipeWire、V4L2、v4l-utils、libuvc 与 Qt 6 主题等运行依赖。

源码获取统一调用 [公共源码下载入口](../common/github/download_latest_stable_release_source.sh)，通过公共 GitHub API 认证查询 `webcamoid/webcamoid` 的最新非草稿、非预发布 Release，并按该标签浅克隆到 `work/source`。公共入口成功后只向 stdout 返回原始标签，克隆日志写入 stderr；不递归拉取 ExtraPlugins 子模块。

现有四个源码补丁分别负责深色配色、关闭 QSharedMemory 单实例检测、过滤 Dummy / loopback 摄像头输入，以及跳过指定硬件编码器。当前编译参数关闭 GStreamer、libavdevice 和 wlroots；安装后移除指定桌面捕获插件，保留音频 PipeWire。各项作用和影响见下方专属文档。

## 版本元数据

构建脚本使用 `VERSION` 保存公共源码入口返回的最新稳定 tag，在最终 AppImage 成功生成后，调用公共版本保存入口写入：

```text
dist/version.txt
```

统一 workflow 在成功构建后上传 `software-version-webcamoid`，当前 Build 使用 `webcamoid.AppImage` 的 Release SHA-256 更新 `software_versions.json`。

## 构建与运行

正式构建入口为 `.github/workflows/build.yml`，构建脚本为：

```text
webcamoid/build_webcamoid.sh
```

在 Linux 终端进入产物所在目录后，运行最终产物：

```bash
# 启动 Webcamoid AppImage。
./webcamoid.AppImage
```

## 专属文档

| 文档 | 内容 |
| --- | --- |
| [模板差异与注释核对](./docs/template-deviations.md) | 当前源码专用流程、相对现有模板的差异、补丁与依赖收集、注释核对结果。 |
| [固定配置](./docs/hardcoded.md) | 工作目录、资源路径、编译参数、部署开关和运行环境的实际取值及依据。 |
| [pkgforge 打包差异](./docs/pkgforge-differences.md) | 上游打包源码快照、实际采用的公共步骤和未启用的上游专属处理。 |
| [错误与处理记录](./docs/error.md) | 原 runtime-errors.md 中的硬件编码器、桌面捕获与 GStreamer 历史记录。 |

当前属于 [专用打包流程](../docs/packaging-classification.md#专用打包流程)。现有 Qt 模板分别面向官方 DEB 或系统已安装程序，不包含这里的源码补丁、CMake 安装和暂存目录部署。本目录不作为新增标准模板，也不表示已由生成器按某份 Qt 模板全量生成。

## 实机验证

### 2026-11-05：用户实机验证通过

用户提供的 Linux 实机截图与完整日志显示，Webcamoid 的摄像头预览、录像启停和录像回放通过。

| 实测项目 | 通过结果 |
| --- | --- |
| 程序界面 | 主窗口显示深色界面及摄像头预览画面。 |
| 摄像头输入 | 日志记录跳过 Dummy 设备并识别真实摄像头，预览画面与录制回放画面一致。 |
| 软件编码与录像 | WebM 录制使用 libvpx 和 libvorbis，日志依次记录 Recording started、Stopping recording、Recording stopped；成片时长为 16.2744 秒。 |
| 录像回放 | 截图展示录像画面，外部播放器显示约 16 秒时长及播放进度。 |

#### 运行观察

- 启动阶段出现 PulseAudio context failed or terminated，之后记录 PulseAudio device initialized；录制阶段的音频输入和输出也正常进入启动流程。
- Invalid codec id: "" 出现在初始化阶段；实际录制随后选定 libvpx / libvorbis 并完成封装。
- Location (URL) not set 紧随空的本地流媒体地址输出，属于该次流媒体启动未提供地址的提示；随后录像正常完成。
- 日志还有 QML Settings 弃用提示、QML Image 协议提示和 PipeWire 连接提示，按本次客观运行观察保留，不作为构建失败记录。

## 变更记录

### 2026-11-05：整理当前实现与实机记录

- 当前脚本基线为 [d1b4475](https://github.com/newyorkthink/linux-packaging/commit/d1b4475cb5ae5215a7490dd67a8210bb5eaeb552)，工作目录为 `work/`，版本变量为 `VERSION`；下方旧提交条目中的变量名保留为当时记录。
- 补齐专属差异、固定配置、上游打包取舍和公共分类入口；错误记录改用 `docs/error.md`，原有故障事实与处理过程继续保留。
- 核对固定注释并为四个 Python 补丁补充中文用途说明；构建命令、补丁逻辑、运行配置和发布入口保持原样。
- 按本次已有截图与日志记录实机通过结果。

### 2026-11-05：源码获取改用公共入口

- [f99c379](https://github.com/newyorkthink/linux-packaging/commit/f99c3792bb33457a0ff0a48facf5b8e13d031661) 新增 `common/github/download_latest_stable_release_source.sh`，统一正式 Release 查询、标签格式校验与对应源码浅克隆。
- [93103ef](https://github.com/newyorkthink/linux-packaging/commit/93103ef4eaecc6551df063dc46bca4e4dcd9a174) 在 `build_webcamoid.sh` 中接入该入口，替代原匿名 Release 请求、单独的 JSON 解析和 `git clone`。
- 返回标签继续用于 `WEBCAMOID_REF` 和 `dist/version.txt`；现有源码补丁、CMake 参数、依赖收集、封装和发布入口保持原样。

### 2026-09-16：接入统一软件版本元数据

- 修改文件：`.github/workflows/build.yml`、本 README。
- 复用既有 `dist/version.txt`，不修改 Webcamoid 构建脚本、现有源码补丁和 Release 资产名。
- 提交后不主动监控 Actions，实际新清单记录以下一次成功构建为准。
