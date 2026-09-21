# Wine Staging AppImage

## 用途与设计目标

本目录构建固定资产名 `wine.AppImage`。它只跟踪 WineHQ 当前最新的 **Wine Staging**，不构建 stable/devel，也不把目标 Wine 版本写死在仓库里。每次构建会读取 WineHQ Ubuntu Jammy 的 amd64/i386 `Packages` 索引，选择两种架构共同存在的最新 staging 版本，并使用索引中的 SHA-256 校验下载包。

这里选择 Ubuntu 22.04（Jammy）作为运行库基线：Wine 本体保持最新 staging，同时比使用 Ubuntu 24.04 运行库有更低的 glibc 门槛。GitHub Actions 的构建 runner 是 Ubuntu 24.04，但包内用户态依赖来自 Jammy。

## 当前实机状态（2026-09-21）

当前发布基线已经由用户实机确认到以下状态：

- `wine.AppImage` 可以正常启动 `winecfg`；
- `winecfg` **简体中文界面已经修复并确认**；
- `wine: could not exec wineserver` 已修复；
- FreeType / zlib 依赖链已修复，早期 `Wine cannot find the FreeType font library` 不再出现；
- 之前出现过的 `setlocale: LC_MESSAGES/LC_ALL: cannot change locale` 在最新实机结果中不再出现；
- 之前截图中的 `wgl:internal_context_create Failed to create internal global context` 在最新实机结果中不再出现；
- wrapper 仍不设置 `WINEPREFIX`，默认 `~/.wine` 与用户自定义 Prefix 行为保持不变。

**当前唯一明确未解决的问题：启动速度。** 从执行 `./wine.AppImage` 到 `winecfg` 窗口出现，实机仍需要约 **30 秒**。这不是预期的日常启动速度，但当前先停止继续试错，等待以后 AI coding 能力/额度和完整上下文更充足时再处理。

### 后续启动延迟排查计划

以后重新处理前，先保持当前能正常运行、中文可用的基线不动。第一轮只做测量，不先改代码：

1. 分别记录 uruntime/DwarFS 挂载、AppRun 初始化、wrapper、`wineserver/wineboot`、`winecfg` 到窗口可见的耗时；
2. 对同一个现有 Prefix 使用 `strace -f -tt -T` 和进程树确认真正的长等待发生在哪个阶段；
3. 如果阻塞在 AppRun/runtime，再核对 AppRun v2、相对 ELF interpreter、双架构 hook 和 system/compat runtime；如果阻塞在 Wine 服务，则核对 Wine 11.x 的 server/service/driver 初始化；如果阻塞在挂载，则单独比较 uruntime/DwarFS；
4. 只有拿到最长阻塞点的直接证据后才修改，不再通过 locale、GPU、注册表或 Prefix 的猜测性调整逐项试错。

后续**不要重复**以下方向：删除/重建 `~/.wine`、打包宿主 GPU 驱动、重新加入启动前 `wine reg add`、重新加入 `localedef/LOCPATH`、回退中文环境、回退 `wineserver-launcher` 或 FreeType/zlib 修复。

## 包含与不包含的内容

- 同时放入 WineHQ 的 `wine-staging`、`wine-staging-amd64`、`wine-staging-i386`，不是只有 amd64 的缩水包。
- 同时收集 64/32 位音频、PulseAudio/ALSA/PipeWire、字体、GStreamer 全插件组、打印、相机、扫描仪、USB、PC/SC、OpenCL 装载器、OpenGL/Vulkan 装载器、网络与常见编解码运行库。
- 附带当前 winetricks `master` 的精确提交版本；构建日志会记录该脚本的 SHA-256。
- **不包含** Mesa DRI、Mesa Vulkan ICD、NVIDIA/AMD 专有驱动及 VA/VDPAU 驱动。显卡驱动必须使用目标电脑自身的驱动，避免换电脑后出现驱动 ABI 冲突。打印服务、设备权限和内核 32 位执行支持同样由宿主系统提供。

