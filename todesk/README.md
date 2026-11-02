# ToDesk AppImage

## 用途与来源

本目录把 ToDesk Linux x86_64 客户端重新封装为单一 AppImage。

- 上游程序：ToDesk 官方 Linux 客户端。
- 版本与校验元数据：AUR `todesk-bin` 的当前 `.SRCINFO`，不固定版本、Tag 或 Commit。
- 程序文件：独立下载本次元数据指向的官方 HTTPS DEB，始终校验原摘要；只有官方文件校验失败时才查同一 URL 的 Internet Archive 快照。
- 构建环境：Arch Linux AnyLinux 容器。
- 打包工具：`quick-sharun`。
- 最终产物与 Release 资产名：`dist/todesk.AppImage`、`todesk.AppImage`。
- 来源版本及完整包版本由公共 AUR 下载入口写入 `work/source-version.txt`、`work/package-version.txt`；成功封装后由公共入口写入 `dist/version.txt`。

完整官方目录放在 `AppDir/bin/todesk/`，保留 `bin / lib / res / config` 的相对布局。`config` 空目录按 AUR 的安装行为补回；`!strip` 沿用 AUR 要求。当前实际核对的官方 DEB 为 4.9.8.1，固定快照仅用于记录证据，构建仍动态查询当前 AUR 来源。

## 打包方式

ToDesk 采用 **Arch Linux + quick-sharun**。主流程遵守仓库标准，专属检查和运行目录准备分别保存在 `patches/prepare_appdir.sh` 与 `patches/90-todesk-runtime.hook`。

1. 安装公共基础工具，再安装 `todesk-bin` 及原有运行依赖、输入模块和 DEB 工具；`libpipewire` 对应当前真实 ELF 的直接依赖，不切换系统音频服务。
2. 在项目目录准备 `work / AppDir / dist`。
3. 单行调用 `common/aur/download_deb_source.sh`，传入 `Mozilla` 客户端标识、同 URL 归档回退、DEB 检查及两个版本输出路径；应用不再自行解析、source 或写入来源版本元数据。
4. 通过公共归档入口解包同一份 DEB，完整复制 `opt/todesk` 到 `AppDir/bin/`，不从系统安装目录取得最终程序。
5. 准备脚本补回配置目录，核对四入口、GTK3 输入模块及托盘库，一次汇总直接动态库错误。官方 desktop 只在工作目录的副本中完整改为 `Exec=ToDesk`，避免把新版 `env` 后的赋值残留为程序参数。
6. 设置主程序、系统图标、便携 desktop、输出名称、GTK 部署、`NO_STRIP` 与路径映射；版本由公共入口读取同次下载记录。
7. 同一次 quick-sharun 收集四个真实入口、完整程序目录、`pulseaudio` 和三项 AppIndicator / dbusmenu 库；GTK3 输入模块由工具按 `DEPLOY_GTK=1` 收集。
8. 生成包内中文 locale，保留工具已写入的 `.env`，并核对四个包装入口及对应真实程序。
9. 安装公共入口提供的完整包版本标记和独立运行 hook；hook 保留已有配置、注册信息及用户目录布局，按包版本刷新程序副本。
10. 使用 `quick-sharun --make-appimage` 封装，随后调用公共保存入口写入版本。

AppRun 继续由工具生成。不固定封装宿主 GPU 驱动，不强制设置 `LIBVA_DRIVER_NAME=iHD`；官方私有编码库及新增 `lib/` 目录完整保留，实际硬件加速仍取决于宿主显卡与驱动。

## 维护说明

- [模板差异与来源依据](./docs/template-deviations.md)
- [固定配置及故障证据](./docs/hardcoded.md)

## 单 AppImage 多入口

quick-sharun 默认 `AppRun` 会先检查启动文件名是否与 `AppDir/bin/` 中的程序同名。因此只需要一个 AppImage，通过软链接即可得到多个入口：

- `todesk.AppImage`：默认启动 `ToDesk` 图形界面。
- `ToDesk`：启动 `ToDesk` 图形界面。
- `ToDesk_Service`：启动 ToDesk 后台服务组件。
- `ToDesk_Session`：ToDesk 会话组件，通常由后台服务按需拉起。
- `CrashReport`：ToDesk 崩溃处理组件，通常由程序按需拉起。

