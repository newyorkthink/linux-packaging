# GoldenDict

本目录打包原版 [goldendict/goldendict](https://github.com/goldendict/goldendict)，与仓库已有的 `goldendict-ng/` 分开维护，发布资产为 `goldendict.AppImage`。

## 来源与构建

- 在 Ubuntu 24.04 x86_64 上编译官方最新稳定 Release，拒绝预发布版和非正式数字标签；版本、提交和归档 SHA-256 写入构建日志，不锁版本。
- Ubuntu 确实提供 DEB，但其发行版版本可能落后于上游。这里使用 Ubuntu 的 Qt5、QtWebKit 和开发依赖，直接编译上游稳定源码；不编译 Qt、不使用 Arch/AUR 二进制。
- AUR 的 [goldendict](https://aur.archlinux.org/packages/goldendict) 仅用于核对依赖和功能选项，不作为源码或二进制下载源。
- 下载、解包、安装依赖、linuxdeploy 初始化及最终封装调用 `common/`；应用的源码补丁、qmake、make 和 make install 直接写在 `build_goldendict.sh`，关键命令各占一行并有中文注释。
- 编译开启简繁转换、ZIM，保留上游 EPWING、音频等默认功能。FFmpeg 音频后端使用随包编译的 libao；libao 从官方最新正式数字标签解析，输出插件路径改为包内目录，使用宿主 PulseAudio 或 PipeWire-Pulse 音频服务。
- QtMultimedia / QtWebKit 的动态多媒体依赖由官方 `linuxdeploy-plugin-gstreamer` 封装。该工具使用其当前默认分支提交，日志记录来源，不把工具版本混入 GoldenDict 软件版本。
- 使用两阶段 linuxdeploy、官方 Qt/GStreamer 插件以及 `--output appimage`。第二阶段生成入口和 hook 后调用公共路径整理，再用官方 appimagetool 和 Type 2 runtime 生成最终文件。
- 构建会重建本目录下的 `source/`、`AppDir/` 和 `dist/`，不要在这些临时目录保存个人文件。最终仅发布 `dist/goldendict.AppImage`；`dist/version.txt` 在封装成功后写入，独立 Job 随即更新 latest Release 的 `software_versions.json`。

## 中文与数据目录

- 包含上游 `zh_CN.qm`、Qt 中文翻译、文泉驿字体和中文 locale，新配置默认中文界面；已有配置中的界面语言选择仍由 GoldenDict 处理。
- 原版翻译及帮助目录改为相对主程序的 `usr/share/goldendict`，避免依赖宿主 `/usr/share/goldendict`；OpenCC 配置和词库一并打入 `usr/share/opencc`。
- 带入同一 Ubuntu Qt5 的 IBus、Fcitx5、compose 输入插件，不强制切换输入法。中文输入仍需要宿主桌面已有运行的输入法服务及会话设置。
- 保留原版默认配置目录 `~/.goldendict`，不创建强制便携配置目录，也不覆盖已有配置。词典文件由用户在程序内添加，包中不附带商业词典。
- 字体配置同时读取宿主字体和包内中文字体；显示服务、输入法服务与音频服务由宿主提供。

## 验证记录与边界

- 2026-09-28：核对官方源码、安装路径、Shell/YAML/JSON、独立构建选择和完整变更范围；没有通过提交后反复触发 Actions 试错。
- 未监控 Actions，构建及运行结果未验证。中文输入、词典查询、简繁转换、发音、托盘和屏幕取词仍需真实产物实机验证，静态检查不代表这些功能已验证。
- Ubuntu 24.04 构建不承诺兼容比它更旧的系统。原版基于 Qt5/QtWebKit；Wayland 下取词等桌面集成功能受上游及宿主限制。
