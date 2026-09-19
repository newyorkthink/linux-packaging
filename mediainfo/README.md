# MediaInfo CLI AppImage

## 用途与产物

本目录把 MediaArea 的 MediaInfo 命令行工具打包为 `mediainfo.AppImage`，用于读取音视频及其他媒体文件的技术信息和标签信息。

上游与软件来源：

- 上游项目：MediaArea/MediaInfo
- 正式构建软件包：Arch Linux Extra 的 `mediainfo`
- 最终 Release 资产：`mediainfo.AppImage`

正式构建通过 `.github/workflows/build.yml` 的标准 matrix Job 执行，并复用 `.github/actions/build-anylinux` 的 Arch 容器和发布流程。应用清单 `.github/appimage-apps.json` 当前指向 `mediainfo/build_mediainfo_linuxdeploy.sh`；共享 Action 的名称不代表应用仍使用 quick-sharun。

## 技术栈

- MediaInfo CLI 为 C / C++ 命令行程序，核心运行库为 `libmediainfo` / `libzen`。
- 正式构建目标为 x86_64。
- Arch 官方 `mediainfo` 提供标准 `/usr/bin/mediainfo` 入口，正式构建使用 linuxdeploy 收集依赖，官方 appimagetool 完成最终封装。
- CLI 软件包本身没有 desktop / 图标；脚本生成 `Terminal=true` 的 desktop，品牌图标从 MediaInfo 官方源码仓库取得。无需 GTK 插件。

## 打包方式

本目录保留两份独立脚本：

- `build_mediainfo_anylinux.sh`：原 `build_mediainfo.sh` 原样改名，保留 quick-sharun 方案。
- `build_mediainfo_linuxdeploy.sh`：当前正式入口，使用 linuxdeploy + 官方 appimagetool。

当前流程：

1. 在现有 Arch CI 容器安装打包工具和官方 `mediainfo` 软件包，从实际安装包动态读取版本。
2. 下载 linuxdeploy、官方 appimagetool 和 `runtime-x86_64`，按官方 Release 的 SHA-256 校验。
3. 将 CLI 放入 `AppDir/usr/bin`，准备 desktop 和官方图标；由 linuxdeploy 自动收集共享库并生成 AppRun，不添加自定义 wrapper。
4. 保留 `linuxdeploy --appdir AppDir --output appimage`，其中间产物放在 `source/`；再用官方 `appimagetool -n` 和明确的 `--runtime-file` 生成最终 `dist/mediainfo.AppImage`。
5. 最终封装成功后写入 `dist/version.txt`，仅发布 `dist/` 内的最终 AppImage。