不需要复制多份 AppImage。

## 可写运行目录

ToDesk 官方 Linux 布局固定使用 `/opt/todesk`，官方排障文档也会直接操作 `/opt/todesk/config/config.ini`。AppImage 挂载内容本身只读，因此不能让服务直接把配置写回 AppImage。

运行时 hook 会把官方程序目录复制到：

```text
${XDG_DATA_HOME:-$HOME/.local/share}/todesk-appimage/runtime
```

服务日志映射到：

```text
${XDG_DATA_HOME:-$HOME/.local/share}/todesk-appimage/logs
```

`/opt/todesk` 与 `/etc/todesk` 通过 path mapping 尝试重定向到上述用户状态目录，其中 `/etc/todesk` 用于持久化 ToDesk 会写入的 `reg.conf`。构建脚本也为 `/var/log/todesk` 配置了用户目录映射，但 2026-09-24 实机运行 `ToDesk_Service` 时仍观察到它直接尝试访问宿主 `/var/log/todesk` 并因普通用户权限不足失败，说明该日志路径并没有被当前映射机制完全拦截。更新 AppImage 后程序文件会按新版本刷新，原有 `config/` 和 `etc/` 状态会保留。

普通便携使用建议让 `ToDesk_Service` 和 GUI 以同一个用户运行，使两者共享同一份运行目录和配置。若用 `sudo` 单独启动服务，`HOME / XDG_DATA_HOME` 通常会切换到 root 环境，从而产生另一份状态目录，因此本项目不把 `sudo` 作为默认启动方式。

## 运行

ToDesk Linux 当前官方说明要求 X11 桌面环境；无桌面/纯 SSH 模式不属于当前 Linux 客户端支持范围。

在 **Linux 终端**、AppImage 所在目录执行。

```bash
# 赋予 AppImage 执行权限
chmod +x todesk.AppImage

# 创建后台服务入口软链接
ln -sfn todesk.AppImage ToDesk_Service

# 启动 ToDesk 后台服务组件；保持该进程运行
./ToDesk_Service

# 启动 ToDesk 图形界面
./todesk.AppImage
```

如果还需要显式入口，可另外创建：

```bash
# 创建 ToDesk GUI 同名入口
ln -sfn todesk.AppImage ToDesk

# 创建 ToDesk Session 入口
ln -sfn todesk.AppImage ToDesk_Session

# 创建 CrashReport 入口
ln -sfn todesk.AppImage CrashReport
```

`ToDesk_Session` 和 `CrashReport` 通常不需要手工启动。

## 系统集成边界

这个 AppImage 面向便携的用户会话运行方式：

- 不主动向宿主 `/opt/todesk` 安装程序文件。
- 不主动创建宿主 `/var/log/todesk`；但 ToDesk_Service 自身仍可能直接尝试访问该路径，普通用户运行时会看到权限相关日志。
- 不创建或修改 `/etc/systemd/system/todeskd.service`。
- 不执行 `systemctl enable/start/restart`。
- 不修改宿主显卡驱动、VA-API 配置、网络、防火墙或其他系统设置。

ToDesk 官方发行版安装包使用 `todeskd.service` 提供系统级后台服务。若需要开机即启动、系统级无人值守或官方 systemd 服务语义，应使用 ToDesk 官方发行版安装方式；本 AppImage 不伪装成系统安装包。

## 当前验证状态

2026-11-02 本次标准化重写完成 478 项隔离验证，覆盖公共旧接口对照、两种摘要、User-Agent、归档回退、主脚本组合顺序，以及运行副本刷新和配置保留。网络、包管理器、依赖收集和封装使用替身；DEB 元数据读取、摘要、解包及目录准备使用真实工具。本轮没有执行完整 AppImage 构建或真实 GUI / 服务。旧版核心远控仍按已实机通过记录，具体范围如下。

2026-09-24 已完成构建和实机核心远控验证：

- GitHub Actions run `35981621428` 的 `Build ToDesk` 已成功完成，`todesk.AppImage` 已生成并发布到 `latest` Release。
- 实机启动 ToDesk 4.9.6.0 GUI 正常，设备代码正常显示，界面进入“已准备好连接”状态。
- `ToDesk_Service` 与 GUI 均可启动。
- 已使用手机端实际连接该设备并完成远程控制，因此 **核心远程控制链路已实机验证通过**。

