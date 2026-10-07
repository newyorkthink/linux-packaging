# DeepSeek Harness 桌面版 AppImage

将 DeepSeek 官方 [deepseek-ai/deepseek-harness](https://github.com/deepseek-ai/deepseek-harness) 的桌面源码，通过 [AUR deepseek-harness-desktop](https://aur.archlinux.org/packages/deepseek-harness-desktop) 社区 Linux 配方编译，再封装为独立的 x86_64 AppImage。

## 定位与来源

- 这是社区 Linux 预览版，不是 DeepSeek 官方发布的 Linux 安装包；AppImage 构建与运行结果尚未验证。
- 官方桌面应用采用 Electron，并内置完整 dsh 运行时。它与仓库已有的 [deepseek-harness 浏览器版](../deepseek-harness/README.md) 分别构建、分别发布。
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
- 构建脚本通过 `common/arch/install_packages.sh` 安装当前 AUR 包和 GTK 3 输入模块；打包复用容器中已有的 quick-sharun。
- `/usr/bin/deepseek-harness-desktop` 是 shell 包装，实际打包入口为 `/usr/lib/deepseek-harness-desktop/deepseek-harness`。脚本同时收集内置原生组件的动态依赖，再补齐相邻资源和许可证。
- AUR 源码构建会下载工具链、Electron 和内置运行时，耗时与空间需求高于直接重打包现成二进制；构建任务设置 90 分钟超时。
- 唯一发布产物为 `dist/deepseek-harness-desktop.AppImage`。成功生成后写入 `dist/version.txt`，由现有流程立即发布版本信息。
- 手动构建时选择 `deepseek-harness-desktop/build_deepseek-harness-desktop.sh`；正常提交和每日构建沿用现有调度规则。

## 检查记录

### 2026-10-07：首次接入

- 已核对当前 AUR 配方、Linux 补丁、上游桌面说明和仓库已有 Electron 打包布局；本次仅新增独立桌面版。
- Bash 语法、JSON/YAML 解析、手动选项排序、公共入口路径和既有配置保留检查通过；已使用现有 Plan 脚本核对本次 push 仅选择新增桌面版，桌面版与浏览器版的手动入口分别选择对应项目。
- 尚未取得正式 CI 构建产物，也未进行图形启动、中文输入、Office 功能或跨发行版运行验证。
- 社区补丁和第三方原生依赖会随 AUR 配方更新；当前来源核对不代表后续版本或运行稳定性已经通过验证。

### 2026-10-07：修复内置 Python 的依赖扫描

- [首次 CI 构建](https://github.com/newyorkthink/linux-packaging/actions/runs/37611755057/job/112760445289) 已完成 `deepseek-harness-desktop 0.2.1alpha.1-1` 的 AUR 源码编译，并通过上游内置运行时与 Office 检查；随后 quick-sharun 扫描 `_tkinter` 时找不到 `libtcl9tk9.0.so` 和 `libtcl9.0.so`，构建中止，未生成 AppImage。
- 两项库位于内置 Python 的 `lib` 目录。仅为首次 quick-sharun 调用设置临时 `LD_LIBRARY_PATH`，加入该目录并保留已有路径，让依赖扫描按包内位置解析 Tcl/Tk。
- 在临时目录下载该版本上游锁定的 CPython 运行时并通过 SHA256 校验；已复现修复前的两项缺库，加入私有库路径后 `_tkinter` 的全部 `ldd` 依赖均可解析。
- Bash 语法检查通过；使用临时入口执行脚本的实际调用片段，确认 `LD_LIBRARY_PATH` 未设置、为空及已有值时均可解析，后续 `--make-appimage` 调用保留原环境。
- 本次未进行完整 Arch 容器构建和 AppImage 封装，也未验证 AppImage 的图形启动、中文输入、Office 功能或跨发行版运行；本地依赖检查不代表最终 AppImage 已构建成功。

### 2026-10-07：补齐 _crypt 的 Arch 兼容库

- [后续 CI 构建](https://github.com/newyorkthink/linux-packaging/actions/runs/37615016607/job/112771213988) 仍在依赖扫描阶段中止：内置 CPython 的 `_crypt` 扩展需要 `libcrypt.so.1`，而当前基础安装项没有提供该兼容库；上轮本地检查仅覆盖 `_tkinter`，未核对其余扩展在 Arch 中的依赖。
- 修改 `deepseek-harness-desktop/build_deepseek-harness-desktop.sh`，通过公共安装入口独立追加 `libxcrypt-compat`，由该 [Arch 官方包](https://archlinux.org/packages/core/x86_64/libxcrypt-compat/files/) 提供 `libcrypt.so.1`；原有 AUR 编译命令和 Python 私有库路径处理保持原样。本文件同步记录此次修复。
- 在临时目录按该应用版本的上游锁定摘要校验并组装 Python、全部 wheel 和 Node；Arch 运行库按当前官方仓库数据库的摘要校验。使用 Arch 动态加载器关闭宿主库缓存，并核对每项解析路径都位于临时运行时或 Arch 库目录。
- 共检查 114 个 x86_64 ELF：CPython 13 个、原生 wheel 100 个、Node 1 个。基线仅 `_crypt` 缺少 `libcrypt.so.1`；加入 `libxcrypt-compat` 后全部依赖解析通过，Bash 语法检查通过。
- 本次检查针对上述同版运行时；尚未完成 Electron 主程序及其原生模块的完整 AppImage 封装，也未验证图形启动、中文输入、Office 功能和跨发行版运行。最终构建及运行结果仍未验证。

### 2026-10-07：按 libc ABI 筛选原生依赖

- [后续 CI 构建](https://github.com/newyorkthink/linux-packaging/actions/runs/37618143431/job/112781458432) 已完成 AUR 编译及其运行时检查；quick-sharun 随后扫描 Koffi 的 musl 备用模块，因缺少 `libc.musl-x86_64.so.1` 中止。原筛选只区分 CPU 架构，未区分 libc ABI。
- 修改 `deepseek-harness-desktop/build_deepseek-harness-desktop.sh`，通过 `readelf` 读取 x86_64 ELF 的解释器和动态依赖，仅从依赖扫描输入中排除声明 musl 的文件。原始资源完整保留，既有安装命令和 quick-sharun 调用保持原样；本文件记录此次修复。
- 已按 npm SHA512 摘要校验失败构建使用的 Koffi 3.1.1 原生包，并直接执行修改前后的筛选片段。临时运行时样本的输入由 114 项减为 113 项，唯一排除项是 musl Koffi 模块；使用 Arch 动态加载器关闭宿主库缓存后，保留项均可解析依赖，原生包在保留 musl 文件时成功加载 GNU 模块。两个原生模块的文件摘要保持不变。
- Bash 语法、既有命令逐字保留和完整 diff 检查通过；本次只修改上述脚本和本文件。
- 完整 Arch 试构建停在临时测试环境的软件包初始化下载，尚未执行应用构建脚本，未取得 AppImage。整包构建、图形启动、中文输入、Office 功能和跨发行版运行仍未验证。
