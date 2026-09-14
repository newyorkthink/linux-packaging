# Parsec AppImage

用于将 Parsec 官方 Linux x86_64 客户端重新封装为 AppImage，重点保留官方启动资源、FFmpeg 4.4 解码 ABI、图形 / 音频运行时以及简体中文 UTF-8 locale。

## 用途与产物

- 打包对象：Parsec Linux 客户端。
- 最终产物：`parsec.AppImage`。
- Release 资产名：`parsec.AppImage`。
- 正式构建入口：`.github/workflows/build.yml` 中的 `Build Parsec` Job。
- 上游程序来源：AUR `parsec-bin`；其 PKGBUILD 从 Parsec 官方 `parsec-linux.deb` 获取程序本体。
- 当前仅构建 x86_64。
- Linux 端只作为 Parsec Client 使用；Parsec 官方当前不支持 Linux Hosting。

本目录只处理 AppImage 重打包、依赖收集和运行兼容，不修改 Parsec 的账号、授权、网络协议或付费功能。

## 技术栈

Parsec Linux 客户端是闭源原生 Linux 程序，官方入口为 `/usr/bin/parsecd`，并使用 `/usr/share/parsec/skel/` 中的 `appdata.json` 与 `parsecd-*.so` 启动资源。

根据 Parsec 当前 Linux 官方文档：

- Linux 客户端基于 X11，也可在 XWayland 下运行。
- Client Renderer 支持 OpenGL；Vulkan 作为实验选项，具体可用项取决于系统与硬件。
- Decoder 正常应能提供 Hardware、Software，部分硬件还会出现 NVIDIA 等厂商选项。
- Linux 运行依赖明确包括 `libavcodec.so.58` 与 `libavutil.so.56`。
- Parsec 官方当前明确支持 Ubuntu 22.04 LTS Desktop；其他发行版可能可用，但不属于其正式支持范围。

AUR `parsec-bin` 当前依赖 `ffmpeg4.4`，与官方要求的 FFmpeg 4.4 ABI 一致；同时把 `libva` 标记为硬件加速解码的可选依赖。构建脚本因此显式安装并收集 Parsec 官方动态模块、`libavcodec.so.58`、`libavutil.so.56` 与 `libswresample.so.3`，避免只打包 `/usr/bin/parsecd` 启动器而漏掉实际解码运行时。

## 打包方式

当前路线为 **Arch Linux + quick-sharun**：

1. 使用仓库规定的最小 Arch Linux AppImage 构建依赖。
2. 通过 `yay` 安装当前 AUR `parsec-bin`，让 AUR 元数据动态跟随 Parsec 官方 Linux 包；脚本不固定 Parsec 应用版本。
3. 额外安装 `ffmpeg4.4`、`libjpeg-turbo` 与 `libva`：
   - `ffmpeg4.4` 提供 Parsec 官方要求的 FFmpeg 4.4 解码 ABI。
   - `libjpeg-turbo` 提供 Parsec 当前 Linux 包需要的 libjpeg v8 ABI。
   - `libva` 对应 AUR 标注的硬件加速解码支持。
4. quick-sharun 同时收集 `/usr/bin/parsecd`、官方 `parsecd-*.so` 模块，以及 FFmpeg 4.4 的关键解码库。
5. 使用 `PATH_MAPPING` 将运行时固定的 `/usr/share/parsec` 映射到 AppImage 内的官方资源目录，并完整保留 `appdata.json` 与官方动态模块。
6. 启用 quick-sharun 的 OpenGL、PipeWire 和 locale 部署；保持 AUR 的 `!strip` 语义，不 strip Parsec 官方闭源 ELF。
7. 生成 `zh_CN.UTF-8` locale 后由 `quick-sharun --make-appimage` 生成 `dist/parsec.AppImage`。

不加入测试 / smoke test 代码，也不通过强制软件解码绕过缺失依赖问题。

## 中文环境与输入法

### 简体中文 locale

AppImage 内生成独立的 `zh_CN.UTF-8` locale，并设置：

- `LANG=zh_CN.UTF-8`
- `LANGUAGE=zh_CN:zh`
- `LC_CTYPE=zh_CN.UTF-8`
- `LC_MESSAGES=zh_CN.UTF-8`
- `LOCPATH=${SHARUN_DIR}/lib/locale`

