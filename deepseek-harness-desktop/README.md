# DeepSeek Harness 桌面版 AppImage

将 DeepSeek 官方 [deepseek-ai/deepseek-harness](https://github.com/deepseek-ai/deepseek-harness) 的桌面源码，通过 [AUR deepseek-harness-desktop](https://aur.archlinux.org/packages/deepseek-harness-desktop) 社区 Linux 配方编译，再封装为独立的 x86_64 AppImage。

## 定位与来源

- 应用主体来自 DeepSeek 官方仓库中的 [桌面工程（`apps/desktop`）](https://github.com/deepseek-ai/deepseek-harness/tree/master/apps/desktop)。
- Linux 构建采用 AUR 社区维护的配方及适配补丁，AppImage 由本仓库封装并发布。
- 用户实测已确认 AppImage 桌面启动和基础中文对话，其他功能及跨发行版兼容性尚未验证。
- 官方桌面应用采用 Electron，并内置完整 dsh 运行时。原来的命令行打包已于 2026-10-29 归档到 [archive/deepseek-harness](../archive/deepseek-harness/README.md)，不再构建、不再发布。
- 每次构建读取当前 AUR 配方和实际安装版本，本仓库不写死应用版本；AUR 当前渠道可能是 alpha，版本元数据保留该标识。
- [PKGBUILD](https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=deepseek-harness-desktop) 从官方 Git tag 获取源码，并应用社区 [linux-desktop.patch](https://aur.archlinux.org/cgit/aur.git/plain/linux-desktop.patch?h=deepseek-harness-desktop)。Linux 目标、更新配置、原生模块和 Office 运行时存在社区适配。
- 核对时的补丁使用第三方 `@janhapke/sharp-electron` 修复 Linux 图像处理崩溃，因此不能称为官方源码原样封装。补丁摘要由 makepkg 校验，补丁中的下载和上游运行时下载使用各自提供的摘要校验。

## 使用方法

从本仓库 [latest Release](https://github.com/newyorkthink/linux-packaging/releases/tag/latest) 下载构建成功后发布的 `deepseek-harness-desktop.AppImage`。在文件所在目录打开 Linux 终端：

```bash
# 赋予 AppImage 执行权限。
chmod +x deepseek-harness-desktop.AppImage

# 启动 DeepSeek Harness 桌面界面。
./deepseek-harness-desktop.AppImage
```

- AppImage 包含 Electron、dsh 资源及 AUR 构建出的 Node、pnpm、CPython 和 Office 组件，保留原有目录关系。
- 包内生成 `zh_CN.UTF-8`，并收集 GTK 3 的 IBus / Fcitx5 输入模块；宿主仍需正常运行并配置对应输入法。
- 保留 Chromium 默认沙箱行为，不在启动入口强制加入 `--no-sandbox`。宿主是否支持用户命名空间及实际运行兼容性仍需确认。
- Linux 更新采用本仓库重新构建的 AppImage，不使用官方 Windows / macOS 安装更新通道。
- 应用数据沿用上游行为；本项目不添加配置迁移、系统服务、自启动或启动时安装软件的逻辑。

## 构建与产物

- 正式构建复用现有标准 Arch Linux matrix 和 `build-anylinux` Action，不在用户真实主机安装 AUR 包。
- 当前 [AUR 配方及来源](https://github.com/archlinux/aur/blob/deepseek-harness-desktop/PKGBUILD) 从官方 Git tag 构建 Linux 桌面程序；[官方桌面打包说明](https://github.com/deepseek-ai/deepseek-harness/blob/master/apps/desktop/packaging/README.md) 未将 Linux 列为支持的发布目标。本次未找到适用的 Linux 预编译桌面安装包，采用“从系统里已安装的程序取得”分类，不添加 DEB 下载和解包步骤。
- 先通过 `common/arch/install_packages.sh --base` 安装统一基础工具，保留原有 simdjson 下载和本地安装处理，再安装 `deepseek-harness-desktop fcitx5-gtk` 及 `libxcrypt-compat`。原有安装命令和执行顺序保持不变，应用运行依赖由当前 AUR 配方声明。
- `/usr/bin/deepseek-harness-desktop` 是 shell 包装，实际程序为 `/usr/lib/deepseek-harness-desktop/deepseek-harness`。构建脚本将 `/usr/lib/deepseek-harness-desktop/.` 完整复制到 `AppDir/bin/`，保留程序、Electron、dsh 和相邻运行时资源，再调用 `quick-sharun AppDir/bin/*` 收集依赖。
- 内置 Python 私有库目录只在第一次 quick-sharun 调用中加入临时 `LD_LIBRARY_PATH`；后续封装不继承这次赋值。`libxcrypt-compat`、Python 私有库路径和 simdjson 的既有故障依据继续保留，不把这些修复复制到通用模板。
- 图标和 desktop 直接读取已安装包的原路径。上游 MIT 版权和许可声明从 `/usr/share/licenses/deepseek-harness-desktop/LICENSE` 复制到 `AppDir/share/licenses/deepseek-harness-desktop/LICENSE`；当前未证实程序资源内已完整包含同一声明，因此保留这份独立副本。
- 使用 `common/build/read_app_version.sh pacman deepseek-harness-desktop` 读取本次安装版本，去掉 epoch 和 pkgrel，保留 alpha 等渠道标识。版本读取保留在第一次 quick-sharun 之前；最终 AppImage 成功生成后，用单行公共保存调用写入 `dist/version.txt`。
- 当前脚本共 75 行。通用流程、元数据顺序、中文 locale 和版本保存沿用 Electron 标准；无现成安装包的来源差异及已保留的专属处理见下方文档。标准化不表示所有专属步骤与 DEB 模板具有相同行数。
- AUR 源码构建会下载工具链、Electron 和内置运行时，耗时与空间需求高于直接重打包现成二进制；构建任务设置 90 分钟超时。
- 唯一发布产物为 `dist/deepseek-harness-desktop.AppImage`。成功生成后写入 `dist/version.txt`，由现有流程立即发布版本信息。
- 手动构建时选择 `deepseek-harness-desktop/build_deepseek-harness-desktop.sh`；正常提交和每日构建沿用现有调度规则。

## 维护说明

- [固定配置与原始故障记录](docs/hardcoded.md)：说明目录、程序名、桌面资源、版本参数及已有修复的取值依据。
- [模板差异说明](docs/template-deviations.md)：说明无现成安装包的来源分类，以及 simdjson、Python 私有库、兼容库和许可证复制为何保留。
- [打包分类](../docs/packaging-classification.md)：只登记近期已按当前标准完成重写或整理的项目；未重写的应用不自动加入。

## 检查记录

### 2026-10-07：首次接入

- 已核对当前 AUR 配方、Linux 补丁、上游桌面说明和仓库已有 Electron 打包布局；本次仅新增独立桌面版。
- Bash 语法、JSON/YAML 解析、手动选项排序、公共入口路径和既有配置保留检查通过；已使用现有 Plan 脚本核对本次 push 仅选择新增桌面版，桌面版与浏览器版的手动入口分别选择对应项目。
- 首次接入时未取得正式 CI 构建产物。桌面启动和基础中文对话已由后续用户实测确认；中文输入法候选词行为、Office 功能及跨发行版兼容性尚未验证。
- 社区补丁和第三方原生依赖会随 AUR 配方更新；当前来源核对不代表后续版本或运行稳定性已经通过验证。

### 2026-10-07：修复内置 Python 的依赖扫描

- [首次 CI 构建](https://github.com/newyorkthink/linux-packaging/actions/runs/37611755057/job/112760445289) 已完成 `deepseek-harness-desktop 0.2.1alpha.1-1` 的 AUR 源码编译，并通过上游内置运行时与 Office 检查；随后 quick-sharun 扫描 `_tkinter` 时找不到 `libtcl9tk9.0.so` 和 `libtcl9.0.so`，构建中止，未生成 AppImage。
- 两项库位于内置 Python 的 `lib` 目录。仅为首次 quick-sharun 调用设置临时 `LD_LIBRARY_PATH`，加入该目录并保留已有路径，让依赖扫描按包内位置解析 Tcl/Tk。
- 在临时目录下载该版本上游锁定的 CPython 运行时并通过 SHA256 校验；已复现修复前的两项缺库，加入私有库路径后 `_tkinter` 的全部 `ldd` 依赖均可解析。
- Bash 语法检查通过；使用临时入口执行脚本的实际调用片段，确认 `LD_LIBRARY_PATH` 未设置、为空及已有值时均可解析，后续 `--make-appimage` 调用保留原环境。
- 该次本地依赖检查未进行完整 Arch 容器构建和 AppImage 封装，不代表整包构建成功。桌面启动和基础中文对话已由后续用户实测确认；中文输入法候选词行为、Office 功能及跨发行版兼容性尚未验证。

### 2026-10-07：补齐 _crypt 的 Arch 兼容库

- [后续 CI 构建](https://github.com/newyorkthink/linux-packaging/actions/runs/37615016607/job/112771213988) 仍在依赖扫描阶段中止：内置 CPython 的 `_crypt` 扩展需要 `libcrypt.so.1`，而当前基础安装项没有提供该兼容库；上轮本地检查仅覆盖 `_tkinter`，未核对其余扩展在 Arch 中的依赖。
- 修改 `deepseek-harness-desktop/build_deepseek-harness-desktop.sh`，通过公共安装入口独立追加 `libxcrypt-compat`，由该 [Arch 官方包](https://archlinux.org/packages/core/x86_64/libxcrypt-compat/files/) 提供 `libcrypt.so.1`；原有 AUR 编译命令和 Python 私有库路径处理保持原样。本文件同步记录此次修复。
- 在临时目录按该应用版本的上游锁定摘要校验并组装 Python、全部 wheel 和 Node；Arch 运行库按当前官方仓库数据库的摘要校验。使用 Arch 动态加载器关闭宿主库缓存，并核对每项解析路径都位于临时运行时或 Arch 库目录。
- 共检查 114 个 x86_64 ELF：CPython 13 个、原生 wheel 100 个、Node 1 个。基线仅 `_crypt` 缺少 `libcrypt.so.1`；加入 `libxcrypt-compat` 后全部依赖解析通过，Bash 语法检查通过。
- 该次检查仅针对上述同版运行时，没有完成 Electron 主程序及其原生模块的完整 AppImage 封装。桌面启动和基础中文对话已由后续用户实测确认；中文输入法候选词行为、Office 功能及跨发行版兼容性尚未验证。

### 2026-10-07：按 libc ABI 筛选原生依赖

- [后续 CI 构建](https://github.com/newyorkthink/linux-packaging/actions/runs/37618143431/job/112781458432) 已完成 AUR 编译及其运行时检查；quick-sharun 随后扫描 Koffi 的 musl 备用模块，因缺少 `libc.musl-x86_64.so.1` 中止。原筛选只区分 CPU 架构，未区分 libc ABI。
- 修改 `deepseek-harness-desktop/build_deepseek-harness-desktop.sh`，通过 `readelf` 读取 x86_64 ELF 的解释器和动态依赖，仅从依赖扫描输入中排除声明 musl 的文件。原始资源完整保留，既有安装命令和 quick-sharun 调用保持原样；本文件记录此次修复。
- 已按 npm SHA512 摘要校验失败构建使用的 Koffi 3.1.1 原生包，并直接执行修改前后的筛选片段。临时运行时样本的输入由 114 项减为 113 项，唯一排除项是 musl Koffi 模块；使用 Arch 动态加载器关闭宿主库缓存后，保留项均可解析依赖，原生包在保留 musl 文件时成功加载 GNU 模块。两个原生模块的文件摘要保持不变。
- Bash 语法、既有命令逐字保留和完整 diff 检查通过；本次只修改上述脚本和本文件。
- 完整 Arch 试构建停在临时测试环境的软件包初始化下载，尚未执行应用构建脚本，未取得 AppImage。桌面启动和基础中文对话已由后续用户实测确认；中文输入法候选词行为、Office 功能及跨发行版兼容性尚未验证。

### 2026-10-07：完整脚本检查与实测反馈

- 检查对象为 [e614503](https://github.com/newyorkthink/linux-packaging/commit/e61450335142c5397aabf7a94b8a819db2fbef7e) 的桌面版构建脚本、三个公共入口和 `build-anylinux` Action。已完整阅读并核对路径、参数、引号、执行顺序、软件包安装、原生依赖筛选、资源复制与相对路径、locale、产物及版本记录。四个脚本的 Bash 语法、共享 Action 的 YAML 与 Bash 片段检查通过；未发现需要继续修改脚本的明确问题，既有命令保持原样。
- 实测证据为用户提供的 AppImage 启动界面、终端输出及对话截图：桌面成功打开，账户接口返回 HTTP 200；使用 `gemma-4-31b-it` 发送中文消息后收到中文回复。本次未重新构建 AppImage，也未读取本次 CI 结果；实测产物与代码提交的对应关系未核对。
- 终端中的 Fontconfig 字体缓存版本警告没有阻止本次启动。首次对话显示“API 密钥无效”（AUTH），后续 Gemma 模型回复成功；首次失败请求的具体配置原因未核实。
- 当前已确认的运行范围为桌面启动及上述模型的基础中文对话。中文输入法候选词行为、Office 功能、其他模型及跨发行版兼容性尚未验证；保留既有构建脚本和公共流程。

### 2026-10-07：澄清源码与安装包来源

- 本次核对 [d24fdd4](https://github.com/newyorkthink/linux-packaging/commit/d24fdd4b4f9196d72d28713128852d4ef8c6f823) 中的来源表述，参考 DeepSeek 官方 [桌面工程说明](https://github.com/deepseek-ai/deepseek-harness/blob/master/apps/desktop/README.md) 和此前已核对的 AUR 配方。将应用主体、Linux 适配和安装包发布分别说明为官方桌面源码、AUR 社区维护的适配补丁及本仓库的 AppImage 封装发布；补丁和第三方原生依赖的既有说明完整保留。
- 本次仅修改本文件的来源说明并追加这条文档变更记录，完整 diff 核对通过。构建脚本、使用命令、既有检查与修复历史、已实测及未验证的运行范围保持原样。

### 2026-10-30：按标准整理脚本并复用公共版本入口

- 按已确认的 75 行草稿统一通用注释、空行和版本调用。用 `common/build/read_app_version.sh` 替换脚本内的三行版本解析，最终版本保存改为单行调用；本次不改变程序来源、安装顺序、复制布局、元数据、依赖收集或中文环境。
- 保留 simdjson 下载和安装、`libxcrypt-compat`、仅作用于一次扫描的 Python 私有库路径，以及独立许可证副本。前三项依据既有构建故障；许可证依据上游 MIT 分发要求，不能仅因基础模板没有该步骤而删除。
- 更新本文件的当前构建说明和已被后续实测取代的待验证表述，其他故障现象、检查边界及修复历史保留。同步补充固定配置、模板差异和打包分类；未修改工作流、公共脚本或其他应用。
- 提交前核对脚本与批准草稿逐字一致、Bash 语法、原有修复命令、文档路径及完整 diff。此前用户已实测确认的桌面启动和基础中文对话继续按通过处理；本次未重新构建 AppImage，不能据此声明新产物或 Office 等其他功能通过。