仍未标记为已验证的功能：

- **音频**：已下载并解包提交 `381d343` 对应的 AppImage。包内有 `pulseaudio` 命令和 `libpulse.so.0`，启动脚本会把包内 `bin` 加入 `PATH`；本次截图也未再出现 `pulseaudio: not found`。执行包内命令查询版本时仍出现 `Couldn't canonicalize binary path, cannot self execute` 警告；包内未发现 `module-*.so`。远程音频尚未实测，不能仅凭这些日志判断音频功能正常或故障。
- **远程打印**：日志出现 `open Todesk_Printer failed`、FUSE 相关提示；当前仅记录为远程打印功能未验证，不为此扩大打包范围。
- **系统特权操作**：出现 `org.freedesktop.DBus.Error.InteractiveAuthorizationRequired`，说明某些需要 Polkit 交互授权的操作在当前普通用户便携运行方式下被拒绝；已验证的核心远控未因此中断。
- **后台服务日志路径**：`ToDesk_Service` 仍会尝试访问宿主 `/var/log/todesk`，普通用户下出现权限不足和日志文件创建失败提示；这没有阻断本次核心远控，但说明当前 path mapping 对该路径不完全生效。
- **系统托盘图标**：核心远控实机验证通过后，i3/X11 桌面没有出现 ToDesk 托盘小图标。成功构建日志确认构建环境安装了 `libappindicator`，但 quick-sharun 收集日志没有看到 `libappindicator3.so.1`、`libdbusmenu-glib.so.4`、`libdbusmenu-gtk3.so.4`；当前构建脚本已改为显式收集这三项，新的托盘显示结果仍需以后续产物实机验证。
- **官方 systemd/root 语义**：AppImage 没有安装官方 `todeskd.service`，因此开机自启、系统级无人值守和官方 root 后台服务语义仍不属于当前验证范围。

启动阶段还观察到 `/tmp/service...` IPC 连接失败提示，但随后 GUI 正常显示、设备在线并且手机端可以完成远程控制，因此当前只记录为启动阶段提示，不把它定性为核心功能故障。


## 修复记录

### 2026-09-24：首次 Actions 在 AUR 源文件校验阶段失败

- 现象：首次正式构建 run `35977062621` 的 `Build ToDesk` 在安装 `todesk-bin 4.9.6.0-1` 时失败；日志显示官方 `https://dl.todesk.com/linux/todesk-v4.9.6.0-amd64.deb` 实际返回 29181 字节 `text/html`，随后 AUR SHA-256 校验失败。失败发生在 quick-sharun 执行之前。
- 根因：AUR 元数据中的版本、官方 URL 和 SHA-256 本身完整，但 ToDesk 官方 CDN 对该次 GitHub Actions 请求没有返回对应 DEB；单纯增加浏览器 User-Agent 不能解决，因为当前 AUR 本身已经使用 `wget -U 'Mozilla'`。
- 修复：`build_todesk.sh` 不再直接 `yay -S todesk-bin`。脚本改为读取当前 AUR `.SRCINFO`，动态取得版本、pkgrel、x86_64 官方 URL、SHA-256 和运行依赖；优先下载官方 DEB，失败后查询同一官方 URL 的 Internet Archive 历史响应，并逐个使用当前 AUR SHA-256 校验，只有完全一致的文件才允许继续解包。当前 Gentoo gentoo-zh 的 ToDesk 4.9.6.0 ebuild 也使用该官方 DEB 的 Internet Archive 快照作为来源，作为这一回退方向的独立参考。
- 安全边界：没有使用 `SKIP`、没有修改 AUR 校验值、没有固定 ToDesk 版本，也没有把第三方内容当成“等价包”；归档回退必须与当前 AUR 记录的官方文件 SHA-256 完全一致。
- 提交前检查：已对修改后的 Bash 执行 `bash -n`，并核对 AUR 元数据解析、依赖安装、官方直连、归档回退、DEB 类型/SHA-256 二次校验和原有 quick-sharun 多入口流程。新的 GitHub Actions 构建和实际远控功能仍以提交后的正式产物为准。


### 2026-09-24：Internet Archive 回退变量拼写错误