包体预计明显大于只带核心 Wine 的约 300 MiB 包；实际大小随 Wine 和 Ubuntu 依赖变化。这里优先保证双架构功能完整，再用 DwarFS 去重压缩。

## Mono / Gecko：只放在 AppImage 内

构建脚本读取当前 Wine tag 的 `dlls/appwiz.cpl/addons.c`，自动解析 Wine 期望的 Mono/Gecko 版本与 SHA-256，然后下载并校验：

```text
AppDir/opt/wine-staging/share/wine/mono/wine-mono-<版本>-x86.msi
AppDir/opt/wine-staging/share/wine/gecko/wine-gecko-<版本>-x86.msi
AppDir/opt/wine-staging/share/wine/gecko/wine-gecko-<版本>-x86_64.msi
```

运行时它们位于只读 AppImage 的 `/opt/wine-staging/share/wine/{mono,gecko}` 数据目录。Wine 创建新 Prefix 时会先找到这些内置 MSI，不需要从网络下载，因此不会再弹出“下载 Wine Mono/Gecko”的窗口。

本项目没有复制、链接、清理或替换 `~/.cache/wine` 的代码，也不会把 MSI 放进该缓存。更新 `wine.AppImage` 只是替换包内只读文件：

- 不删除 `~/.cache/wine` 的任何真实文件；
- 不删除用户已有 Prefix；
- 已有 Prefix 中已安装的组件由 Wine 自己判断是否需要升级；
- 新建 Prefix 会直接使用新版 AppImage 内与当前 Wine 匹配的 MSI。

Wine 或 Windows 应用仍会按正常行为写入 Prefix、XDG 缓存或临时目录；打包 wrapper 不额外创建 Mono/Gecko 缓存目录。

## Prefix 行为

wrapper **不设置 `WINEPREFIX`**，所以默认 Prefix 是 Wine 官方默认值：

```text
~/.wine
```

用户显式设置的 Prefix 会原样生效：

```bash
WINEPREFIX="$HOME/.wine-office" ./wine.AppImage winecfg
```

## 简体中文界面环境

Wine 11.18 的 Unix 初始化逻辑会从 locale 推导 Windows 用户 UI language；当 `setlocale()` 最终仍处于 `C` / 无效 locale 时，Wine 的 `unix_to_win_locale()` 会回退读取 `LC_ALL`。实机已经证明，仅向 Wine 进程提供 `LC_ALL=zh_CN.UTF-8` 即可让 `winecfg` 使用简体中文资源。

因此 wrapper 不再 `export LC_ALL`，也不再在启动前调用 `localedef` 或维护 `LOCPATH` 缓存。所有 Wine 原生命令只在最终 `exec` 时通过 `/usr/bin/env LC_ALL=zh_CN.UTF-8 LANGUAGE=zh_CN:zh` 注入环境：Bash wrapper 自身不会尝试切换到目标机不存在的中文 locale，所以不会再出现 `setlocale: LC_ALL: cannot change locale`；同时删除了每次启动前可能触发的 locale 编译和缓存检查。

`fonts-wqy-zenhei` 仍作为简体中文字体后备。这个方案不修改宿主 locale、不写 `/etc/locale.gen`，也不改变 `WINEPREFIX`。

## NVIDIA X11 的 EGL / GLX 兼容

Wine 11 在 X11 默认使用 EGL，并保留注册表 `HKCU\Software\Wine\X11 Driver\UseEGL=N` 作为官方 GLX fallback。部分 NVIDIA / 异常 EGL 设备环境会在 Wine 初始化 OpenGL context 时出现长时间停顿或失败。

wrapper 只在 **X11 + NVIDIA 驱动已加载 + 已有 Prefix 没有显式全局 `UseEGL` 值** 时设置 `UseEGL=N`，让 Wine 走 GLX；纯 Wayland不处理。上一版通过 `wine reg add` 写值，会在正式启动前额外启动一次 Wine，导致 EGL 初始化的长等待被先执行一遍。现在不再启动 Wine：仅在没有运行中 wineserver 时原子修改已有 Prefix 的 `user.reg`；新 Prefix 不预造注册表文件。用户已有 `UseEGL` 设置不覆盖，应用级 `AppDefaults\<程序>\X11 Driver\UseEGL` 仍由 Wine 按原优先级处理。

