# v2rayN AppImage

## 用途与产物

本目录从 v2rayN 官方 GitHub 最新稳定 Release 下载 Linux x64 DEB，并重新封装为 `v2rayn.AppImage`。

## 技术栈与打包方式

v2rayN Linux 客户端使用 .NET/Avalonia。构建脚本校验官方 Release SHA-256，保留 DEB 内的自包含运行目录，复用 DEB 的 desktop 和图标，通过 quick-sharun 处理 ELF 和桌面集成。

## 版本元数据

构建脚本复用官方稳定 Release tag 解析出的 `VERSION`，在现有最终产物检查完成后写入 `dist/version.txt`。workflow 使用 `SOFTWARE_KEY=v2rayn` 接入统一版本清单。

## 运行

```bash
./v2rayn.AppImage
```

## 实机验证

### 2026-11-04：用户实机验证通过（7.25.6）

用户已确认 v2rayN 7.25.6 实机验证通过，正常启动后没有程序运行报错。以下结果来自用户提供的运行界面和终端截图。

| 实测项目 | 通过结果 |
| --- | --- |
| 启动与界面 | 程序窗口正常打开，窗口标题显示 v2rayN 7.25.6；用户确认启动后终端没有程序运行报错。 |
| 中文界面与深色显示 | 中文菜单、配置窗口和节点列表正常显示，深色界面正常呈现。 |
| 中文输入 | 输入框内能够显示中文输入候选框。 |
| 核心启动与连接 | 界面日志可见 Xray 启动及连接处理记录。 |
| 延迟与速度测试 | 测试完成提示正常出现，节点列表显示延迟和速度结果。 |
| 文件选择窗口 | 能够从配置界面打开文件选择窗口。 |

