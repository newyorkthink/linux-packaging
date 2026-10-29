# Grok Bot 模板差异

核对日期：2026-10-30。通用阶段、注释和空行沿用 [quick-sharun 标准](../../anylinux_projects.md#直接下载安装包的标准模板)。本应用属于 Electron 直接下载，执行先安装应用及依赖、再独立下载的两阶段流程。下载主体保持三行，版本读取位于第一次 quick-sharun 前，成功保存位于最后。

## 采用与不采用

| 处理 | 决定 | 对应代码 | 当前依据、用途与影响 |
| --- | --- | --- | --- |
| 安装阶段 | 采用标准两阶段 | [基础和应用依赖安装](../build_grok-bot.sh#L11-L13) | 先安装 grok-bot-bin 及运行依赖；系统安装用于资源与依赖，最终程序从独立下载的官方 DEB 取得。 |
| 下载和版本来源 | 采用公共入口 | [三行下载命令](../build_grok-bot.sh#L20-L22)；[读取实际下载版本](../build_grok-bot.sh#L50) | 官方 JSON 的 version/debUrl 与 DEB 身份绑定，版本 stdout 重定向文本；不使用可能滞后的 AUR 版本。 |
| 完整程序目录 | 采用标准布局 | [复制程序目录](../build_grok-bot.sh#L28) | 完整复制 opt/Grok Bot 到 AppDir/bin，保留资源相对布局，取消旧 shared/bin 及手工资源链接。 |
| GTK 输入与中文 | 采用标准步骤 | [GTK 部署](../build_grok-bot.sh#L47)；[生成中文环境](../build_grok-bot.sh#L56-L63) | 依赖安装后由工具收集 GTK 输入模块；按模板生成包内中文 locale，不在收集命令中重复列 im-ibus.so / im-fcitx5.so。 |
| 音频及动态加载库 | 保留专属输入 | [完整收集命令](../build_grok-bot.sh#L53)；原文见下方代码块。 | 保留原音频客户端、通知、密钥环和托盘库；出声已有旧包实测，本次保持该依赖范围，不启动宿主音频 daemon。 |
| Electron 启动兼容 | 保留已有处理 | [启动参数 hook](../build_grok-bot.sh#L66-L68) | 保留 --no-sandbox 处理部分系统的 Electron 沙箱启动限制；它关闭 Chromium 沙箱，不宣称所有 AppImage 都必须设置。 |
| 协议与回调 | 保留实际宿主登记 | [公共协议 hook 参数](../build_grok-bot.sh#L71-L80) | 继续登记 grokbot:// 和兼容 sand://，让浏览器登录回调能交给当前 AppImage。 |
| 构建期目录变量 | 不采用 | 未启用 APPDIR / SOURCE_DIR 构建变量。 | 构建路径直接写 AppDir/...；不因保留 hook 而新增目录变量。 |
| 旧布局与额外开关 | 不采用 | 未启用。 | 不再使用额外 chmod、动态 ICON 查询、手工资源链接、SHARUN_EXTRA_LIBRARY_PATH / WORKING_DIR、STRACE_MODE、NO_STRIP 或强制 DEPLOY_PIPEWIRE。 |

## 当前完整收集命令

[构建脚本](../build_grok-bot.sh#L53)：

```bash
quick-sharun AppDir/bin/* /usr/lib/libasound.so.2 /usr/lib/libpulse.so.0 /usr/lib/libpulse-simple.so.0 /usr/lib/libpipewire-0.3.so.0 /usr/lib/pulseaudio/libpulsecommon-*.so /usr/lib/libnotify.so.4 /usr/lib/libsecret-1.so.0 /usr/lib/libayatana-appindicator3.so.1
```

## 来源与验证边界

本次按 grok-bot 及同名候选核实，未发现可确认同一应用的 pkgforge-dev 打包。AUR grok-bot-bin 已核实为同一个 Cursor 官方 Grok Bot。没有采用 pkgforge 专属代码，不创建空的 pkgforge 差异清单，也不把本仓库旧修复标成官方原命令。

AUR 依据：[PKGBUILD 固定提交](https://github.com/archlinux/aur/blob/7ece8a32a4f0be0b828c09eeb7d2eeb671d348e3/PKGBUILD)。最终程序独立来自官方 DEB，不复制 AUR 的 ASAR 托盘注入、系统 AppArmor 安装或 wrapper。固定值见 [配置依据](hardcoded.md)，完整历史见 [README](../README.md)。

本次只做语法、接口、代码原文与行号、依赖覆盖和文档核对，没有进行新的 AppImage 构建或实机运行；已有用户确认的功能仍按各自原记录维护。