## 多命令与软链接

无参数运行会打开 `winecfg`：

```bash
./wine.AppImage
```

可以把子命令写在第一个参数：

```bash
./wine.AppImage winecfg
./wine.AppImage winetricks
./wine.AppImage wineserver -k
./wine.AppImage setup.exe
```

也可以把同一个文件链接成多个命令；AppRun 提供的 `ARGV0` 会让 wrapper 分派到同名程序：

```bash
install -Dm755 wine.AppImage "$HOME/.local/bin/wine.AppImage"
ln -sfn wine.AppImage "$HOME/.local/bin/wine"
ln -sfn wine.AppImage "$HOME/.local/bin/winecfg"
ln -sfn wine.AppImage "$HOME/.local/bin/wineserver"
ln -sfn wine.AppImage "$HOME/.local/bin/winetricks"
```

## AppRun 与路径映射

依赖部署使用 [AppImageCrafters/appimage-builder](https://github.com/AppImageCrafters/appimage-builder) 1.1.0，并固定 [AppImageCrafters/AppRun](https://github.com/AppImageCrafters/AppRun) v2.0.0。AppRun 把双架构 `libapprun_hooks` 放进 `LD_PRELOAD`，通过 `APPDIR_PATH_MAPPINGS` 将 Wine 编译时的 `/opt/wine-staging` 映射到只读 AppImage 内部。

当前 Wine 的 ntdll 使用 `posix_spawn()` 启动 `wineserver`，而 AppRun v2 的 exec hook 不覆盖 `posix_spawn()`。AppImageBuilder 又会把包内 ELF 的解释器改成依赖 AppRun runtime 工作目录的相对路径，因此 Wine 从已经恢复的用户工作目录直接 spawn 包内 `wineserver` 时可能报 `wine: could not exec wineserver`。

为保持现有 AppRun v2 双架构运行库不变，wrapper 将 `WINESERVER` 指向包内 `usr/bin/wineserver-launcher`。该 launcher 在 AppImageBuilder 完成 runtime 设置后才复制进去，保留绝对 `#!/bin/sh` shebang；Wine 可以先通过 `posix_spawn()` 启动宿主 `/bin/sh`，随后 shell 再通过正常 `exec` 进入 AppRun hook 并启动真实的包内 `wineserver`。这个处理不设置或修改 `WINEPREFIX`。

AppImageBuilder v2 会把 `libz.so*` 和 glibc 一起移到 `runtime/compat`。在 glibc 比 Jammy 更新的宿主上，AppRun 会选择 system runtime，此时 compat 库目录不会加入正常库搜索路径；双架构 Wine 的 32 位 FreeType 虽然已经打包，却可能因为找不到同包内的 32 位 zlib 而使 `dlopen(libfreetype.so.6)` 失败。recipe 的 `after_runtime` 因此只把已经打入 AppImage 的 32/64 位 zlib 恢复到各自 `usr/lib/<multiarch>` 目录；不会复制 compat glibc，也不要求宿主额外安装 FreeType 或 zlib。

这里**不加入** `project-portable/libunionpreload.so`，也不维护第二套 preload 逻辑。最终文件由 [VHSgunzo/uruntime](https://github.com/VHSgunzo/uruntime) 0.7.1 加 DwarFS 封装；uruntime 负责挂载/解包，AppRun 负责库环境和路径映射。

## Ubuntu 构建

在 x86_64 Ubuntu 环境中运行：

```bash
chmod +x wine/build_wine.sh
./wine/build_wine.sh
```

输出：

```text
wine/dist/wine.AppImage
wine/dist/version.txt
```

构建脚本会执行以下失败即停检查：WineHQ 三个包版本一致、全部外部下载通过 SHA-256、Mono/Gecko 与当前 Wine 源码常量一致、AppRun 同时含 x86_64/i386 hook、Wine 同时含 x86_64/i386 Unix loader、包内没有 GPU 驱动/ICD，且 wrapper 没有 `WINEPREFIX`、`~/.cache/wine` 或 `libunionpreload` 操作。

## 针对旧包问题的处理记录

旧的精简包可能在新 Prefix 首次启动时弹出 Mono/Gecko 下载框；如果 Wine 文件集或双架构依赖不完整，还可能出现 `failed to load start.exe, c0000135`、`RpcSs` 启动失败等连锁错误。本实现对应处理为：

1. WineHQ staging amd64/i386 包按同一版本成套放入；
2. Wine 官方声明的直接依赖和推荐依赖按 64/32 位成对收集，并补齐 GStreamer、字体和常见外设链；
3. Mono/Gecko 根据当前源码自动匹配并放入官方 Wine 数据目录；
4. `/opt/wine-staging` 由 AppRun hook 映射，不依赖宿主机同路径；
5. 显卡驱动留给宿主，避免把某一台构建机的驱动带到其他电脑。

## 修复记录

### 2026-09-21：当前稳定基线

本轮 Wine AppImage 已完成并由实机确认以下修复：

- **wineserver 启动链：** Wine 11.x 通过 `posix_spawn()` 启动 `wineserver`，AppRun v2 不 hook `posix_spawn`。当前使用包内 `wineserver-launcher` 先由绝对 `/bin/sh` 启动，再通过正常 `exec` 回到 AppRun hook 链，实机已不再出现 `wine: could not exec wineserver`。
- **FreeType / zlib：** AppImageBuilder v2 会把 `libz.so*` 归到 compat runtime；较新宿主选择 system runtime 时，32 位 FreeType 可能因此缺少包内 zlib。当前在 `after_runtime` 只把已打包的 32/64 位 zlib 恢复到正常 multiarch 目录，不复制 compat glibc。实机已不再出现 `Wine cannot find the FreeType font library`。
- **简体中文：** Wine 原生命令最终通过包内 `$APPDIR/usr/bin/env` 注入 `LC_ALL=zh_CN.UTF-8` 与 `LANGUAGE=zh_CN:zh`，避免 Bash wrapper 自身处理目标机不存在的中文 locale，也避免通过宿主 `/usr/bin/env` 脱离 AppRun inner-target 环境。实机 `winecfg` 已确认显示简体中文。
- **中文字体：** 保留 `fonts-wqy-zenhei` 作为中文字体后备。
- **GPU 处理：** AppImage 不打包宿主 Mesa/NVIDIA/AMD 驱动和 Vulkan ICD，只保留通用装载器；目标机 GPU 驱动继续由宿主提供。
- **Prefix 行为：** wrapper 不设置 `WINEPREFIX`，默认继续使用 `~/.wine`，用户显式传入的 Prefix 原样生效。
- **EGL/GLX 兼容：** 当前 NVIDIA + X11 兼容逻辑保留；不再通过启动前 `wine reg add` 额外启动一次 Wine。最新实机截图中此前的 `wgl:internal_context_create` 报错已不再出现。

### 仍未解决：启动约 30 秒

当前同一个可正常工作的 AppImage/Prefix，从命令执行到 `winecfg` 窗口出现仍约 **30 秒**。这项问题暂时搁置，不再在本轮继续增加补丁。

以后继续时必须先按本文“后续启动延迟排查计划”做分段计时和 `strace`，再按证据定位；构建成功、静态检查或单个错误消失都不能替代启动时间的实机结果。

### 已经试过且不要直接重复的方向

- 仅把 `LC_MESSAGES` 指向中文；
- 把 Jammy `locales-all` 的预编译 locale 直接通过 `LOCPATH` 给较新宿主 glibc；
- 启动前调用宿主 `localedef` 生成 locale 缓存；
- 通过启动前 `wine reg add` 设置 `UseEGL`；
- 使用宿主 `/usr/bin/env` 再执行包内 Wine ELF；
- 把问题简单归因于 GPU、locale 或第一次创建 Prefix，而没有分段计时证据。

这些历史尝试的价值仅用于避免以后重复走弯路；当前代码应以本 README 前面的“当前实机状态”和现有 wrapper/recipe 为准。