- 现象：正式构建 run `35979009601` 已正确识别官方 CDN 返回的 29181 字节 HTML，并进入 Internet Archive 回退分支，但随后在 `build_todesk.sh: line 99` 以 `SOURCE_URL_ENCODED: unbound variable` 退出。
- 根因：URL 编码结果误写入变量 `SOURCE_URL_ENCODD`，下一行读取的是 `SOURCE_URL_ENCODED`；在 `set -u` 下因此立即失败。这不是缺少依赖，也不是 Internet Archive 本身失败。
- 修复：统一变量名为 `SOURCE_URL_ENCODED`，并在生成 CDX 查询 URL 前增加非空检查。AUR 运行依赖和下载方案不需要继续扩大：日志已经确认 `gtk3`、`libappindicator-gtk3`、`noto-fonts-cjk` 与额外的 `fcitx5-gtk` 均能正常安装。
- 核对：重新检查了当前 AUR `todesk-bin 4.9.6.0-1` 的 x86_64 官方 URL 与 SHA-256；Gentoo gentoo-zh 当前 `todesk-4.9.6.0` ebuild 也使用同一官方 DEB 的 Wayback 快照 `20260908130616`，因此继续采用“同一官方 URL + AUR SHA-256 强校验”的归档回退，不新增其他第三方安装包，也不跳过校验。
- 验证边界：本次根据失败日志和脚本逐项静态核对变量、依赖、官方直连、CDX 查询与 SHA-256 回退链路；新的 Actions 构建及最终 AppImage 运行结果仍以提交后的正式构建为准。


### 2026-09-24：官方 DEB 不包含空 config 目录

- 现象：正式构建 run `35979645432` 已成功从 Internet Archive 下载 114.2 MiB 的官方 ToDesk 4.9.6.0 DEB，并通过当前 AUR SHA-256；解包后在布局检查阶段报 `缺少 ToDesk 配置目录：.../opt/todesk/config`。
- 根因：官方 DEB 本身不包含这个空目录。当前 AUR `todesk-bin` 的 PKGBUILD 启用 `emptydirs`，并在 `package()` 中显式创建 `/opt/todesk/config`；之前直接解包 DEB 后错误地把该空目录当成官方 DEB 必须自带的内容。
- 修复：解包并确认 `/opt/todesk` 存在后，按 AUR 的实际打包行为显式创建空的 `/opt/todesk/config`，再继续四个入口、资源与 quick-sharun 校验。没有新增下载包，也没有放宽 SHA-256 校验。
- 运行状态补全：现有 Flatpak/Nix 打包实现都表明 ToDesk 服务会持久化 `/etc/todesk/reg.conf`；本 AppImage 默认不写宿主 `/etc`，因此把 `/etc/todesk` 一并映射到用户状态目录的 `etc/`。
- 依赖核对：本次 Actions 只确认 AUR 声明的 `gtk3`、`libappindicator-gtk3`、`noto-fonts-cjk` 以及本项目额外的 `fcitx5-gtk` 能正常安装；随后 run `35980957997` 进入 quick-sharun 后又暴露出 AUR 未声明的 XCB helper 直接依赖，因此这里不再把“无需其他软件包”作为结论。


### 2026-09-24：补齐 ToDesk XCB helper 运行库

- 现象：正式构建 run `35980957997` 已完成 AUR 元数据解析、官方 DEB 归档回退、SHA-256 校验、DEB 解包和 AppDir 元数据准备；进入 quick-sharun 后，`ToDesk` 主程序直接报缺 `libxcb-util.so.1`、`libxcb-keysyms.so.1`、`libxcb-icccm.so.4`。
- 根因：当前 AUR `todesk-bin` 只声明 `gtk3`、`libappindicator-gtk3`、`noto-fonts-cjk`，没有把 ToDesk 闭源 ELF 实际依赖的 XCB helper 库列进 `depends`。这不是 quick-sharun 自身错误。
- 修复：构建环境显式补 `xcb-util`、`xcb-util-keysyms`、`xcb-util-wm`；同时补齐同一 Qt/XCB 运行族的 `xcb-util-image`、`xcb-util-renderutil`、`xcb-util-cursor`，避免下一步只因同族库继续中断。Arch 官方包文件列表确认：`xcb-util` 提供 `libxcb-util.so.1`，`xcb-util-keysyms` 提供 `libxcb-keysyms.so.1`，`xcb-util-wm` 提供 `libxcb-icccm.so.4`。
- 防止反复构建：在 quick-sharun 前新增四入口 `ldd` 汇总检查，一次列出 `ToDesk / ToDesk_Service / ToDesk_Session / CrashReport` 仍缺的直接动态库；如果还有缺库，单次 Actions 日志即可看到完整列表。
- 范围：只增加构建环境中的 XCB 运行库和依赖预检，不修改下载回退、SHA-256、安全边界、`/opt/todesk`/`/etc/todesk` 持久化或多入口逻辑。


