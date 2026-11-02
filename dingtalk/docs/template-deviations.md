# DingTalk 专属差异

钉钉采用 AppDir / 官方 appimagetool 体系的直接封装模式，按 [统一规范](../../linuxdeploy_projects.md) 与 [固定注释](../../docs/linuxdeploy-comments.md) 维护。公共流程在主 build 中单行调用；以下仅保留 Qt/CEF 产品实际需要的差异。

## 来源与版本

2026-11-02 按 DingTalk、dingtalk、ding-talk 查找 pkgforge-dev，未查到对应打包仓库；上游索引两列继续留空，不建立空的上游取舍清单。

AUR 当前快照为 [9f15353cb6556398d3cd3ac594a57ca4a824200a](https://aur.archlinux.org/cgit/aur.git/log/?h=dingtalk-bin&id=9f15353cb6556398d3cd3ac594a57ca4a824200a)，已读取同次 [PKGBUILD](https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=dingtalk-bin&id=9f15353cb6556398d3cd3ac594a57ca4a824200a)、`.SRCINFO`、desktop、SVG 和启动脚本。PKGBUILD 的 `source_x86_64` 指向钉钉官方 HTTPS DEB，`sha512sums_x86_64` 提供对应完整摘要；软件官方网站为 [dingtalk.com](https://www.dingtalk.com/)。快照仅作为说明依据，正式构建始终动态读取当前 AUR 来源，不固定此 commit 或软件版本。

主 build 使用 `common/aur/install_and_extract_deb_source.sh`，在一次调用中下载、校验、安装并按原布局解包同一 DEB，返回实际版本；不执行 PKGBUILD、makepkg 或 Docker。AUR `pkgver` 与 DEB Version 精确核对，AUR `pkgrel` 不写入软件版本；同次 AUR 资源和依赖清单留在 source。最终版本只由公共封装入口写入 `dist/version.txt`。

## 专属处理位置

| 阶段 | 处理 | 原因与保留边界 |
| --- | --- | --- |
| 准备构建环境 | Ubuntu 24.04 的 GTK2、GLU、libcrypt、音频、X11/XCB、Fcitx5 Qt 运行依赖，另提供 SVG 转换工具。 | 沿用既有 Ubuntu 运行环境和库覆盖；Qt/CEF 使用官方 bundle，不另行安装一套 Qt 替换私有框架。 |
| 准备桌面资源和运行库 | `patches/prepare_appdir.sh` 将 DEB 中唯一的 `files/*-Release.*` 完整移动为 `opt/dingtalk/release`，保留 version 和随包版权文档。 | 对齐 AUR `package()` 的布局，保留 Qt、CEF、会议组件和相邻 Resources 的相对位置。 |
| 同上 | 沿用 AUR 对 GTK2、libm、libstdc++、Harfbuzz、GBM、libcurl、libz、libGL 及平台无关资源的清理。 | AUR 注明移除私有 GTK2 用于工作台中文输入；其余清理的原文见上述 PKGBUILD，AUR 未逐项说明原因。清理范围沿用此前 AUR 产物，外部依赖随后从同一 Ubuntu 环境收集。仅处理 AppDir，不删系统文件。 |
| 同上 | 移除 doctor、libgtkglext、libgdkglext。 | 沿用旧 CI 已有的诊断组件清理：这些非主程序组件依赖 Ubuntu 24.04 已不提供的 libpangox。 |
| 同上 | 对 AUR desktop 按分组保留首次出现的键，再沿用 `Exec=dingtalk`、规范化 Icon 和 `usr/bin/dingtalk → ../../AppRun`。 | 保留原 desktop 净化与命令入口。desktop 的 MIME 声明保留，本次不新增宿主协议注册。 |
| 同上 | 公共 NSS 入口显式传入 `--with-nspr`，兼容完整的 `nss/` 子目录和 multiarch 平铺目录；`patches/collect_runtime.sh` 保留 NSSUTIL / NSPR 符号版本检查。 | 同一 Ubuntu 软件包集合提供完整 16 文件，覆盖动态加载模块和校验文件；目录选择统一由公共入口完成，模块组不跨目录拼接，避免包内 NSS 与宿主库混用。 |
| 同上 | 保留 ELF 可执行栈清理、两轮递归依赖收集和缺失依赖拦截。 | 迁入独立 patches，原依赖排除规则和收集命令保留；不随包复制 glibc、动态加载器和宿主 GPU 驱动接口。 |
| 准备 AppRun | 保留三段库路径、预加载包内 CEF、Wayland/XCB 顺序、缩放与输入法默认值、插件目录及工作目录。 | 主程序仍从官方运行目录直接执行，传入参数完整保留，AppRun 内不下载或安装软件。 |
| 整理产物 | 只调用公共 `package_appimage.sh`。 | 公共入口生成 PNG 根图标、修权限、正式封装、输出 SHA-256 并保存版本；主 build 不单独生成 SVG .DirIcon，不再附加启动测试或 runtime 检查。 |

钉钉自身提供中文界面资源，本次保持原界面语言选择与输入法行为，不因标准化新增中文 locale 或强制 LANG。区域数据、界面翻译与中文输入是不同内容，不以环境变量存在代替功能验收。

## CI 与产物

`.github/scripts/ci_build_dingtalk.sh` 只转交主 build；`build.yml` 的 DingTalk job 保留 Ubuntu 24.04、原超时、权限、选择条件和发布名称。公共封装已生成 `dist/version.txt`，workflow 不再从旧 `dingtalk-version.txt` 二次解析。旧容器、makepkg、独立工具安装、SHA 文件复查和两轮图形测试不再执行。

当前产物为 `dist/dingtalk.AppImage` 与 `dist/version.txt`；SHA-256 输出到构建日志，发布动作继续计算摘要并更新软件清单。此处是用户确认的标准化迁移，不把旧 README 中的容器命令、冒烟测试和历史本地辅助文件恢复为当前必需步骤。
