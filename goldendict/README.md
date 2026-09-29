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

- 2026-09-28：用户确认此前产物的托盘图标能够显示；随后报告同一本词典反复建立索引、启动慢。尚未确定根因，不能声称更换 DEB 已解决此问题。
- 按用户要求切换官方 DEB 路线，核对 Shell 语法、包内路径和完整差异。未监控 Actions；新的构建及实机运行结果未验证。

- 官方 DEB 路线首次构建失败在 Qt 插件的 `qmlimportscanner`：改用 DEB 时漏装 `qtdeclarative5-dev-tools`，且未指定 `QT_SELECT=qt5`。现补齐 Ubuntu 官方扫描工具并显式选择 Qt5；这些工具只用于依赖扫描，不编译应用或依赖。修复后仅做静态检查，未监控后续 Actions，构建结果待验证。
- 2026-09-28：Kali Linux + i3wm 实机排查确认，外层 AppImage 遗留的 `GCONV_PATH` 指向其临时挂载目录中的 `lib/gconv`，使系统 `/usr/bin/iconv` 报告不支持 UTF-16，并导致 GoldenDict 词典正文无法显示。用户在独立子 Shell 中清除外层环境后重新启动同一 `goldendict.AppImage`，正文恢复正常，证明词典文件和索引本身可用。
- 当前修复只在 GoldenDict 的根 `AppRun` 中清除 `GCONV_PATH`，不改动现有 `LD_LIBRARY_PATH`、`LD_PRELOAD` 或其他启动环境。已核对 Shell 语法和完整差异；新构建产物及其实际运行结果仍待验证。
- 2026-09-28：用户重新下载最新 `goldendict.AppImage` 并在 Kali Linux + i3wm 实机确认，现有词典能够正常查询，英文和中文正文均完整显示，说明 `GCONV_PATH` 修复有效。
- 原版 GoldenDict 仅提供默认、Modern、Lingvo 和 Babylon 显示风格，没有内置黑色主题；当前打包保持上游默认界面，不强制修改 Qt 主题或词典正文 CSS。
- 2026-09-29：Linux 实机确认，使用 `Qt Multimedia` 时英文 OGG 与个别 WAV 可发音，但多数粤语 WAV 无声；切换到 `FFmpeg+libao` 后包括英文在内的全部音频无声。对 SHA256 为 `091ac09a617a6a1baf06c43162fcd35aeb808f87a17e9118bd903430c5273a75` 的 Release 成品解包核对后确认，包内有 `libao.so.4`，却没有它动态加载的 `ao/plugins-4` 输出模块，而且该库仍写死宿主 `/usr/lib/x86_64-linux-gnu/ao/plugins-4`。因此 FFmpeg 已能解码 PCM，但 libao 无法打开实际输出驱动。
- 上一版修复在 `build_goldendict.sh` 中显式安装官方 `libao4`，复制其 `libpulse.so`、`libalsa.so` 和 `libasound.so.2`，并把 `libao.so.4` 的宿主插件目录等长重定位到由 `AppRun` 保留的包内目录描述符路径。对 SHA256 为 `00624bfd5b5147879a8f6d627f8648e2f39afd5c57e5787066fd9845f86737d5` 的新 Release 实机复测确认，`libpulse.so` 已能从包内路径找到，但因漏带其直接依赖 `libpulse-simple.so.0` 而加载失败，随后回退 ALSA 并报 `snd_pcm_dmix_open unable to open slave`。
- 本次只补入 Ubuntu 官方 `libpulse-simple.so.0`，保留现有 libao 路径重定位、Qt、GStreamer、中文环境及其他已生效内容不变。该改动不修改词典、WAV、用户配置或播放器选择；`qview.AppImage` 的 Qt 符号冲突和 locale 警告属于独立问题，不纳入本次修复。已完成 Shell 语法和完整差异核对；新构建及真实 Linux 环境中的播放结果仍待验证，提交后不监控 Actions。
