# PeaZip 模板差异

构建阶段沿用 [Qt DEB linuxdeploy 模板](../../Templates/appimage/linuxdeploy-qt-deb.sh)。以下是 PeaZip 的来源、运行入口和已验证的专属处理。

| 阶段 | 处理 | 依据与影响 |
| --- | --- | --- |
| 下载并准备应用 | 公共组合入口下载官方 GitHub Release 的 Qt6 amd64 DEB，校验 SHA-256 和包身份，安装并解包同一份 DEB。 | 版本来自匹配资产所在的 Release。原有 DEB 布局供应用与 linuxdeploy 共用。 |
| 准备桌面资源和运行库 | 中文语言文件仅在缺少 UTF-8 BOM 时补入。临时将两个官方绝对链接改为等价相对链接。 | 保留官方中文正文和部署时所需的相邻资源路径。BOM 依据见[上游翻译说明](https://peazip.github.io/peazip-translations.html)。 |
| 准备桌面资源和运行库 | 收集随包 Qt6Pas、Adwaita 样式、GTK3 主题及其运行库。继续用原 GCC 命令编译 `peazip_utf8_fix.c`。 | 保留已验证的 Qt6 查找路径和 UTF-8 兼容层，见[稳定基线](../README.md#已实机确认的稳定基线禁止改动)。 |
| 准备 AppRun | 保留 desktop Exec 解析、已验证的路径、显示配置和 UTF-8 兼容层预加载。 | Qt6 旧产物以顶层 AppRun 启动。兼容层只用于 PeaZip 主进程，加载后恢复原环境。 |
| 核心打包 | 使用原 Qt6 扫描命令。扫描前暂移 `res/bin`，优先从上游目录查找 Qt6Pas。 | 旧 32 位后端依赖 libncurses.so.5，移出后可以独立完成 Qt6 部署。 |
| 整理产物 | 恢复归档后端，移除 `usr/bin/peazip` 转发链接，并将 `res/share` 换成实体目录。 | 保留主程序相邻资源，避免 7-Zip 因 SquashFS 中目标含 `..` 的链接而拒绝解包。 |

显示与启动参数见[固定配置](./hardcoded.md)。完整故障和修复历史见[应用 README](../README.md)。