### 2026-09-24：实机远控验证

- 验证结果：ToDesk 4.9.6.0 GUI 正常启动并显示设备代码，手机端已经实际连接并完成远程控制，核心远控功能确认可用。
- 运行日志：`ToDesk_Service` 仍会直接尝试访问 `/var/log/todesk` 并出现普通用户权限不足；当前日志路径映射不能描述成“已经完全重定向”。
- 非阻断提示：`pulseaudio: not found`、`InteractiveAuthorizationRequired`、`Todesk_Printer`/FUSE 以及启动阶段 `/tmp/service...` IPC 提示均未阻断本次远控。
- 验证边界：音频、远程打印、官方 systemd/root 后台服务语义尚未验证；在这些功能有明确需求前，不为消除日志提示继续扩大 AppImage 依赖或修改宿主系统。


### 2026-09-24：补齐 AppIndicator 托盘运行库

- 现象：ToDesk 4.9.6.0 GUI、设备代码、手机连接和实际远程控制均正常，但 i3/X11 桌面没有出现 ToDesk 托盘小图标。
- 核对：AUR `todesk-bin` 已声明 `libappindicator-gtk3`；成功构建日志也确认 Arch 构建环境安装了 `libappindicator`，但 quick-sharun 的实际收集日志没有看到 `libappindicator3.so.1`、`libdbusmenu-glib.so.4`、`libdbusmenu-gtk3.so.4` 被收入 AppImage。
- 修复：保持现有 AUR 依赖不变，在同一次 quick-sharun 调用中显式加入 `/usr/lib/libappindicator3.so.1`、`/usr/lib/libdbusmenu-glib.so.4`、`/usr/lib/libdbusmenu-gtk3.so.4`，并在收集前检查文件存在，避免库名变化时静默生成缺托盘支持的包。
- 边界：本次只修 AppImage 内的托盘运行库收集，不修改 i3 配置。若新产物仍不显示托盘，再单独核对 i3 当前 bar 是否提供 AppIndicator/StatusNotifier 托盘宿主。


### 2026-09-24：补入 PulseAudio 命令并复用公共 DEB 解包

- 现象：此前实机启动时出现 `pulseaudio: not found`；只靠构建日志中已安装 `libpulse`，不能确认 AppImage 是否包含同名服务命令。
- 产物核对：下载并解包提交 `3b7e5e3` 对应的 `latest` 资产 `todesk.AppImage`，SHA-256 为 `b7d3fa02150f95a9a19e7e533fd4ecda2fa1f902bc4d65552bd4dd9181b4e32f`，与 Release 和成功构建 run `35987119142` 日志一致。产物内有 `libpulse.so.0`、`libpulse-simple.so.0`，但没有 `pulseaudio` 可执行文件；ToDesk 程序包含 `pulseaudio --start --log-target=syslog` 字符串，生成的 `AppRun.sh` 会把包内 `bin` 置于 `PATH` 前面。
- 修改：`todesk/build_todesk.sh` 显式安装 Arch `pulseaudio`，并把 `/usr/bin/pulseaudio` 加入现有的同一次 `quick-sharun` 调用，让上游命令能从包内 `bin` 查找。同时安装 `dpkg`，将手工 `ar` / `tar` 解包替换为现有的 `common/archive/extract_archive.sh`；官方 DEB 下载与 SHA-256 校验保持原样。
- 验证边界：本次产物检查确认旧包缺少该命令；脚本改动仅完成静态检查。新 AppImage 是否实际包含可用的 `pulseaudio`、是否能连接宿主音频会话以及远程音频是否正常，均需以后续产物和实机结果为准。该修改不代表音频功能已通过验收。


### 2026-09-24：新版 AppImage 产物与启动日志复核

