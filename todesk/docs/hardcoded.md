# ToDesk 固定配置依据

这里只记录本应用实际使用的路径、名称和参数；不把这些值推广给其他应用。程序版本、pkgrel、下载地址和摘要从当前 AUR 动态取得，不固定到本次检查的快照。

## 配置及依据

| 配置 | 取值与用途 | 原始依据或故障 |
| --- | --- | --- |
| 架构 | x86_64；由公共工作区入口检查。 | 当前构建及原有远控验证均针对 x86_64；AUR 其他架构分支不因此启用。 |
| 应用及入口 | APPNAME / MAIN_BIN / STARTUPWMCLASS 使用 ToDesk；产物名 todesk.AppImage。 | 官方 DEB 的四入口为 ToDesk、ToDesk_Service、ToDesk_Session、CrashReport。主入口与旧版生成的 ToDesk 标识一致；未新增窗口修补。 |
| 图标 | /usr/share/icons/hicolor/512x512/apps/todesk.png。 | 实际 DEB 含该图标；AUR package() 完整安装 usr/share/icons，构建读取系统安装结果。 |
| desktop | 系统来源 /usr/share/applications/todesk.desktop；工作副本 work/todesk.desktop。 | 当前官方 Exec 原文为 `Exec=env LIBVA_DRIVER_NAME=iHD LIBVA_DRIVERS_PATH=/opt/todesk/bin GDK_BACKEND=x11 /opt/todesk/bin/ToDesk`。旧的首词替换会残留参数，因此只在工作副本把完整 Exec 改为 ToDesk，TryExec 按既有处理调整。 |
| 完整程序 | AppDir/bin/todesk，内部保留 bin、lib、res、config。 | DEB 的 opt/todesk 布局及 AUR 的空 config 目录要求；旧构建曾因误认为 DEB 自带 config 而失败。 |
| 安装来源缓存 | 公共入口为本次安装创建临时 sources / build 目录；只对这次 yay 设置 SRCDEST 和 --builddir。 | AUR 安装收到 989 字节 HTML；makepkg 优先查构建目录中的同名文件，所以需要新目录和来源缓存一起使用。文件名来自同次 .SRCINFO，支持 source 别名；不固定构建用户、版本、URL、摘要或旧缓存路径。退出后清理本次目录。 |
| 下载器 | aria2c，仅由 ToDesk 的两个公共调用显式传入；构建阶段安装标准 aria2。 | wget 与默认 aria2c 均有正式构建摘要失败记录。当前通过公共入口读取仓库 HTTP 配置；原地址使用该配置，备用源站使用公共默认 curl。后续正式 ToDesk job 已确认安装预取和独立打包下载均从官方备用源取得并校验 DEB，完整构建与发布通过。 |
| 客户端标识 | 使用 [公共配置](../../common/config/download/aria2.conf) 中的模拟浏览器标识；显式公共参数仍可覆盖。 | 原文来自 [P3TERX/aria2.conf 固定快照](https://github.com/P3TERX/aria2.conf/blob/9cc45956ceee02d553adff67a7e296f06fd62946/aria2.conf#L167)，不表示维护者的实际系统。此前 `--no-conf` 未覆盖配置中的 HTTP 请求设置；这是已核实的差异，不是已确认的唯一故障原因。 |
| 官方备用源站 | `https://update.todesk.com`，只用于 ToDesk 原地址下载失败时。 | 保留 AUR 提供的文件路径和当前原摘要。完整 DEB 校验、正式构建与发布已通过，证据见 [README 成功基线](../README.md#当前验证状态) 和[正式通过记录](../README.md#2026-11-03官方备用源正式构建与发布通过)。 |
| 下载连接与分段 | 公共配置使用 16 连接、16 分段；最小分段和分块大小均为 1M。 | 标准 aria2 1.37.0 的实际参数帮助确认最大连接数为 16、大小下限为 1048576 字节；[官方手册](https://aria2.github.io/manual/en/html/aria2c.html) 提供参数定义。真实下载按原摘要校验；不固定 ToDesk 或工具包版本。 |
| NO_STRIP | 1。 | AUR !strip 注释记录部分闭源 ELF 无正常 sections，禁止在本次重写中剥离。 |
| DEPLOY_GTK | 1。 | 当前真实入口直接依赖 GTK3；IBus / Fcitx5 GTK3 模块已由原构建要求保留。 |
| 托盘和声音 | pulseaudio、libappindicator3.so.1、libdbusmenu-glib.so.4、libdbusmenu-gtk3.so.4。 | 旧实机存在 pulseaudio 命令缺失及 i3 托盘未显示的记录；继续显式收集，不据此宣称音频或托盘已实机验收。 |
| libpipewire | 安装 Arch 客户端库包；不替换音频服务。 | 当前 ToDesk、Service、Session 的 DT_NEEDED 含 libpipewire-0.3.so.0；官方包新增 lib/ 兜底目录。 |
| 构建 PATH_MAPPING | `/opt/todesk:${SHARUN_DIR}/bin/todesk`。 | 让工具收集 path-mapping 库，并与新完整目录对应；运行时由 hook 改为包装入口及可写副本映射。 |
| 运行状态 | XDG_DATA_HOME 或 HOME/.local/share 下的 todesk-appimage/runtime、logs、etc。 | 已验证的便携目录方案，config 与 reg.conf 在升级时保留；HOME 不可用时沿用 /tmp/todesk-appimage-UID 后备。 |
| 包版本标记 | share/todesk-appimage/package-version，内容 pkgver-pkgrel。 | 沿用包版本变化才刷新程序副本的逻辑；由公共入口输出，不在应用重新解析版本。 |
| 运行工作目录 | 可写副本的 bin；SHARUN_EXTRA_LIBRARY_PATH 使用同一目录。 | 官方程序与私有编码库相邻；运行路径语义沿用既有实现，不全局向宿主导出 LD_LIBRARY_PATH。 |

## 固定来源

AUR [PKGBUILD](https://github.com/archlinux/aur/blob/4d59901f7b559b0b363819ba9a9150878a4b1935/PKGBUILD)、[.SRCINFO](https://github.com/archlinux/aur/blob/4d59901f7b559b0b363819ba9a9150878a4b1935/.SRCINFO) 和 [维护脚本](https://github.com/archlinux/aur/blob/4d59901f7b559b0b363819ba9a9150878a4b1935/todesk.install) 只作为核对快照。完整包摘要及实际检查结果见 [README 修复记录](../README.md#修复记录)，通用与专属代码的边界见 [模板差异](./template-deviations.md)。
