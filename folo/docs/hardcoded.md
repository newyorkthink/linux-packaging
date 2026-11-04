# Folo 固定配置说明

## 取值来源与适用范围

构建脚本使用正式模板允许替换的应用参数。以下路径、名称和资产模板来自官方 DEB、AUR 配方或原脚本的既有元数据，不固定应用版本或某次下载的摘要。实际版本仍由公共入口动态选择。

- 官方来源：[RSSNext/Folo Releases](https://github.com/RSSNext/Folo/releases)。本次核对的稳定版本为 `desktop/v1.17.0`。
- 官方打包配置：[forge.config.cts](https://github.com/RSSNext/Folo/blob/987e180426228e91d35d99abf445dd5d2f5b337f/apps/desktop/forge.config.cts)，使用 Electron、ASAR 和 DEB maker，真实主程序名为 `Folo`。
- AUR 来源：[folo-bin PKGBUILD](https://github.com/archlinux/aur/blob/f7845044fc4e1b142a334eca9f54390177d1f8b5/PKGBUILD)、[.SRCINFO](https://github.com/archlinux/aur/blob/f7845044fc4e1b142a334eca9f54390177d1f8b5/.SRCINFO)。AUR 安装提供运行依赖、`/usr/share/pixmaps/folo.png` 与 `/usr/share/applications/folo.desktop`；最终程序继续来自第二阶段独立下载的官方 DEB。

## 标签前缀兼容

固定参数为 `--tag-prefix "desktop/"`，用于只匹配 Desktop 发布，并在提取版本前移除该字面前缀。前缀由 Folo 调用方传入，公共代码不含 Folo 仓库、资产名或应用专用分支。

原解析器中 `capture` 的字符串参数原文为：

```text
"^v?(?<version>[0-9]+(?:\\.[0-9]+)+)$"
```

该规则不能直接匹配 `desktop/v1.17.0`。本次在修改前，以官方 Release 元数据离线运行基线 `124f3265d2a325005fb718a026d2b6f2d57ff854` 的原公共解析器，完整结果为：

```text
退出码：1
错误：RSSNext/Folo 没有符合模板的正式 Release 资产：Folo-{version}-linux-x64.deb
```

这是本次离线复现记录，不是历史 Actions 日志或应用运行故障。新参数只在调用方显式传入时生效；旧版 semver 及校验清单调用的结果已作离线对比。

## 程序目录与桌面资源

| 参数 | 取值 | 用途与依据 |
| --- | --- | --- |
| 官方仓库、资产模板 | `RSSNext/Folo`、`Folo-{version}-linux-x64.deb` | 选择官方 Linux x64 DEB；版本和 SHA-256 随同次 Release 动态取得。 |
| DEB 身份 | `folo`、`amd64` | 下载后由公共入口核对包名和目标架构。 |
| 完整程序目录 | `usr/lib/folo` | 独立解包后原样复制，保持 Electron 与资源的相对布局。 |
| 应用名、主程序 | `Folo`、`Folo` | 来自官方产品名及包内真实可执行文件。 |
| 窗口类 | `Folo` | 保留原构建脚本已有的 `STARTUPWMCLASS` 值；本次官方 desktop 本身未声明该字段。 |
| 系统图标 | `/usr/share/pixmaps/folo.png` | 来自 AUR 安装提供的官方 PNG。 |
| 系统 desktop | `/usr/share/applications/folo.desktop` | 来自 AUR 安装提供的官方桌面入口。 |
| 产物名 | `folo.AppImage` | 保持现有 workflow 的发布资产名。 |
| 完整扫描列表 | `AppDir/bin/*`、`/usr/bin/hostname` | 保留现有应用目录扫描，并恢复[旧构建脚本](https://github.com/newyorkthink/linux-packaging/blob/41250121cdaa8c7471ade14596733a63bd0a1df0/folo/build_folo.sh)已有的辅助命令；`hostname` 由基础包 `inetutils` 提供。 |

本次读取官方 DEB 得到的元数据与关键文件记录如下：

```text
Package: folo
Version: 1.17.0
Architecture: amd64
Depends: libgtk-3-0, libnotify4, libnss3, xdg-utils, libatspi2.0-0, libdrm2, libgbm1, libxcb-dri3-0, kde-cli-tools | kde-runtime | trash-cli | libglib2.0-bin | gvfs-bin
usr/lib/folo/Folo
usr/lib/folo/resources/app.asar
usr/share/applications/folo.desktop
usr/share/pixmaps/folo.png
```

官方 desktop 原文为：

```ini
[Desktop Entry]
Name=Folo
Comment=Follow everything in one place
GenericName=RSS Reader
Exec=folo %U
Icon=folo
Type=Application
StartupNotify=true
Categories=Network;News;
MimeType=x-scheme-handler/folo;x-scheme-handler/follow;
```

这些参数属于官方布局和既有元数据，并非新增的故障规避路径。原脚本的自写 AppRun、固定禁用沙盒参数及额外部署开关本次全部移除，不在本文件把它们重新登记为启用项。

## 依赖与验证

原安装清单中已被公共基础包覆盖的工具和运行库继续由 `--base` 提供；其余 30 个原有包保留在模板的应用依赖参数中，并增加 `fcitx5-gtk` 提供对应输入模块。新增的 `folo-bin` 与模板固定的 `dpkg` 分别负责应用安装和 DEB 解包。

实际核对了官方 DEB 的 SHA-256、上述元数据和文件布局，公共入口兼容性与生成器复现通过离线检查。后续已有成功的完整 AppImage 构建记录，2026-11-04 用户实机截图已确认启动、中文界面、深色显示、内容展示和中文输入。具体验收范围与运行观察统一见 [README 实机验证](../README.md#实机验证)。
