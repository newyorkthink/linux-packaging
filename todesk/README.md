# ToDesk AppImage

## 用途与来源

本目录把 ToDesk Linux x86_64 客户端重新封装为单一 AppImage。

- 上游程序：ToDesk 官方 Linux 客户端。
- 版本与校验元数据：AUR `todesk-bin` 的当前 `.SRCINFO`。
- 程序文件：优先从 `.SRCINFO` 当前指向的 ToDesk 官方 HTTPS x86_64 DEB 获取；如果官方 CDN 返回的内容无法通过 AUR SHA-256，则只允许从 Internet Archive 取得同一个官方 URL 的历史响应，并继续要求 SHA-256 完全一致。
- 构建环境：Arch Linux AnyLinux 容器。
- 打包工具：`quick-sharun`。
- 最终产物：`dist/todesk.AppImage`。
- Release 资产名：`todesk.AppImage`。
- 构建版本、官方 URL、pkgrel 和 SHA-256 都从本次 AUR `.SRCINFO` 动态读取，不写死 Version / Tag / Commit；成功生成 AppImage 后把软件版本写入 `dist/version.txt`。

AUR 当前包保留 ToDesk 官方 `/opt/todesk` 布局，主要运行组件包括 `ToDesk`、`ToDesk_Service`、`ToDesk_Session`、`CrashReport`、`bin/*.so*` 和 `res/`。当前官方 DEB 本身不带空的 `/opt/todesk/config`；AUR 通过 `emptydirs` 并在 `package()` 中显式创建该目录，因此本项目直接解包官方 DEB 后也按同样方式补回。AUR 同时明确使用 `!strip`，因此本项目也保持官方闭源二进制和私有库不 strip。

## 打包方式

ToDesk 采用 **Arch Linux + quick-sharun**，不使用 linuxdeploy，也不安装 AppImage 自己的 systemd 服务。

构建过程：

1. 通过仓库统一 Arch 基础环境安装构建依赖。
2. 浅克隆 AUR `todesk-bin` 元数据，并从当前 `.SRCINFO` 动态读取 `pkgver / pkgrel / source_x86_64 / sha256sums_x86_64 / depends`。
3. 按当前 `.SRCINFO` 安装 ToDesk 声明的 Arch 运行依赖，再补 Fcitx5 GTK3 中文输入模块以及 ToDesk 4.9.6.0 实际 ELF 所需的 XCB helper 运行库；IBus 来自统一基础环境。
4. 优先通过公共下载入口取得当前 AUR 指向的 ToDesk 官方 DEB，并在落盘前强制校验当前 AUR SHA-256。
5. 如果官方 CDN 返回 HTML 或其他错误内容，不跳过校验、不降低版本；改查同一个官方 URL 的 Internet Archive 快照，只接受 SHA-256 与当前 AUR 完全一致的那一份。
6. 直接解包已经校验通过的官方 DEB，完整复制其中 `/opt/todesk` 到 `AppDir/shared/bin/todesk/`，保持官方 `bin / res / config` 相对布局。
7. 在同一次 `quick-sharun` 调用中收集 `ToDesk`、`ToDesk_Service`、`ToDesk_Session`、`CrashReport` 和 GTK3 IBus/Fcitx5 输入模块。
8. 不自制 `AppRun`。使用 quick-sharun 默认入口按 AppImage/软链接文件名选择 `AppDir/bin/` 中的同名程序。
9. 加入独立 `zh_CN.UTF-8` locale，并通过 quick-sharun hook 处理固定 `/opt/todesk`、可写 `config` 和服务日志路径。
10. 最终由 `quick-sharun --make-appimage` 生成一个 `todesk.AppImage`。

不固定封装 Intel、NVIDIA 或 AMD 的宿主 GPU 驱动，也不强制设置 `LIBVA_DRIVER_NAME=iHD`。ToDesk 官方随包提供的私有编码相关 `.so` 保持原样，实际硬件加速继续取决于宿主显卡与驱动环境。

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

`/opt/todesk` 和 `/var/log/todesk` 的访问通过 path mapping 重定向到上述用户目录；`/etc/todesk` 同时映射到状态目录下的 `etc/`，用于持久化 ToDesk 会写入的 `reg.conf`。更新 AppImage 后，程序文件会按新版本刷新，但原有 `config/` 和 `etc/` 状态会保留，避免无条件重置设备配置。

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

- 不向宿主 `/opt/todesk` 写文件。
- 不向宿主 `/var/log/todesk` 写日志。
- 不创建或修改 `/etc/systemd/system/todeskd.service`。
- 不执行 `systemctl enable/start/restart`。
- 不修改宿主显卡驱动、VA-API 配置、网络、防火墙或其他系统设置。

ToDesk 官方发行版安装包使用 `todeskd.service` 提供系统级后台服务。若需要开机即启动、系统级无人值守或官方 systemd 服务语义，应使用 ToDesk 官方发行版安装方式；本 AppImage 不伪装成系统安装包。

## 当前验证状态

2026-09-24 新增 ToDesk AppImage 打包实现时，已依据以下内容完成静态设计核对：

- 当前 AUR `todesk-bin` 的包布局和 `!strip` 规则。
- ToDesk 官方 Linux 文档中的 `/opt/todesk/config/config.ini`、服务日志位置和 X11 要求。
- 本仓库 `anylinux_projects.md` 的 quick-sharun 多入口、非标准 `/opt` 布局、GTK3 中文输入和 locale 规则。
- 私有仓库 EasyConnect 已有“单 AppImage 多入口 + 可写后台运行目录 + 固定路径映射”的实现经验。

本条只表示构建脚本和路径设计已经静态核对；首次 GitHub Actions 正式构建、最终 AppImage 启动、服务与 GUI 通信、真实远程连接仍需以之后实际产物结果为准，不提前标记为已验证。


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