`runtime-x86_64` 来自 [AppImage/type2-runtime 的 continuous Release](https://github.com/AppImage/type2-runtime/releases/tag/continuous)，不是 appimagetool 的附件；[官方 appimagetool 文档](https://github.com/AppImage/appimagetool#changelog) 同样指向该 runtime 来源。CI 使用项目内的 `source/runtime-x86_64`，不依赖个人工具目录。

构建只在 Actions 临时容器中执行。脚本会清理当前应用的 `AppDir/`、`dist/`、`source/` 上一次构建内容；不会修改使用者的 lf 配置。

以后切换两种方式，只需修改 `.github/appimage-apps.json` 中 MediaInfo 的 `script` 字段，产物名、版本文件和发布流程一致。

## 版本元数据

版本来自本次实际安装的 Arch `mediainfo` 软件包，去掉仅属于 Arch 打包的 epoch / pkgrel 后写入：

```text
mediainfo/dist/version.txt
```

成功发布后，当前 Build Job 立即把 `mediainfo` 条目写入 `latest` Release 的 `software_versions.json`。

## 运行与兼容说明

在 Linux 终端、AppImage 所在目录运行；将 `<媒体文件>` 替换为实际文件路径：

```bash
# 查看版本
./mediainfo.AppImage --Version
# 读取指定媒体文件信息
./mediainfo.AppImage "<媒体文件>"
```

历史 MediaInfo CLI AppImage 样本为 MediaInfoLib 22.12，使用旧 AppImageKit Type 2 runtime，直接运行时需要宿主提供 `libfuse.so.2`。当前 linuxdeploy 方案使用新的官方 type2-runtime，不复用该样本的旧 runtime 或旧依赖集合。

保留的 anylinux 脚本使用 uruntime。当前 linuxdeploy 脚本显式嵌入官方 type2-runtime；上游说明该 runtime 静态链接，不再要求宿主安装 `libfuse.so.2`，正常挂载仍需要可用的 FUSE 环境。构建工具设置的 `APPIMAGE_EXTRACT_AND_RUN=1` 仅用于 CI，不写入最终启动入口。

linuxdeploy 默认不捆绑 glibc / 动态加载器，因此宿主仍需满足本次 Arch 二进制及所打包共享库的 ABI 要求；不能把此方案描述为支持任意旧系统。当前尚未验证新产物的 lf 预览耗时。

## 修复 / 变更记录

### 2026-09-19：新增 MediaInfo CLI AppImage

- **检查对象：** 历史 MediaInfo CLI AppImage 样本、MediaArea 官方来源、Arch Linux 当前 `mediainfo` 软件包以及仓库现有 CLI AppImage 打包基线。
- **已确认事实：** 历史样本为 MediaInfoLib 22.12，旧 runtime 直接运行依赖 `libfuse.so.2`；MediaArea 官方页面当前认可 Arch 官方 `mediainfo` 包，Arch Extra 当前提供 CLI 包及标准 `/usr/bin/mediainfo` 入口。
- **处理：** 新增 `mediainfo/build_mediainfo.sh`，按 Arch 官方包 + quick-sharun 标准路线动态打包；新增本 README；在 `.github/appimage-apps.json` 登记标准应用。
- **未采用方案：** 不复刻旧 linuxdeploy AppImage；不新增 `linuxdeploy --output appimage`；不把 FUSE3 写成固定运行要求。
- **验证状态：** 提交时已完成上游、旧样本和仓库实现的静态核对；后续正式构建与产物核查结果见下方记录。

### 2026-09-19：正式构建产物核查

- **检查对象：** 提交 `859f4ce23f4a0dcf373f098613d2c99878e74e6a` 中的 `mediainfo/build_mediainfo.sh`、`.github/appimage-apps.json` 登记项、Build AppImages 运行 `35440897954`、latest Release 的 `mediainfo.AppImage`，以及用户提供的同名产物。
- **现象与范围：** 用户要求确认 MediaInfo 打包是否正常；本次核查覆盖脚本语法和动态版本逻辑、matrix 登记、正式构建与发布结果、Release 资产一致性、AppImage 结构、主程序及直接运行依赖、启动包装，以及 `--Version` / `--Help` 基础运行。
- **证据：** Build MediaInfo Job `105891395097` 成功完成构建、上传版本元数据和即时发布；构建日志显示产物写入 `dist/mediainfo.AppImage`，并成功更新 `software_versions.json`。latest Release 资产与用户提供文件的大小均为 `13846109` 字节，SHA256 均为 `fbbf632d38a1021ccbda620d1e47ddc5b6782ae9bdee44018d0ede00f473f46b`；版本清单记录为 `26.05`。
- **确认结论：** 产物为 x86_64 AppImage，包含 quick-sharun 启动层、`mediainfo` 主程序及 `libmediainfo` / `libzen` 等运行库；在无 FUSE 的核查环境中 uruntime 解包回退成功，`--Version` 返回 MediaInfoLib 26.05，`--Help` 正常。未发现应用专属的提权、开机启动或系统配置修改逻辑，当时未发现需要修改的基础启动问题；该结论不覆盖后续反馈的 lf 预览延迟。
- **未确认边界：** 本次未覆盖真实媒体文件解析结果、所有媒体格式，以及不同发行版上的完整兼容矩阵；这些不影响本次对打包结构、发布一致性和 CLI 基础启动的确认。

### 2026-09-19：保留 anylinux 并切换 linuxdeploy

- **现象：** 真实使用反馈为旧 AppImage 的 lf 媒体预览较快，新 AppImage 长时间显示 `loading...`。
- **检查对象与证据：** 基于提交 `89e90952e10a49b0fd77b2e3a7048f5a404fedf1` 的构建脚本、清单与调度逻辑，完整读取提供的 lf 配置和两份 preview 脚本，并静态读取新旧 AppImage 的 ELF 类型及 runtime 字符串。
- **已确认范围：** 两份 preview 脚本均直接调用 `mediainfo`，没有额外等待逻辑；旧包包含传统 AppImageKit / SquashFS runtime 字符串，新包包含 uruntime。此前记录的应用版本也不同，因此不能仅凭加载截图把根因确定为 quick-sharun 或 runtime。
- **修改文件与处理：** 原脚本原样改名为 `build_mediainfo_anylinux.sh`；新增 `build_mediainfo_linuxdeploy.sh`，按要求保留 linuxdeploy 输出步骤并单独使用官方 appimagetool 和指定 runtime 最终封装；`.github/appimage-apps.json` 切换正式入口；同步更新本 README。未修改 lf 配置或增加运行包装。
- **验证状态：** 完成脚本语法、静态分析、清单路径及完整 diff 核对；未在真实主机打包或反复运行样本，未监控本次 Actions。正式构建结果、宿主 ABI 兼容性及 lf 实际预览速度待新产物确认，尚不能声称加载问题已经解决。
