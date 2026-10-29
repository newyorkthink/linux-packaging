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

当前按 [Electron 直接下载标准](../anylinux_projects.md#直接下载安装包的标准模板) 重写：

1. 公共入口先安装基础包，再安装已核实的 AUR `grok-bot-bin`、原有音频运行依赖和 DEB 工具。系统安装结果用于依赖、图标及主 desktop。
2. 从官方 stable manifest 独立下载当前 x64 DEB，公共入口校验 CDN、文件名、包名、版本和架构；stdout 的实际版本保存到 `grok-bot.version`，不拿 AUR 安装版本代替。
3. 公共归档入口解包到 `grok-bot-unpacked`，把完整 `opt/Grok Bot/` 原样放入 `AppDir/bin/`，保留 Electron 相邻资源。
4. 图标使用系统 `/usr/share/icons/hicolor/256x256/apps/grok-bot.png`，主 desktop 使用 `/usr/share/applications/grok-bot.desktop`。最终程序不复制 AUR 安装目录中的托盘注入、wrapper 或其他修改。
5. quick-sharun 收集完整程序目录及原有音频客户端、通知、密钥环和托盘库；GTK 输入模块交给工具收集，构建环境继续提供 Fcitx5 GTK 和 IBus。
6. 标准步骤生成包内中文 locale；保留原有 `--no-sandbox` 启动兼容 hook，以及 `grokbot://`、`sand://` 登录回调注册。
7. 第一次 quick-sharun 前用公共版本入口读取本次下载记录；最终 AppImage 成功后，统一单行调用公共保存入口写 `dist/version.txt`。

不再把程序放入 `AppDir/shared/bin/`，不再用手工相对链接把资源补回 bin，也不再追加旧布局专用的库路径和工作目录环境变量。脚本中没有构建期 `APPDIR` 变量、额外 `chmod`、`STRACE_MODE`、`NO_STRIP` 或强制 `DEPLOY_PIPEWIRE` 设置。

统一 workflow 中按标准 matrix 项构建，本项目不使用独立 Job。详细配置见 [模板差异](docs/template-deviations.md) 和 [固定配置依据](docs/hardcoded.md)。

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
- 启动 hook 保留 `--no-sandbox`，用于原有 Electron 启动兼容；该参数关闭应用自身的 Chromium 沙箱，不写成所有 AppImage 都必需。构建脚本不再额外修改 `chrome-sandbox` 权限。
- GTK3 的 IBus 与 Fcitx5 输入模块交给 quick-sharun 收集，并按标准生成包内 `zh_CN.UTF-8` locale。IBus 仍由基础包 `ibus` 提供，不在调用处重复列输入模块路径。
- `grokbot://` 与 `sand://` 的桌面协议注册只写入当前用户的 XDG desktop / MIME 配置，不修改系统级默认配置。
- 音频客户端库进入 AppImage 后仍依赖宿主存在可用的用户音频会话与实际输出设备。

## 2026-10-30：按直接下载标准重写

- **处理：** 先安装 `grok-bot-bin`，再独立下载官方 DEB，完整程序放入 `AppDir/bin/`；图标和主 desktop 从系统安装结果取得。
- **版本：** 下载和版本记录属于同一次公共调用；打包前读取文本，封装成功后用公共保存入口写 `dist/version.txt`。
- **保留：** 原有音频客户端库、启动兼容和登录回调。2026-09-26 的出声实测作为既有基线保留，本次不声称重写后的包已重新实测。
- **清理：** 构建期 `APPDIR`、额外 sandbox 权限修改、动态图标查询、旧 shared/bin 布局及手工资源链接、旧库路径和工作目录设置、额外收集模式与不剥离开关。以用户最后确认的脚本为定稿，不再改写。
- **文档：** 增加模板差异与固定配置依据，并登记 Electron 直接下载分类。
- **检查边界：** 本次完成语法、公共接口、依赖覆盖、代码行号和文档核对；没有执行新的完整构建或实机运行。图标位置沿用原脚本已使用的官方 DEB 256×256 资源布局，AUR 安装代码按原 DEB 路径展开，未作本次系统安装实测。

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
