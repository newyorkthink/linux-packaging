# ToDesk 模板差异

## 标准与来源

主流程遵守 [Anylinux / quick-sharun 规范](../../anylinux_projects.md) 和 [固定注释](../../docs/quick-sharun-comments.md)，采用先安装应用及依赖、再独立下载官方 DEB、完整放入 AppDir/bin、收集依赖、生成中文环境、封装和保存版本的顺序。ToDesk 为闭源原生 GTK3 程序，不归为 Electron。

pkgforge-dev 当前未找到 ToDesk 专属打包仓库；上游参考索引保留空白，不虚构专属处理。通用流程核对自 [HOW-TO-MAKE-THESE.md，1930c50](https://github.com/pkgforge-dev/Anylinux-AppImages/blob/1930c50cc7e0e524165afc67233f0693e5e73da8/HOW-TO-MAKE-THESE.md)，原始核心命令为 `./quick-sharun /usr/bin/myapp` 和 `./quick-sharun --make-appimage`。本仓库使用构建容器已有命令，不另行下载工具、不增加系统升级或瘦身包替换。

应用来源和布局核对自 AUR 固定快照 `4d59901f7b559b0b363819ba9a9150878a4b1935`：

- [.SRCINFO](https://github.com/archlinux/aur/blob/4d59901f7b559b0b363819ba9a9150878a4b1935/.SRCINFO)
- [PKGBUILD](https://github.com/archlinux/aur/blob/4d59901f7b559b0b363819ba9a9150878a4b1935/PKGBUILD)
- [todesk.install](https://github.com/archlinux/aur/blob/4d59901f7b559b0b363819ba9a9150878a4b1935/todesk.install)

快照仅记录依据，不用于固定构建版本。官方 DEB 已完整核对，SHA-256 与该快照一致；版本、长度、摘要及故障保存在 [README 修复记录](../README.md#修复记录)。

## 保留的专属差异

| 阶段 | 处理与实际位置 | 必要性和边界 |
| --- | --- | --- |
| 安装 | [build_todesk.sh](../build_todesk.sh) 调用 `arch/install_packages.sh --aur-deb todesk-bin "$(uname -m)" --downloader aria2c --wayback --fallback-origin "$SOURCE_FALLBACK_ORIGIN" --`，随后传原有 XCB / PulseAudio / 输入模块、dpkg 和 libpipewire，并安装构建下载工具 aria2。 | run 41466283245 在 AUR wget 阶段取到 989 字节 HTML，后续公共下载尚未执行。公共入口先校验来源并填入 SRCDEST，再通过独立 builddir 让原 AUR 规则复核和安装，避免旧错误源文件盖过缓存。应用安装及 AUR 运行依赖处理保留；原有运行依赖不变，新增 aria2 仅用于构建下载，不增加服务切换。此衔接属于本仓库兼容处理。 |
| 下载 | 主脚本单行调用 `aur/download_deb_source.sh`，传入 `--downloader aria2c --wayback --fallback-origin "$SOURCE_FALLBACK_ORIGIN" --deb --version-file work/source-version.txt --package-version-file work/package-version.txt`。 | 当前显式选择 aria2c，由公共入口读取仓库 HTTP 下载配置，使用 16 连接 / 16 分段及公开模拟浏览器标识；原地址失败后，公共入口从官方更新域名下载同一路径的文件；该文件仍须通过原 AUR 摘要校验。AUR 仍以 wget / Mozilla 作为 DLAGENTS，本次是针对已记录下载失败的兼容集成，不冒称复用 AUR 下载命令。 |
| 布局 | `cp -a work/todesk-unpacked/opt/todesk AppDir/bin/`。 | 完整保留 bin、lib、res 和配置相对布局；最终程序来自独立下载包。没有使用系统安装目录复制替代第二阶段。 |
| 准备 | [prepare_appdir.sh](../patches/prepare_appdir.sh) 补 config、核对组件和全部直接缺库、准备 desktop 副本。 | config 空目录由 AUR 创建；四入口预检及输入 / 托盘库检查沿用已记录需求。当前 desktop 的 Exec 带 env，必须完整替换为便携入口，不保留 GPU 强制赋值。系统 desktop 不修改。 |
| 元数据 | MAIN_BIN、NO_STRIP、PATH_MAPPING。 | 明确真实入口，保留闭源二进制，并让工具收集路径映射库；固定值见 [配置依据](./hardcoded.md)。 |
| 依赖收集 | 主脚本同一次传入完整目录、四个真实入口、pulseaudio 和三项托盘库。 | 目录参数负责相邻资源和自带库，显式 ELF 参数参与工具早期依赖识别；GTK3 输入模块改由 DEPLOY_GTK 自动收集，准备脚本仍核对两套模块已安装。构建命令前的 LD_LIBRARY_PATH 只服务于这一条依赖收集命令。 |
| 运行准备 | [90-todesk-runtime.hook](../patches/90-todesk-runtime.hook)。 | 保留同名入口选择、可写 config、etc/reg.conf 和既有用户状态目录。官方程序目录由 bin/todesk 提供；工具会包装嵌套 ELF，刷新临时副本时先删除包装器硬链接，再复制 shared/bin 中四个独立真实 ELF。否则四个目标可能共享同一 inode，被最后一次复制全部覆盖。 |
| 版本 | 公共入口写 pkgver 和 pkgver-pkgrel；主脚本分别读取来源版本、复制完整包版本标记，成功后公共保存。 | 不在应用解析 .SRCINFO、source 元数据或用 printf 再拼来源版本；pkgrel 仅控制副本刷新，不与 DEB Version 混为一谈。 |

下载器仅为公共调用参数。对照分类表中已标准化的 AUR 项目，保留现有两阶段及公共入口；两处调用继续显式使用 aria2c，HTTP 请求设置统一放在公共配置中，主脚本不展开下载参数，原地址、官方更新域名和原 URL 的归档按顺序尝试。标准 aria2 加载公共配置后的实际下载、摘要、版本与来源缓存已核对；后续 [Build ToDesk job 125731320407](https://github.com/newyorkthink/linux-packaging/actions/runs/41579665676/job/125731320407) 已完成官方备用源下载、真实 AUR 安装、依赖收集、AppImage 封装与发布，版本清单也已更新。完整证据与实机范围见 [README](../README.md#当前验证状态)。

历史正式构建 run `41567549690` 使用 wget 只取得 988 字节响应，run `41573638599` 改用 aria2c 后仍未通过原摘要；隔离浏览器也曾停在人工验证页。这些失败和隔离结果不能推出直接命令下载不可用，也不能单独证明补齐请求配置即可修复 CI。后续官方备用源方案已由上述正式 ToDesk job 验证通过；公共配置调整本身的故障与检查范围见 [README](../README.md#2026-11-03公共-aria2-http-配置补齐请求设置并兼容标准版本)。

## 主脚本注释

通用注释逐字采用 [固定注释标准](../../docs/quick-sharun-comments.md)，包括 `DEPLOY_GTK` 和 `DESKTOP` 的注释、标点、位置及相邻空行。`DESKTOP` 引用系统安装提供的官方 desktop 的工作副本，副本调整仍由已记录的准备脚本负责。

以下是本应用的专属注释，统一使用本仓库兼容处理前缀；来源依据保存在本文和 [固定配置](./hardcoded.md)，不把 AUR 原因或上游链接插入脚本注释。

| 处理 | 脚本注释原文 | 来源与用途 |
| --- | --- | --- |
| 准备程序目录 | `# 本仓库兼容处理：补回配置目录、核对运行组件，并准备便携桌面入口。` | 本仓库的配置目录、运行组件检查和便携 desktop 准备。 |
| NO_STRIP | `# 本仓库兼容处理：保持闭源二进制和官方私有库原样。` | 本仓库按 AUR 的 !strip 要求设置；原始依据保留在固定配置说明中。 |
| PATH_MAPPING | `# 本仓库兼容处理：收集路径映射运行库，运行时由专属 hook 指向可写目录。` | 本仓库为既有运行 hook 收集路径映射支持。 |
| 四入口检查 | `# 本仓库兼容处理：核对四个便携入口与运行副本需要的真实程序都已收集。` | 本仓库核对 quick-sharun 处理后的包装入口和真实程序。 |
| 完整包版本标记 | `# 本仓库兼容处理：保存完整包版本，沿用升级时刷新程序副本并保留配置的判断。` | 本仓库为程序副本刷新与配置保留写入版本标记。 |
| 运行 hook | `# 本仓库兼容处理：保留多入口、可写配置目录和固定路径映射。` | 本仓库的多入口与可写运行目录处理。 |

## 保持的运行边界

AppRun 继续由 quick-sharun 生成。没有加入宿主 systemd 安装、服务启动、GPU 驱动固定封装或 LIBVA_DRIVER_NAME 强制设置。日志路径映射沿用既有尝试，旧实测仍存在部分宿主 /var/log 访问未拦截；本次没有宣称解决该边界。

原有 4.9.6.0 核心远控实机通过结论保留。此前 584 项隔离验证包含未改动的官方 libmakepkg 来源处理与原 AUR 摘要复核，补上安装替身漏检的下载链；该轮包安装使用替身，不等于正式构建验收。后续官方备用源方案的 4.9.8.1 完整构建与发布已通过，新产物尚无实机运行结果；音频、打印、托盘及系统集成边界不扩大。完整状态见 [README](../README.md#当前验证状态)。
