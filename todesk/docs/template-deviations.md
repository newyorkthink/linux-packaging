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
| 安装 | [build_todesk.sh](../build_todesk.sh) 安装 todesk-bin、原有 XCB / PulseAudio / 输入模块，以及 libpipewire。 | 应用安装负责 AUR 声明的 gtk3、AppIndicator 和中文字体依赖；IBus 来自公共基础包。原有额外依赖保留；libpipewire 来自当前四入口中三个 ELF 的直接依赖。只安装客户端库，不增加服务切换。 |
| 下载 | 主脚本单行调用 `aur/download_deb_source.sh`，传入 `--user-agent Mozilla --wayback --deb --version-file work/source-version.txt --package-version-file work/package-version.txt`。 | PKGBUILD 原文为 `DLAGENTS=("https::/usr/bin/wget -U 'Mozilla' -O %o %u")`；本仓库通过公共 curl 入口传入相同标识，属于兼容集成，不冒称逐字复用 wget 命令。上游未说明该客户端标识的具体原因；本次实际请求确认能取得摘要匹配的完整 DEB。 |
| 布局 | `cp -a work/todesk-unpacked/opt/todesk AppDir/bin/`。 | 完整保留 bin、lib、res 和配置相对布局；最终程序来自独立下载包。没有使用系统安装目录复制替代第二阶段。 |
| 准备 | [prepare_appdir.sh](../patches/prepare_appdir.sh) 补 config、核对组件和全部直接缺库、准备 desktop 副本。 | config 空目录由 AUR 创建；四入口预检及输入 / 托盘库检查沿用已记录需求。当前 desktop 的 Exec 带 env，必须完整替换为便携入口，不保留 GPU 强制赋值。系统 desktop 不修改。 |
| 元数据 | MAIN_BIN、NO_STRIP、PATH_MAPPING。 | 明确真实入口，保留闭源二进制，并让工具收集路径映射库；固定值见 [配置依据](./hardcoded.md)。 |
| 依赖收集 | 主脚本同一次传入完整目录、四个真实入口、pulseaudio 和三项托盘库。 | 目录参数负责相邻资源和自带库，显式 ELF 参数参与工具早期依赖识别；GTK3 输入模块改由 DEPLOY_GTK 自动收集，准备脚本仍核对两套模块已安装。构建命令前的 LD_LIBRARY_PATH 只服务于这一条依赖收集命令。 |
| 运行准备 | [90-todesk-runtime.hook](../patches/90-todesk-runtime.hook)。 | 保留同名入口选择、可写 config、etc/reg.conf 和既有用户状态目录。官方程序目录由 bin/todesk 提供；工具会包装嵌套 ELF，刷新临时副本时先删除包装器硬链接，再复制 shared/bin 中四个独立真实 ELF。否则四个目标可能共享同一 inode，被最后一次复制全部覆盖。 |
| 版本 | 公共入口写 pkgver 和 pkgver-pkgrel；主脚本分别读取来源版本、复制完整包版本标记，成功后公共保存。 | 不在应用解析 .SRCINFO、source 元数据或用 printf 再拼来源版本；pkgrel 仅控制副本刷新，不与 DEB Version 混为一谈。 |

## 保持的运行边界

AppRun 继续由 quick-sharun 生成。没有加入宿主 systemd 安装、服务启动、GPU 驱动固定封装或 LIBVA_DRIVER_NAME 强制设置。日志路径映射沿用既有尝试，旧实测仍存在部分宿主 /var/log 访问未拦截；本次没有宣称解决该边界。

原有核心远控实机通过结论保留。478 项隔离验证覆盖组合流程和运行目录准备，不等于真实依赖收集、完整 AppImage 构建或新产物实机验证；完整状态见 [README](../README.md#当前验证状态)。
