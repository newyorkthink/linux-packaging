# GoldenDict

本目录使用 **Ubuntu 24.04 官方仓库的原版 GoldenDict DEB**，只重新封装为 `goldendict.AppImage`。与已有 `goldendict-ng/` 分开维护。

## 来源与打包

- 通过 Ubuntu 官方 APT 仓库安装并下载 `goldendict`，版本随该发行版仓库更新，不锁软件版本；`version.txt` 记录实际 DEB 版本及发行版修订号。
- Ubuntu 26.04 的同名包已是转向 GoldenDict-ng 的过渡包，因此原版保持使用 Ubuntu 24.04。来源：[Ubuntu 24.04](https://packages.ubuntu.com/noble/goldendict)、[Ubuntu 26.04](https://packages.ubuntu.com/resolute/goldendict)。
- **禁止在本项目自行编译 GoldenDict、libao 或其他依赖。** 已删除此前的源码下载、qmake/make、autotools 和源码补丁步骤；Qt 的 qmake 仅供官方 linuxdeploy Qt 插件查询安装路径，不用于编译。
- 完整解包官方 DEB，保留主程序、翻译、帮助、desktop、图标及许可证；依赖由 Ubuntu 软件包提供，linuxdeploy 和官方 Qt/GStreamer 插件收集运行库。打包工具使用官方发布产物或官方脚本，不自行编译。
- `libao` 继续使用 Ubuntu 官方 `libao4`，不自行编译；构建只带入其 FFmpeg 后端实际需要的 PulseAudio、ALSA 输出模块及其运行库，不复制完整系统插件树。
- 使用原有两阶段 linuxdeploy、公共路径整理和官方 appimagetool / Type 2 runtime。独立 Job 完成后立即更新 latest Release 的 `software_versions.json`。
- 构建仅重建本项目的 `source/`、`AppDir/` 和 `dist/` 临时目录，不作用于用户的词典、配置或索引。

## 中文与用户数据

- 保留官方包中文翻译，附带 Qt 中文翻译、文泉驿字体和中文 locale；通过上游支持的程序旁 `locale` / `help` 回退目录访问包内资源，不修改主程序二进制。
- 保留 Qt5 IBus、Fcitx5 和 compose 输入插件；输入法服务由宿主桌面提供，沿用会话选择。
- 配置与索引遵循官方 DEB 的上游/发行版默认行为，不重定向 HOME，不创建强制便携目录，不清理或覆盖已有数据。词典由用户自行添加。
- 音频、词典格式及简繁转换能力以官方 DEB 为准，不再维护自行编译的 libao 路径补丁；当前只重定位官方 `libao.so.4` 中用于查找动态输出模块的目录，不覆盖用户的播放器选择。首次切换软件版本可能需要重建索引，但不能把每次启动都重建视为正常。

## 验证记录

- 2026-09-28：Kali Linux + i3wm 实机排查确认，外层 AppImage 遗留的 `GCONV_PATH` 指向其临时挂载目录中的 `lib/gconv`，使系统 `/usr/bin/iconv` 报告不支持 UTF-16，并导致 GoldenDict 词典正文无法显示。当前只在 GoldenDict 根 `AppRun` 中清除 `GCONV_PATH`，不改动现有 `LD_LIBRARY_PATH`、`LD_PRELOAD` 或其他启动环境；重新下载最新 `goldendict.AppImage` 后实机确认英文和中文正文均可正常显示。
- 2026-09-28：用户确认托盘图标能够正常显示。原版 GoldenDict 仅提供默认、Modern、Lingvo 和 Babylon 显示风格，没有内置黑色主题；当前打包保持上游默认界面，不强制修改 Qt 主题或词典正文 CSS。
- 2026-09-29：音频排查确认，FFmpeg 本身能够正常解码 WAV / OGG；此前无声的根因是包内 `libao.so.4` 缺少其动态加载的 `ao/plugins-4` 输出模块，补入 PulseAudio / ALSA 模块后又确认 `libpulse.so` 还直接依赖 `libpulse-simple.so.0`。
- 最终修复保留 Ubuntu 官方 `libao4`，带入 `libpulse.so`、`libalsa.so`、`libpulse-simple.so.0` 和 `libasound.so.2`，并将 `libao.so.4` 的宿主插件目录等长重定位到由 `AppRun` 保留的包内目录描述符路径；不修改词典、音频文件、用户配置或播放器选择。
- 2026-09-29：Kali Linux + i3wm 实机确认，使用 `FFmpeg+libao` 时粤语 WAV 与英文 OGG 均可正常发音；日志显示 WAV / OGG 已成功解码，并由 `ao_open_live(): PulseAudio Output` 正常打开 PulseAudio 输出。此前的 `Failed to load plugin` 和 ALSA `unable to open slave` 已不再出现。
- 当前日志中的 `libpng iCCP: known incorrect sRGB profile` 以及 Opus `Could not update timestamps for skipped/discarded samples` 属于非致命警告，当前实机播放正常，不需要为此修改音频依赖。
- 对应最终修复提交的 Build AppImages #846 与监督工作流均已成功完成。
- 此前曾报告同一本词典反复建立索引、启动慢；该问题尚未确认根因，不能据此声称已由本次 DEB、正文或音频修复解决。
