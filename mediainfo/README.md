# MediaInfo CLI AppImage

## 用途与产物

本目录把 MediaArea 的 MediaInfo 命令行工具打包为 `mediainfo.AppImage`，用于读取音视频及其他媒体文件的技术信息和标签信息。

上游与软件来源：

- 上游项目：MediaArea/MediaInfo
- 正式构建软件包：Arch Linux Extra 的 `mediainfo`
- 最终 Release 资产：`mediainfo.AppImage`

正式构建通过 `.github/workflows/build.yml` 的标准 matrix Job 执行，并复用 `.github/actions/build-anylinux`。

## 技术栈

- MediaInfo CLI 为 C / C++ 命令行程序，核心运行库为 `libmediainfo` / `libzen`。
- 正式构建目标为 x86_64。
- Arch 官方 `mediainfo` 提供标准 `/usr/bin/mediainfo` 入口，因此使用仓库的 Arch Linux + quick-sharun 标准路线。
- CLI 软件包本身没有 desktop / 图标，构建使用 `DESKTOP=DUMMY`，品牌图标从 MediaInfo 官方源码仓库取得。

## 打包方式

当前不沿用旧的 linuxdeploy + 传统 AppImageKit runtime 方案。构建流程为：

1. 在正式 Arch Linux 构建环境安装仓库规定的 quick-sharun 最小基础工具。
2. 从 Arch 官方仓库安装当前稳定版 `mediainfo`，由包管理器解析 `libmediainfo` 等实际运行依赖。
3. 从本次安装的 `mediainfo` 包读取版本，不写死应用版本。
4. 从 MediaInfo 官方源码仓库取得官方 SVG 图标。
5. 直接对 `/usr/bin/mediainfo` 执行 quick-sharun，再生成 `dist/mediainfo.AppImage`。
6. AppImage 成功生成后写入 `dist/version.txt`。

选择 quick-sharun 的原因是 MediaInfo CLI 已有标准 `/usr/bin` 入口，属于仓库 `AGENTS.md` 规定的最短标准链路；无需为了复刻历史包额外引入 linuxdeploy、appimagetool 或固定 FUSE 版本。

## 版本元数据

版本来自本次实际安装的 Arch `mediainfo` 软件包，去掉仅属于 Arch 打包的 epoch / pkgrel 后写入：

```text
mediainfo/dist/version.txt
```

成功发布后，当前 Build Job 立即把 `mediainfo` 条目写入 `latest` Release 的 `software_versions.json`。

## 运行与兼容说明

直接运行：

```bash
./mediainfo.AppImage --Version
./mediainfo.AppImage <媒体文件>
```

历史 MediaInfo CLI AppImage 样本为 MediaInfoLib 22.12，使用旧 AppImageKit Type 2 runtime，直接运行时需要宿主提供 `libfuse.so.2`。当前方案只把该样本用于确认原有应用形态和命令入口，不沿用其旧 runtime 或依赖集合。

quick-sharun 使用仓库现有 uruntime 路线；不把当前方案描述为“FUSE3 AppImage”，也不要求为了打包 MediaInfo 在用户系统安装构建依赖。

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
- **确认结论：** 产物为 x86_64 AppImage，包含 quick-sharun 启动层、`mediainfo` 主程序及 `libmediainfo` / `libzen` 等运行库；在无 FUSE 的核查环境中 uruntime 解包回退成功，`--Version` 返回 MediaInfoLib 26.05，`--Help` 正常。未发现应用专属的提权、开机启动或系统配置修改逻辑，当前打包脚本无需修改。
- **未确认边界：** 本次未覆盖真实媒体文件解析结果、所有媒体格式，以及不同发行版上的完整兼容矩阵；这些不影响本次对打包结构、发布一致性和 CLI 基础启动的确认。
