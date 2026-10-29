# Claude Desktop 固定配置依据

## 来源记录与验证边界

本次读取的 [AUR PKGBUILD](https://github.com/archlinux/aur/blob/claude-desktop/PKGBUILD) 的 Git blob SHA 为 `5f6e0d57bc59ed7d6a9ce2ce97e14fa7d62ec33a`。其 x86_64 来源为 Anthropic 的官方 DEB；本次下载用于核对布局的包版本是 `4.29.0`，SHA-256 为 `4aa0f763d6c05ac79502392dd50f5d7f5c455b2f0a405d5bdf1554acd8342a89`，与 AUR 提供的摘要一致。

上述版本和摘要仅为本次来源核对记录，不参与后续构建的版本选择。正式脚本由公共入口读取当前 AUR 元数据，不使用本记录锁版本。下列基础模板参数并非为新故障增加的补丁；没有实际报错的项目如实标明，不编造故障日志。

## 安装包与下载参数

- 为什么固定：第一阶段必须安装应用及真实依赖；第二阶段必须另行下载 DEB。当前 AUR 包名为 `claude-desktop`，项目目标架构为 x86_64。
- 具体内容：安装参数 `claude-desktop fcitx5-gtk dpkg`；下载参数 `claude-desktop x86_64 claude-desktop.deb`。
- 作用：安装应用、Fcitx5 GTK3 模块及 DEB 工具；由公共 AUR 下载入口根据当前来源取得并校验 DEB。原脚本的 23 个基础包由 `common/arch/install_packages.sh --base` 覆盖，未省略其依赖。
- 原始故障依据：原 README 已记录中文输入失效时缺少 `fcitx5-gtk` 的现象、首次构建来源和修复。完整历史保留在 [README](../README.md#变更记录)，本次没有新的安装或下载报错。

## 工作目录、程序目录与产物

- 为什么固定：使用基础模板的 DEB 下载、解包、整目录复制和输出位置；官方包的程序目录由实际 DEB 布局确认。
- 具体内容：`AppDir`、`dist`、`claude-desktop.deb`、`claude-desktop-unpacked`、`claude-desktop-unpacked/usr/lib/claude-desktop/`、`dist/claude-desktop.AppImage` 和 `dist/version.txt`。
- 作用：只清理当前应用目录下的上述构建路径；将独立下载包的完整程序目录放入 `AppDir/bin`，生成稳定命名的产物和版本文件。
- 原始故障依据：旧 README 记录 AUR 将 `/usr/bin/claude-desktop` 改为 launcher 后，旧脚本报“Claude Desktop 的上游安装布局已改变”。新模板从下载 DEB 的真实目录取得程序；旧故障及修复过程继续保留在 README，本次不伪造未取得的完整旧日志。

## 应用名、真实主程序与窗口类

- 为什么固定：官方 DEB 的 desktop 定义应用名和 StartupWMClass，实际程序文件为 `usr/lib/claude-desktop/claude-desktop`。
- 具体内容：`APPNAME=Claude`、`MAIN_BIN=claude-desktop`、`STARTUPWMCLASS=com.anthropic.Claude`。
- 作用：按模板直接赋值，显式指定入口与窗口类；不增加 awk、mapfile 或桌面入口枚举逻辑。
- 原始报错：没有。本次从官方 desktop 读到的原始字段为：

```ini
Name=Claude
Exec=claude-desktop %U
Icon=claude-desktop
StartupWMClass=com.anthropic.Claude
```

官方 desktop 的原注释说明 StartupWMClass 对应 Chromium 根据 package.json desktopName 推导的 Wayland app_id / X11 WM_CLASS，用于桌面按这一条目归组窗口。

## 图标与桌面入口

- 为什么固定：路径来自实际官方 DEB；AUR PKGBUILD 提取其文件 payload。
- 具体内容：`/usr/share/icons/hicolor/256x256/apps/claude-desktop.png`、`/usr/share/applications/com.anthropic.Claude.desktop`。
- 作用：由模板的 ICON 和 DESKTOP 直接指定系统安装后的资源，交给 quick-sharun 收集；不创建替代图标或附加复制步骤。
- 原始报错：没有。两项路径均在本次已校验的官方 DEB 中找到。

## 公共版本读取参数

- 为什么固定：当前批准的模板使用 AUR 安装版本，保持与其他采用 pacman 来源的项目相同的公共接口。
- 具体内容：`read_app_version.sh pacman claude-desktop`。
- 作用：由公共入口去掉 epoch 和 Arch pkgrel；最终产物存在且非空后，再由公共保存入口写入版本文件。
- 原始报错：没有。此项属于用户批准的基础模板参数。

## 未启用的固定配置

pkgforge 的 QEMU / 固件路径、NSPR 环境设置和 asar 修改只保存在 [暂不采用的差异记录](pkgforge-differences.md) 中，没有进入当前构建脚本。后续加入前必须核实官方当前是否仍保留并重新取得针对该处理的授权。
