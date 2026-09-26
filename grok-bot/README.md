# Grok Bot

## 用途与产物

本目录把 Grok Bot 官方 Linux x64 DEB 重新封装为 AnyLinux AppImage，最终发布资产固定为 `grok-bot.AppImage`。

上游来源：

- 产品页：`https://x.ai/bot`
- Linux stable manifest：`https://api2.cursor.sh/updates/api/download/stable/linux-x64/sand`
- 官方 Linux 安装说明：`https://docs.x.ai/grok-bot/get-started`

构建不固定应用版本。`build_grok-bot.sh` 每次读取官方 stable manifest 的 `version` 与 `debUrl`，再由公共 `download_json_deb_asset.sh` 校验官方 CDN、文件名、DEB 包名、版本和 `amd64` 架构。

## 技术栈

Grok Bot Linux 桌面端是 Electron / Chromium 应用。官方 DEB 的主要程序位于 `/opt/Grok Bot/`，主程序为 `grok-bot`，桌面入口为 `usr/share/applications/grok-bot.desktop`，品牌图标位于 hicolor 图标目录。

本项目只保留官方程序、Electron 资源、原生模块、desktop、图标和许可证文件，不修改 `app.asar`，不修改账号、订阅、授权或服务端访问逻辑。

## 打包方式

当前采用 Arch Linux + quick-sharun：

1. 通过仓库公共 Arch 安装入口准备统一基础环境及 Grok Bot 应用依赖。
2. 通过官方 Linux stable JSON 动态取得当前 x64 DEB；下载与 DEB 身份检查全部复用公共下载入口。
3. 通过公共归档入口解包 DEB，只把官方 `/opt/Grok Bot/` 运行目录复制到 `AppDir/shared/bin/`，保持 Electron 相对资源布局。
4. quick-sharun 收集主程序、Crashpad、GTK3 输入法、通知、密钥环、托盘以及音频客户端运行库。
5. 使用 `.env` 保持 `shared/bin` 为应用运行目录并提供中文 locale；使用 hook 加入 `--no-sandbox`，不自行覆盖 quick-sharun 生成的 AppRun。
6. 使用公共协议 hook 注册 `grokbot://` 与兼容的 `sand://`，用于浏览器登录回调。
7. `quick-sharun --make-appimage` 生成 `dist/grok-bot.AppImage`，成功后写入 `dist/version.txt`。

统一 workflow 中按标准 matrix 项构建，本项目不使用独立 Job。

## 音频处理

用户反馈官方 `grok-bot.AppImage` 在目标 Linux 环境中没有声音，因此本项目不直接同步官方 AppImage，而从官方 DEB 重封装并显式补齐 Linux 音频客户端运行库：

- `libasound.so.2`
- `libpulse.so.0`
- `libpulse-simple.so.0`
- `libpulsecommon-*.so`
- `libpipewire-0.3.so.0` 及 quick-sharun 的 PipeWire runtime 部署

这里同时存在 PulseAudio 与 PipeWire **客户端兼容库**，不代表 AppImage 内启动两套音频服务。构建不会打包或启动 PulseAudio daemon，也不会在用户会话中启动 PipeWire daemon；最终仍连接宿主音频会话。宿主使用 `pipewire-pulse` 时，Electron 的 libpulse 客户端继续通过 PulseAudio 兼容协议工作。

Grok Bot 官方文档确认桌面端支持 voice chat 与可播放的 voice memo，因此语音播放属于应用正常功能；本项目的处理只补齐 Linux 便携包运行时依赖，不改变应用语音功能本身。

2026-09-26 实机对比：官方 `grok-bot.AppImage` 无法发出声音；本目录重打包并补齐上述客户端库后的 `grok-bot.AppImage` 可以发出声音。

## 运行与兼容说明

- AppImage 不安装官方 DEB 的系统级 postinst，也不向 `/etc` 写 AppArmor 配置。
- `chrome-sandbox` 在 AppImage 内保持普通执行权限，启动参数使用 `--no-sandbox`；不会要求用户为 AppImage 设置 setuid root。
- GTK3 同时携带 IBus 与 Fcitx5 输入模块，并在包内提供 `zh_CN.UTF-8` locale。IBus 模块来自 `ibus` 包，不来自 `gtk3`。
- `grokbot://` 与 `sand://` 的桌面协议注册只写入当前用户的 XDG desktop / MIME 配置，不修改系统级默认配置。
- 音频客户端库进入 AppImage 后仍依赖宿主存在可用的用户音频会话与实际输出设备。

## 2026-09-26：新增重打包方案

- **现象：** 用户反馈官方 Grok Bot AppImage 可以运行，但无法发出声音。
- **核查：** 官方文档确认 Linux 桌面端和 voice chat / voice memo 功能；官方 DEB 直接声明 ALSA 等 Linux 依赖，现有 Linux 封装资料同时显示 Electron 运行时可能动态加载 PulseAudio / PipeWire 客户端库。
- **处理：** 新增 `build_grok-bot.sh`，改从官方 stable DEB 动态重打包；显式携带 ALSA、libpulse 与 PipeWire 客户端运行库，同时保留宿主音频 daemon，不在 AppImage 内启动 PulseAudio 或 PipeWire 服务。
- **接入：** 新增标准 matrix 清单项和手动构建下拉项，最终资产为 `grok-bot.AppImage`，版本元数据写入 `software_versions.json` 的 `grok-bot` 条目。
- **验证状态：** 构建脚本、清单和 workflow 已接入。音频输出的实机结果见同日「实机确认可以出声」。

## 2026-09-26：补上 IBus 包

- **现象：** 构建把 `/usr/lib/gtk-3.0/3.0.0/immodules/im-ibus.so` 交给 quick-sharun，但安装列表只有 `fcitx5-gtk`。
- **核查：** Arch 上该文件属于 `ibus`，不在 `gtk3` 依赖里。quick-sharun 遇到不存在的路径会报错并退出。
- **处理：** 安装列表补上 `ibus`，与 Discord 的 GTK3 输入模块来源一致。
- **验证状态：** 只完成包来源和缺失路径会中止构建的静态核对；提交后不监控 GitHub Actions。

## 2026-09-26：实机确认可以出声

- **对比：** 同一环境中，官方 Grok Bot AppImage 可以运行，但不能发出声音。
- **结果：** 本仓库从官方 DEB 重打包，并补齐 ALSA、libpulse 与 PipeWire 客户端库之后，`grok-bot.AppImage` 可以发出声音。
- **范围：** 这次确认的是音频输出恢复。应用自身的 voice chat / voice memo 逻辑没有改动，播放仍依赖宿主已有的用户音频会话和输出设备。