对应的[构建与发布记录](https://github.com/newyorkthink/linux-packaging/actions/runs/41772916703/job/126386596444)显示构建发布、版本元数据上传和版本清单更新成功。当前标准构建脚本及 `quick-sharun AppDir/bin/v2rayN` 保持原样，不恢复旧版代码。

### 2026-11-04：Hysteria2 TUN 实机验证通过（7.25.6）

用户已确认 v2rayN 7.25.6 的 Hysteria2 TUN 通过 Linux 实机验证。在「设置 → Core 类型」中，仅将 Hysteria2 改为 `sing_box`，其他协议保持 Xray；保存后重新开启 TUN。

| 实测项目 | 通过结果 |
| --- | --- |
| TUN 网卡 | `singbox_tun` 已创建，标志包含 `UP,LOWER_UP`。 |
| IPv4 出口 | 移除大小写 HTTP、HTTPS 和 ALL 代理环境变量后，`curl` 返回当前节点的出口地址。 |
| 关闭 TUN | 日志显示核心收到 SIGTERM 后正常结束，随后查询不再显示 `singbox_tun`。 |

#### 运行观察

此前使用 Xray 26.10.31 启动 TUN 时，出现以下错误：

```text
exec: "resolvectl": executable file not found in $PATH
```

v2rayN 7.25.6 的[上游实现](https://github.com/2dust/v2rayN/blob/7.25.6/v2rayN/ServiceLib/Services/CoreConfig/V2ray/V2rayInboundService.cs#L95-L98)在 Linux 的 Xray TUN 配置中启用 `autoSystemDnsToGateway`。此次失败发生在运行时配置系统 DNS 的阶段，Xray 的启动环境找不到 `resolvectl`；该报错不是共享库加载失败。改用上述已实测通过的 sing-box 方案后，TUN 已正常工作，当前打包脚本及上游程序保持原样。

## 变更记录

### 2026-09-16：接入统一软件版本元数据

仅增加统一版本输出与发布映射，不改变现有官方包校验、Avalonia 自包含目录或启动环境。

### 2026-09-17：修复 GitHub Actions 下载官方 Release 资产 403

- 故障现象：全量 Actions Run `35159519188` 的 `Build v2rayN` 在读取官方最新 Release 信息成功后，下载 `v2rayN-linux-64.zip` 时收到 HTTP 403，构建在正式打包前退出。
- 根因范围：失败发生在 GitHub Release 的 `browser_download_url` 直链下载阶段；现有 Release API、版本解析和 SHA-256 digest 读取均已成功，因此不修改 v2rayN 打包、Avalonia runtime 或版本元数据逻辑。
- 修改文件：`v2rayn/build_v2rayn.sh`、本 README。
- 修复：继续优先使用官方 `browser_download_url`；如果该直链下载失败，则使用同一 Release asset 的 GitHub API asset ID，并通过 workflow 已提供的 `GH_TOKEN` 以 `application/octet-stream` 方式下载。两条路径最终仍使用 GitHub Release 返回的同一个 SHA-256 digest 校验。
- 已知结果：本次修复针对下载入口；后续构建与实机通过结果见 [实机验证](#实机验证)。

### 2026-09-23：恢复既有打包环境并延后安装统一基础包

- 故障现象：AppImage 已生成，但在现有 Xvfb 启动检查中出现 `free(): invalid pointer` 并提前退出。
- 根因范围：最近新增的统一 Arch 基础包调用位于构建脚本开头，改变了此前稳定的依赖收集与启动检查环境。
- 修改文件：`v2rayn/build_v2rayn.sh`、本 README。
- 修复内容：将统一基础包调用移动到 AppImage 完成现有检查之后，使打包阶段继续使用原有应用依赖集合，同时在脚本返回前补齐后续发布需要的基础命令。
- 已知结果：脚本执行顺序已恢复原有打包环境；后续构建与实机通过结果见 [实机验证](#实机验证)。

### 2026-09-24：整理构建脚本与可选图形检查

- 构建脚本的流程注释改为中文，移除最终 AppImage 再解包、逐项核对 AppRun、desktop、图标和程序目录的重复检查；仍保留官方资产 SHA-256、架构与入口判断、desktop 校验和最终产物非空判断。
- 只有本应用显式调用 `common/gui/check_appimage_gui.sh`；保留原有 20 秒上限、`timeout → dbus-run-session → xvfb-run` 顺序、退出码 `124` 及既有致命日志特征，不检查窗口标题。通过后仍先安装统一基础包，再由 `common/build/finish_appimage_build.sh` 写入 `dist/version.txt` 并输出原成功提示。
- 官方 Release 直链失败时使用同一资产 ID 与 `GH_TOKEN` 回退的逻辑，以及官方 SHA-256 校验均未改变。本次完成静态检查；后续构建与实机通过结果见 [实机验证](#实机验证)。

### 2026-09-24：复用官方 DEB 桌面资源与公共构建入口

- 本次改从最新稳定 Release 的 `v2rayN-linux-64.deb` 解包。该包自带 `/opt/v2rayN` 程序、`v2rayn.desktop` 和 hicolor 图标；复制上游 desktop 后只将 `Exec=v2rayn` 改为 AppImage 内的真实入口 `Exec=v2rayN`，并补上窗口类与本次版本。此前手写 desktop 的实现由此替代。
- `common/github/download_latest_stable_named_asset.sh` 统一选择固定资产名、验证官方 SHA-256 和 DEB 包名及 amd64 架构；直链失败仍按同一资产 ID 使用认证 API 回退。`common/archive/extract_archive.sh` 解包 DEB，`common/arch/install_packages.sh` 安装应用依赖，`common/build/prepare_x86_64_workspace.sh` 限定架构并清理本项目目录。
- 保留原先的 ELF 收集、相邻文件布局、20 秒可选图形检查及其后安装统一基础包的顺序。此次完成静态检查；后续构建与实机通过结果见 [实机验证](#实机验证)。上面关于 ZIP 下载和手写 desktop 的旧记录描述的是当时实现，现由本节替代。

### 2026-09-24：修复 DEB 追踪库扫描并整理产物收尾

- Actions Run `35956804794` 的 v2rayN Job `107496795652` 成功下载和校验官方 DEB，随后 `quick-sharun` 扫描 `libcoreclrtraceptprovider.so` 时因缺少 `liblttng-ust.so.0` 退出。上游 `package-debian.sh` 也将该可选追踪库排除在依赖扫描之外；本脚本只从 quick-sharun 的 ELF 输入中排除它，原样复制官方程序目录时仍保留该文件。不安装当前仅提供 `.so.1` 的 Arch `lttng-ust`，也不把旧兼容库加入所有应用的基础包。
- 原有的产物非空/可执行判断和 `sha256sum | tee` 写文件合并到 `common/build/check_appimage_artifact.sh`，调用位置仍在 20 秒图形检查之前。版本文件和成功提示仍由独立的 `common/build/finish_appimage_build.sh` 在图形检查后处理。
- 此前为避免 `free(): invalid pointer`，将整套 Arch 基础包移至图形检查之后；但此时 AppImage 已生成，它不再改变产物。现在删除该末尾安装，只在开始的精确依赖列表中补 `github-cli` 供同一容器的 Release 发布步骤使用，保留已有 `jq`。上方记录描述当时的顺序，已由本节替代。
- 当时完成静态检查；后续构建与实机通过结果见 [实机验证](#实机验证)。

### 2026-09-24：实机确认界面、中文输入和代理

Linux 实机运行当时的 `v2rayn.AppImage`。日志显示进程来自 `/tmp/.mount_v2ray*`，版本 `V7.24.9 - X64`，核心 `Xray 26.3.27`。主界面可以打开，拼音输入时出现中文候选框。节点延迟测试完成，一条结果为 280 ms。浏览器通过 `PROXY 127.0.0.1:10808` 打开了 Google。

同一次日志里的 `10808 bind: address already in use` 是本地端口已被占用。未加密和 `AllowInsecure` 提示来自节点配置。这两项都不作为打包故障。