- 产物：下载的 `todesk.AppImage` SHA-256 为 `bc77e0217c5db7054942e20594475f064c10b4ca5f2866c9ecc8e19046c6cda8`，与 Release 标注的校验值一致；包内已包含 `pulseaudio`。
- 实机截图：GUI 能打开；`ToDesk_Service` 仍提示无法写入 `/var/log/todesk`，启动时仍有 `/tmp/service...` 连接失败、`Todesk_Printer` 和 FUSE 提示。截图未显示这些提示阻断 GUI。
- 验证边界：此前核心远控实测针对旧产物；这份新产物尚无远程控制和远程音频实测结果。当前先记录提示，暂不据此修改打包脚本或宣称相关功能已验证。


### 2026-09-24：AUR 来源与归档回退复用公共入口

- 现象：`build_todesk.sh` 虽已调用公共单文件下载与 DEB 解包入口，仍自行克隆 AUR、解析 `.SRCINFO`、查询 Internet Archive 并遍历快照；来源选择和摘要回退逻辑没有在公共入口复用。这是代码职责重复，不是已确认的实机故障。
- 修改：新增 `common/aur/resolve_deb_source.sh` 统一获取并解析 AUR 当前架构专用 DEB 来源、摘要和依赖；新增 `common/download/download_verified_with_wayback.sh` 复用既有 `download_file.sh`，只对同一官方 URL 的历史快照使用原 AUR SHA-256 严格校验。`build_todesk.sh` 保持原有安装、下载、解包顺序，改为单行调用上述两个入口；公共接口同步写入公共 README 和维护指南。
- 提交前核对：三个涉及的 Bash 脚本通过 `bash -n`；仓库外临时样例已覆盖 AUR 元数据解析、官方直连、同 URL 归档回退、错误摘要拒绝和非 DEB 拒绝。ShellCheck 仅报告原脚本已有的两处 SC2155 和一处 SC2016；未进行新脚本的正式 Actions 构建或新产物实机运行。
- 验证边界：本次仅复用下载流程，不据此宣称音频、打印、托盘或新产物远控功能已经通过实测。

### 2026-11-02：标准化重写并接入完整公共 AUR 下载入口

- 现象：run `41420975694` 的 ToDesk 下载收到约 985 字节的非 DEB 内容，摘要失败后没有可用归档；故障发生在依赖收集之前。
- 核对：当前 AUR `4d59901f7b559b0b363819ba9a9150878a4b1935` 的 PKGBUILD 使用 `wget -U 'Mozilla'`。本次完整读取官方 4.9.8.1 DEB，长度 115086264 字节，SHA-256 为 `a257916c32ca792826dd1027596395278259050fee42ca8fd0a0aaa8851940e1`，与同次 AUR 元数据相同；只读取包内容，没有运行安装脚本或程序。
- 公共复用：扩展现有 AUR 下载入口的可选 User-Agent、归档和版本文件参数；旧三参数调用保持原行为。ToDesk 主脚本单行调用该入口，不再展开解析、source、printf 或自行组合摘要下载。
- 标准重写：保留先安装应用及依赖、再独立下载和解包的两个阶段；完整程序迁到 `AppDir/bin/todesk`，版本读取与保存均复用公共入口。
- 新版布局：真实 ELF 直接依赖 `libpipewire-0.3.so.0`，构建安装 `libpipewire`；官方 desktop 的 Exec 已使用 env，便携副本完整替换整行，避免旧的首词替换留下环境赋值和绝对路径。
- 既有行为：保留四入口、PulseAudio 命令、托盘库、中文环境、No Strip、按包版本刷新副本和保留配置的逻辑。适配嵌套 ELF 被工具包装后的布局时，先解除临时副本中的包装器硬链接，再复制四个独立真实 ELF。
- 提交前验证：478 项隔离验证通过，包含旧调用方接口、SHA-256 / SHA-512 官方及归档下载、错误参数、元数据拒绝、完整主流程替身验证，以及同版本不刷新、升级保留配置和注册信息。五份 Shell 文件语法核对通过。
- 验证边界：网络、包安装、quick-sharun 和 locale 生成使用替身；真实工具完成摘要、DEB 读取、解包和目录准备。没有运行 ToDesk GUI、服务或完整真实 AppImage 构建；旧版核心远控的已实机结论继续保留，不把本次静态与隔离结果扩展为新产物实机验收。
