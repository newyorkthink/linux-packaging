# poppler-utils AppImage

## 用途与产物

本目录把 Ubuntu 24.04 官方仓库的 `poppler-utils` 与 `poppler-data` 打包为 `poppler-utils.AppImage`。一个 AppImage 提供 13 个命令：

- `pdfattach`
- `pdfdetach`
- `pdffonts`
- `pdfimages`
- `pdfinfo`
- `pdfseparate`
- `pdfsig`
- `pdftocairo`
- `pdftohtml`
- `pdftoppm`
- `pdftops`
- `pdftotext`
- `pdfunite`

上游来源：

- Ubuntu 24.04 官方 `poppler-utils` deb
- Ubuntu 24.04 官方 `poppler-data` deb
- Poppler 官方项目：<https://poppler.freedesktop.org/>

正式构建由 `.github/workflows/build.yml` 的 Ubuntu 24.04 独立 Job 完成，固定发布资产为 `poppler-utils.AppImage`。

## 技术栈

- Poppler C / C++ 命令行工具。
- 目标架构：x86_64。
- 不编译 Poppler 源码，直接使用 Ubuntu 官方 deb。
- `linuxdeploy` 负责整理 AppDir 和收集动态依赖。
- `appimagetool` 使用构建时下载的官方 Type 2 runtime 生成最终 AppImage。
- `poppler-data` 的 CMap / 编码数据一并放入 AppDir。
- 不安装 udev，不请求额外系统权限。

## 打包方式

1. 在 Ubuntu 24.04 安装官方 `poppler-utils` 与 `poppler-data`。
2. 通过公共 APT 入口下载与已安装版本一致的 `poppler-utils` 和 `poppler-data`，按原有 DEB 目录结构解包到 AppDir，保留 13 个命令及 `/usr/share/poppler` 数据。
3. 自定义 `AppRun` 根据 Type 2 runtime 提供的 `ARGV0` 分派软链接入口；也支持把命令名作为第一个参数。
4. 通过公共工具入口取得 linuxdeploy、appimagetool 与 Type 2 runtime，使用 `linuxdeploy --appdir AppDir --output appimage` 收集依赖。
5. 通过公共最终封装入口调用 appimagetool 和 Type 2 runtime 生成 `poppler-utils.AppImage`，并输出 SHA-256。
6. 从实际安装的 Ubuntu deb 读取版本并写入 `dist/version.txt`。

workflow 入口：`poppler-utils/build_poppler-utils.sh`。成功发布后由当前 Job 立即更新 `software_versions.json` 中的 `poppler-utils` 条目。

Poppler Utilities 的稳定构建基线固定为 Ubuntu 24.04：linuxdeploy 负责整理 AppDir 和收集依赖，官方 appimagetool 使用明确下载并校验的 `runtime-x86_64` 完成最终封装。不得改回 Arch Linux + quick-sharun，也不得在 Arch Linux 中执行 linuxdeploy + appimagetool 打包。

## 版本元数据

版本来自本次实际安装的 Ubuntu 官方 `poppler-utils` 软件包，去掉 Debian epoch / revision 后写入：

```text
poppler-utils/dist/version.txt
```

成功发布后，当前 Build Job 立即把 `poppler-utils` 条目写入 `latest` Release 的 `software_versions.json`。

## 运行与兼容说明

把同一个 AppImage 按命令名做符号链接后，AppRun 会按链接名分派对应程序：

```bash
ln -sf ./poppler-utils.AppImage ./pdftotext
ln -sf ./poppler-utils.AppImage ./pdfinfo
ln -sf ./poppler-utils.AppImage ./pdffonts
ln -sf ./poppler-utils.AppImage ./pdfimages
ln -sf ./poppler-utils.AppImage ./pdfattach
ln -sf ./poppler-utils.AppImage ./pdfdetach
ln -sf ./poppler-utils.AppImage ./pdfseparate
ln -sf ./poppler-utils.AppImage ./pdfsig
ln -sf ./poppler-utils.AppImage ./pdftocairo
ln -sf ./poppler-utils.AppImage ./pdftohtml
ln -sf ./poppler-utils.AppImage ./pdftoppm
ln -sf ./poppler-utils.AppImage ./pdftops
ln -sf ./poppler-utils.AppImage ./pdfunite
./pdftotext -v
```

也可以直接把命令名作为第一个参数：