这些设置只作用于 AppImage 运行环境，不修改宿主系统的全局 locale。

### Fcitx5 / IBus

Parsec Linux 客户端是 X11 程序，并非 Qt 或 GTK 应用，因此本项目不错误地塞入 `fcitx5-qt`、`fcitx5-gtk` 或对应 Qt / GTK input context plugin。

构建产物不会覆盖 `XMODIFIERS`，继续使用宿主图形会话已经配置的 XIM / Fcitx5 / IBus 环境。这样既兼容使用 Fcitx5 的桌面，也不会把公共 AppImage 强制绑定到某一种输入法。

远程 Windows / macOS 主机中的中文输入法仍属于远端系统自身；本节处理的是 Linux Parsec 客户端本地文本输入环境。

### Parsec 官方中文界面

截至 2026-09-14，当前 Parsec Linux 官方设置文档没有列出 Language / 中文界面切换项，也没有确认 Linux 客户端提供官方简体中文 UI。

因此本项目：

- 不修改 Parsec 二进制或资源来强行汉化；
- 不加入第三方翻译补丁；
- `zh_CN.UTF-8` 仅用于 locale 与中文输入兼容；
- 实际 Parsec UI 语言继续由上游程序决定。

如果 Parsec 后续正式加入 Linux 中文界面，当前中文 locale 可以直接作为上游语言选择的基础环境，但仍应以届时官方实现为准。

## 运行与兼容说明

- Linux AppImage 只能作为 Client 连接受支持的 Host；不能把 Linux 机器变成 Parsec Host。
- 官方 Linux 支持基线是 Ubuntu 22.04 LTS Desktop；AppImage 的跨发行版兼容属于本仓库重打包目标，不代表 Parsec 官方扩大了支持范围。
- 图形硬件解码最终仍依赖宿主 GPU、内核 / 用户态显卡驱动及对应硬件能力；AppImage 不封装某一台机器的 NVIDIA / AMD / Intel 专有驱动。
- OpenGL 运行时由 quick-sharun 按 AnyLinux 路线部署；硬件相关 ICD / 驱动仍按 quick-sharun 与宿主驱动机制处理。
- ALSA / PipeWire 音频按 AUR 依赖和 quick-sharun PipeWire 部署处理。
- Parsec 用户数据仍按上游正常行为写入用户目录中的 `.parsec` 数据目录；本项目不额外创建系统服务、开机启动项或提权逻辑。

### 直接运行

在 Linux 终端进入 AppImage 所在目录后执行：

```bash
# 启动 Parsec Linux 客户端
./parsec.AppImage
```

## 修复与变更记录

### 2026-09-14：新增 Parsec AppImage，并针对 Decoder 空白 / `-17` 补齐解码运行时

- **问题现象：** 旧 AppImage 能登录、发现远端 Windows 主机并完成网络建链，但 Linux Client 的 `Decoder` 下拉框为空；收到视频关键帧后出现 `decode-frame[341] = -17` 并断开。
- **核对结果：** Parsec 当前官方 Linux 文档明确要求 `libavcodec.so.58` 与 `libavutil.so.56`，正常 Decoder 设置应提供 Hardware / Software 等选项；当前 AUR `parsec-bin` 依赖 `ffmpeg4.4`，并将 `libva` 标为硬件加速解码可选依赖。Flathub 当前 Parsec manifest 也确认官方包使用 `/usr/bin/parsecd` 与 `/usr/share/parsec/skel/` 启动资源，并额外提供 libjpeg v8 ABI。
- **修改文件：** `parsec/build_parsec.sh`、`parsec/README.md`、`.github/workflows/build.yml`。
- **处理内容：** 新增正式 quick-sharun 构建；显式收集官方 `parsecd-*.so`、FFmpeg 4.4 解码库和官方 skel 资源；加入 OpenGL / PipeWire 运行部署；保留上游二进制不 strip；补充简体中文 locale，并保持宿主 XIM/Fcitx5/IBus 环境。
- **中文界面结论：** 当前 Parsec Linux 官方文档未确认官方中文 UI 或 Language 选择项，因此没有加入非官方汉化。
- **已知状态：** 已完成上游文档、AUR/Flathub 打包元数据与仓库结构的静态核对；新 AppImage 的正式 Actions 构建结果以及 Decoder、实际连接、硬件解码、中文输入效果仍待真实产物验证，不提前标记为已修复验收。
