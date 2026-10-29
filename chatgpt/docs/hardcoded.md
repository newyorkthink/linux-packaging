# ChatGPT 固定配置依据

核对日期：2026-10-30。本脚本面向隔离的 Arch Linux x86_64 构建环境。

| 固定项 | 当前值 | 依据与用途 |
| --- | --- | --- |
| AUR 包与架构 | `chatgpt-desktop；x86_64` | [固定 .SRCINFO](https://github.com/archlinux/aur/blob/fac212f2e43f029d6c5b336c82d1ebf68da77949/.SRCINFO) 明确指向 OpenAI 官方 Linux amd64 DEB；不是同名第三方聊天壳。 |
| 下载及解包文件 | `chatgpt.deb；chatgpt-unpacked` | 当前应用工作目录内的独立下载及解包结果。 |
| 程序目录与主程序 | `usr/lib/chatgpt；ChatGPT` | 原脚本及 [pkgforge 准备脚本](https://github.com/pkgforge-dev/ChatGPT-Desktop-AppImage/blob/0e52cadeafc0229ea9a55415a70a2abc00d0bf07/get-dependencies.sh) 的实际布局；完整复制到 AppDir/bin。 |
| 图标与主 desktop | `/usr/share/pixmaps/chatgpt.png；/usr/share/applications/chatgpt.desktop` | 同源 AUR 完整安装官方 DEB；pkgforge 脚本直接使用这两个路径。 |
| 应用与窗口类 | `APPNAME=ChatGPT；MAIN_BIN=ChatGPT；STARTUPWMCLASS=ChatGPT` | 保留本应用标识及原有窗口匹配。 |
| 版本字段 | `AppDir/bin/resources/linux-package-metadata.json` 的 `version` | 旧脚本明确读取并核对过该字段；公共 JSON 入口直接使用本次程序包的值。 |
| Qt 删除范围 | `./AppDir/bin/libqt*_shim.so` | 官方原命令；作用及 Plasma 边界见 [官方处理记录](pkgforge-differences.md)。 |
| 运行时 PATH | `/usr/bin:/bin${PATH:+:$PATH}:$APPDIR/bin` | 原有 bwrap 修复原文，保留在运行时 hook；不声明同名构建期变量。 |
| 启动参数 | `--no-sandbox --disable-setuid-sandbox` | 原有 Electron 启动兼容，仅影响应用的 Chromium 沙箱。 |
| 产物 | `dist/chatgpt.AppImage；dist/version.txt` | 保留发布名；封装成功后通过公共保存入口记录版本。 |

原运行依赖由基础包、AUR 声明或应用安装行覆盖。原 Xorg/Xvfb 三项只服务于已移除的内联图形自测，不再追加。历史沙盒和图形故障见 [README](../README.md)，不因此恢复正式构建自测。