```bash
./poppler-utils.AppImage pdftotext -v
./poppler-utils.AppImage pdfinfo <PDF文件>
```

直接运行 AppImage 且不提供命令名时，默认执行 `pdftotext`。

真实 Linux 环境已经确认原 quick-sharun 产物用于 lf PDF 预览时会长时间停在 `loading...`；当前 Ubuntu 24.04 `linuxdeploy + appimagetool` 产物已在 lf 中快速显示 PDF 文本预览，速度正常，现有 lf 配置无需修改。一个 AppImage、13 个命令和软链接分派方式继续作为稳定基线。

## 标准化构建与专属差异

当前构建脚本按 [LinuxDeploy CLI 标准模板](../templates/appimage/linuxdeploy-cli-apt.sh) 组织分区、公共入口和固定注释。构建环境仍为 Ubuntu 24.04；程序及 `poppler-data` 来自同一构建环境的官方 APT 软件包，不编译 Poppler 源码。

- 公共工作区、APT 安装、下载同版本 DEB、linuxdeploy 初始化、打包工具及 Type 2 runtime 准备、最终 AppImage 封装与版本元数据均复用现有公共入口。
- 专属部分只负责官方 PNG 图标、终端 desktop 和 13 命令分派。原 `AppRun` 的 `ARGV0`、命令名作为首参数及默认 `pdftotext` 行为逐字保留。
- 标准模板只支持单一主程序入口，因此原 13 命令 `AppRun` 保留为已验证的程序专属差异，详见 [模板差异](docs/template-deviations.md)。构建环境与必要固定参数见 [固定配置](docs/hardcoded.md)。

## 实机验证

### 2026-11-08：用户实机验证通过

用户已确认 Poppler Utilities 实机验证通过。

| 实测项目 | 通过结果 |
| --- | --- |
| `pdftotext -v` | 正常输出 `pdftotext version 24.02.0`。 |
| 命令分派 | 软链接入口和 AppImage 首参数指定命令均正常执行。 |
| 默认入口 | 不指定命令时正常执行 `pdftotext`。 |
| PDF 工具 | 13 个工具的调用与相应功能测试通过。 |

## 修复记录

### 2026-09-18：新增 poppler-utils AppImage

- 日期：2026-09-18
- 现象：需要不安装发行版系统包即可使用整套 Poppler PDF 命令行工具。
- 根因：Poppler 官方不发布 Linux 独立二进制；发行版 `poppler` / `poppler-utils` 提供整套命令，需要重打包才能不依赖宿主安装该软件包。
- 修改文件：新增 `poppler-utils/` 目录；在 `.github/appimage-apps.json` 增加标准应用记录。
- 具体内容：按 Arch 官方 `poppler` / `poppler-data` + quick-sharun 最短链路打包 13 个命令；版本从本次安装的软件包动态读取。
- 已知结果：当时已提交正式构建入口，未监控 Actions。

### 2026-09-18：补上 DUMMY desktop 仍缺少的 ICON

- 日期：2026-09-18
- 现象：[run 35349847442](https://github.com/newyorkthink/linux-packaging/actions/runs/35349847442) 的 `Build poppler-utils` 失败。日志：`ERROR: Missing AppDir/.DirIcon`，并提示 `Set ICON env variable`。
- 根因：`DESKTOP=DUMMY` 只会生成空 desktop，quick-sharun 仍要求图标。官方 `poppler` 包没有 desktop / 图标。
- 修改文件：`poppler-utils/build_poppler-utils.sh`、`poppler-utils/README.md`。
- 具体内容：在收集依赖前从构建环境的 Adwaita / hicolor 中选取已有的 `application-pdf` MIME 图标并 `export ICON`。不自绘品牌图，不改命令收集范围。
- 已知结果：已提交修复，未监控 Actions。

### 2026-09-18：Adwaita 50 没有 application-pdf 图标

- 日期：2026-09-18
- 现象：[run 35350625229](https://github.com/newyorkthink/linux-packaging/actions/runs/35350625229) 失败。日志：`找不到 application-pdf 图标`。
- 根因：Adwaita 50 的 MIME 图标没有 `application-pdf`，只有 `x-office-document` 等。
- 修改文件：`poppler-utils/build_poppler-utils.sh`、`poppler-utils/README.md`。
- 具体内容：ICON 改为明确路径 `/usr/share/icons/Adwaita/scalable/mimetypes/x-office-document.svg`。
- 已知结果：已提交，未监控 Actions。

### 2026-09-18：补上 STARTUPWMCLASS 消除 dummy desktop 警告

- 日期：2026-09-18
- 现象：[run 35350939418](https://github.com/newyorkthink/linux-packaging/actions/runs/35350939418) 构建成功，但 quick-sharun 警告 `pdftotext.desktop is missing StartupWMClass`。
- 根因：`DESKTOP=DUMMY` 生成的 desktop 没有该类名；命令行工具没有窗口，警告无功能影响。
- 修改文件：`poppler-utils/build_poppler-utils.sh`、`poppler-utils/README.md`。
- 具体内容：增加 `export STARTUPWMCLASS=pdftotext`。
- 已知结果：已提交，未监控 Actions。

### 2026-09-18：STARTUPWMCLASS 改为套件名

- 日期：2026-09-18
- 现象：误把 `STARTUPWMCLASS` 写成 `pdftotext`，只覆盖其中一个命令。
- 根因：这是多命令套件，类名应与 AppImage / `APPNAME` 一致。
- 修改文件：`poppler-utils/build_poppler-utils.sh`、`poppler-utils/README.md`。
- 具体内容：改为 `export STARTUPWMCLASS=poppler-utils`。
- 已知结果：已提交，未监控 Actions。

### 2026-09-19：从 quick-sharun 切换到 linuxdeploy

- 日期：2026-09-19
- 现象：quick-sharun 打包的 `pdftotext` 被 lf 调用时，PDF 预览长时间停在 `loading...`。
- 根因：真实运行对比确认延迟来自原 AppImage 打包启动层；13 个 Poppler 命令本身不需要拆分成多个 AppImage。
- 修改文件：`poppler-utils/build_poppler-utils.sh`、`poppler-utils/README.md`、`.github/appimage-apps.json`、`.github/workflows/build.yml`。
- 具体内容：改用 Ubuntu 24.04 官方 `poppler-utils` / `poppler-data` deb；保留一个 AppImage 和 13 个软链接入口；由 `linuxdeploy` 收集依赖，最终由 `appimagetool` 配合官方 Type 2 runtime 封装。
- 已知结果：脚本与 workflow 已切换；现有软链接部署方式无需修改。
### 2026-09-19：实机确认 lf PDF 预览速度

- 日期：2026-09-19
- 检查对象：提交 `ecaf371afa22922342cf2bbbfc8857f3ef5bc229` 切换后的 Ubuntu 24.04 `linuxdeploy + appimagetool` 产物、提交 `d393e98e5f1ecce7f239a808db38211e4ca32822` 恢复的软链接使用说明，以及 lf 中的 PDF 文本预览。
- 实机反馈：lf 已能快速显示 PDF 文本预览，速度正常，不再长时间停在 `loading...`。
- 确认结论：当前打包路线已解决原 quick-sharun 产物的 lf 预览延迟；现有 lf 配置无需修改。
- 稳定基线：继续保留一个 `poppler-utils.AppImage`、13 个命令入口和现有软链接分派；正式构建固定使用 Ubuntu 24.04、linuxdeploy 收集依赖、官方 appimagetool 配合明确下载并校验的 `runtime-x86_64` 完成最终封装。
- 文档处理：仅更新 `poppler-utils/README.md` 的当前状态、版本元数据和实机确认记录；未修改构建脚本、workflow、AppRun 或 Release 逻辑。

### 2026-11-08：按 LinuxDeploy CLI 结构标准化

- 保持 Ubuntu 24.04、单个 AppImage、13 个 Poppler 工具、`poppler-data` 及 lf PDF 快速预览的既有实机通过基线。
- 构建脚本统一使用仓库公共工作区、APT 同版本解包、linuxdeploy 工具准备和封装入口，移除旧版重复实现的下载工具函数、版本提取和打包路径配置。
- 官方 PNG、CLI desktop 与多命令 `AppRun` 分派按已验证逻辑保留，专属代码使用固定的 `# 本程序专属处理：` 注释，并与 LinuxDeploy 通用分区及固定注释一致。
- 对应专属代码、固定配置及技术依据分别记录在 `docs/template-deviations.md` 和 `docs/hardcoded.md`；既有修复历史与实机验证结论保留。
