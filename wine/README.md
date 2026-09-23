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

### 完整逐条修复历史（永久保留）

以下内容恢复自本轮整理前的原始逐条修复记录，用于保留每次故障、失败方案、修复依据和当时的验证状态，防止后续 AI 重复试错。即使上方已有“当前稳定基线”摘要，本节也不得删除；如果以后长度过大，只能按根 `AGENTS.md` 的永久规则完整迁移到独立历史 MD，并从本 README 保留明确链接。

- **2026-09-21：修复中文环境注入后 winecfg 报“没有那个文件或目录”。** 上一版为了避免 Bash 自身处理无效的 `LC_ALL`，通过宿主 `/usr/bin/env` 最后注入中文环境；但 AppRun v2 会把宿主 env 视为包外目标并恢复包外执行环境，env 随后再执行 AppImage 内 Wine ELF 时已经不在 AppRun hook 的正常 inner-target 链路中，因此实机出现 `env: .../opt/wine-staging/bin/winecfg: 没有那个文件或目录`。现在改用 AppImage 已经打包的 `$APPDIR/usr/bin/env`，它作为包内目标继续由 AppRun 处理；LC_ALL 仍只在最终 Wine 子进程生效，不重新引入 wrapper 的 setlocale 警告或 localedef 启动开销。
- **2026-09-21：移除启动前 localedef，保留中文并消除 LC_ALL 警告。** 实机新包的 `winecfg` 已经正确显示简体中文，但仍在 wrapper 第 51 行输出 `setlocale: LC_ALL: cannot change locale (zh_CN.UTF-8)`，并且启动约 30 秒。继续对照 Wine 11.18 `ntdll/unix/env.c` 后确认，Wine 在 locale 无效/为 C 时会从 `LC_ALL` 环境变量回退解析 Windows locale；因此不需要先为 Bash/glibc 构造真实中文 locale。现在彻底删除 wrapper 的 `localedef`、`LOCPATH` 与 locale 缓存逻辑，并移除不再需要的 Jammy `locales` 包；只在最终 exec Wine 时通过 `/usr/bin/env` 注入 `LC_ALL=zh_CN.UTF-8`。这样不会让 Bash 自身调用 `setlocale()`，中文 UI 保持不变，同时去掉启动前额外工作。
- **2026-09-21：修复中文 locale 与 GLX fallback 自身造成的启动延迟。** 实机最新包明确输出 `setlocale: LC_MESSAGES: cannot change locale (zh_CN.UTF-8)`，证明把 Jammy 预编译 locale 通过 `LOCPATH` 直接交给较新宿主 glibc 的方案不可靠；同时上一版为写 `UseEGL=N` 先执行 `wine reg add`，会在真正打开 winecfg 前额外启动一次 Wine，正好重复触发原本要规避的慢初始化。现在改为携带 `locales` 源数据，并由宿主 `localedef` 生成与当前 glibc 匹配的可再生中文 locale 缓存；GLX fallback 则在安全条件满足时直接原子修改已有 Prefix 的 `user.reg`，不再预启动 Wine。构建检查同步改为强校验 `zh_CN` 源文件与 `UTF-8` charmap。
- **2026-09-21：修复 Wine 11.18 在 NVIDIA X11 上启动约 20 秒并继续修正中文 UI。** 实机新包已不再出现 `wineserver` / FreeType 故障，但 `winecfg` 打开前仍停顿约 20 秒并输出 `wgl:internal_context_create Failed to create internal global context`，且界面继续显示英文。Wine 11 在 X11 默认启用 EGL，同时官方仍支持 `HKCU\Software\Wine\X11 Driver\UseEGL=N` 强制 GLX；Wine Bugzilla 也已有 Wine 11/EGL 初始化异常通过禁用 EGL规避的案例。wrapper 现在仅在 NVIDIA + X11 且当前 Prefix 没有显式全局 `UseEGL` 时写入 `N`，已有设置不覆盖，Wayland 不处理。中文方面确认 glibc 的 `LC_ALL` 优先级高于 `LC_MESSAGES`；现在保留宿主 `LC_ALL` 对其他 locale 分类的实际效果后取消子进程 `LC_ALL`，再固定 `LC_MESSAGES=zh_CN.UTF-8`。构建同时强校验包内 `zh_CN.utf8/LC_MESSAGES/SYS_LC_MESSAGES`，避免再次出现“环境变量已写但 locale 数据不可用”的假修复。
- **2026-09-21：补齐简体中文 UI locale 与中文字体后备。** FreeType 修复后的实机截图确认 Wine 11.18 `winecfg` 已正常启动且此前 FreeType 缺失提示消失，但界面仍为英文。Wine 11.18 在 `ntdll/unix/env.c` 中从 `LC_MESSAGES` 解析用户 UI language；当前 wrapper 没有提供中文消息 locale。现在加入 Jammy `locales-all` 与 `fonts-wqy-zenhei`，wrapper 设置 `LOCPATH=$APPDIR/usr/lib/locale`、`LC_MESSAGES=zh_CN.UTF-8` 和 `LANGUAGE=zh_CN:zh`。只固定界面消息语言，不改 `LANG`、`LC_ALL`、日期、数字、排序、输入法或 `WINEPREFIX`。新成品仍需实机确认 winecfg 中文显示。
- **2026-09-21：修复包内 FreeType 已存在但 Wine 仍反复报告找不到 FreeType。** `wineserver` 修复后的实机反馈确认 `winecfg` 已能正常打开，同时终端反复出现 `Wine cannot find the FreeType font library`。对应构建日志确认 `libfreetype6`、`libpng16-16`、`libbrotli1` 和 `zlib1g` 均已同时部署 amd64/i386，因此不是漏装 FreeType。进一步核对 AppImageBuilder v2 源码确认其会把 `libz.so*` 归入 glibc compat runtime；较新的宿主选择 system runtime 后不会把 compat 库目录加入正常搜索路径，而 Wine 的 FreeType 后端通过 `dlopen()` 加载 `libfreetype.so.6`，其 32 位依赖链因此会在 zlib 处失败。现在由 `wine-staging.yml` 的 `after_runtime` 只把已打包的 32/64 位 zlib 恢复到正常 multiarch 库目录，同时保留 compat 中原文件；不复制旧 glibc、不修改 `WINEPREFIX`，也不要求宿主安装额外 32 位字体库。修改依据实机日志、当前成功构建日志和 AppImageBuilder/Wine 源码交叉核对；新成品仍需正常构建后由实机确认该提示消失。
- **2026-09-21：修复 `wine: could not exec wineserver`。** 用户实机运行当前 `wine.AppImage` 时，Wine 主程序能够启动但内部 `wineserver` 启动失败。Wine 当前源码在 `dlls/ntdll/unix/loader.c` 中通过 `posix_spawn()` 启动 server，而 AppRun v2 的 hook 只覆盖 `exec*` 路径；AppImageBuilder v2 同时会为包内 ELF 设置依赖 runtime 工作目录的相对解释器，因此 Wine 直接 spawn 真实 `wineserver` 时绕过了 AppRun 的运行时切换。现在新增绝对 `/bin/sh` 的 `wineserver-launcher`，由 `after_runtime` 在 AppImageBuilder 完成后放入 AppDir，并由 wrapper 通过 `WINESERVER` 指向它；launcher 随后用正常 `exec` 启动真实 server，使执行重新进入 AppRun hook。未改动默认 `~/.wine`、用户自定义 `WINEPREFIX`、WineHQ 双架构包、Mono/Gecko 或 GPU 驱动策略。源码与配置已按上游 Wine/AppRun 执行路径核对；提交后不监控 Actions，新的构建产物及实机运行结果仍需由本次正常构建确认。
- **2026-09-20：修复 AppImageBuilder 间接带入 Mesa 驱动后导致构建中止。** 在提交 `5a14f62` 的 Actions 构建中，Wine 11.18、amd64/i386、Mono 11.3.0 和 Gecko 2.47.4 均已下载并通过校验，但 AppImageBuilder 解析 Jammy 通用 GL/Vulkan 装载器的替代依赖时仍部署了 Mesa vendor 文件，最终被封装前的 GPU 驱动检查拦截。`build_wine.sh` 现在会在 AppImageBuilder 完成后精确移除 DRI、特定 VDPAU 驱动、Vulkan ICD、NVIDIA 库及 Mesa EGL/GLX vendor 库，并继续用原检查阻止残留文件进入产物；通用 OpenGL/Vulkan 装载器仍保留。修复已依据该失败日志和脚本静态检查确认，后续 Actions 构建及实机运行尚未验证。

## 2026-09-23 自根目录原样迁入

以下原文来自当时根目录 `PENDING_AI_TASKS.md` 和 `README.md` 的「当前待处理」，未改写。

## Wine

### 当前实机基线

截至 2026-09-21，用户已经用当前发布的 `wine.AppImage` 实机确认：

- `winecfg` 可以正常打开，GUI 可用；
- `winecfg` 已显示**简体中文**，中文环境修复完成；
- 早期的 `wine: could not exec wineserver` 已不再出现；
- 早期反复出现的 `Wine cannot find the FreeType font library` 已不再出现；
- 后续出现过的 `setlocale: LC_MESSAGES/LC_ALL: cannot change locale` 已不再出现在最新实机结果中；
- 早期截图中的 `wgl:internal_context_create Failed to create internal global context` 在最新实机结果中也已不再出现；
- 默认 Prefix 行为仍保持 Wine 官方语义：wrapper 不设置 `WINEPREFIX`，默认继续使用 `~/.wine`，用户显式传入的 Prefix 原样生效。

### 当前唯一明确遗留问题

- 从终端执行 `./wine.AppImage` 到 `winecfg` 窗口真正出现，实机仍需要约 **30 秒**。
- 这不是期望的日常启动速度。当前已经停止继续叠加猜测性修复，**暂不再改 Wine 包装代码**。
- 该问题不能再简单归因于中文 locale、FreeType、`wineserver`、此前的 EGL 报错或“第一次创建 Prefix”；这些方向已经分别处理过，最新实机仍保留约 30 秒延迟。

### 后续重新处理时的固定方法

后续只有在 AI coding 额度和上下文都足够时再继续。开始前必须重新完整阅读 `AGENTS.md`、本文件、`wine/build_wine.sh`、`wine/wine-staging.yml`、`wine/wrapper`、Wine workflow 以及当前上游 Wine/AppRun/AppImageBuilder 行为。

第一步**不是继续改代码**，而是对同一个现有 Prefix 做可重复的分段计时和系统调用/进程时间线采样，至少区分：

1. uruntime / DwarFS 挂载耗时；
2. AppRun 初始化、runtime 选择和 hook 注入耗时；
3. wrapper 自身耗时；
4. `wineserver` / `wineboot` / services 启动与等待耗时；
5. `winecfg` 进程创建到窗口可见的耗时。

优先使用 `time`、时间戳日志、`strace -f -tt -T`、进程树和必要的 Wine debug channel 做一次完整采样，再根据最长阻塞点决定是否需要处理 AppRun v2、Wine 11.x、Prefix service、DwarFS 或其他具体组件。

**禁止重复的方向：**

- 不得为了启动速度删除或重建用户 `~/.wine`；
- 不得把宿主 NVIDIA/Mesa 驱动或 ICD 打进 AppImage；
- 不得重新加入启动前 `wine reg add`、`localedef` 或其他会额外启动 Wine/增加启动阶段工作的逻辑；
- 不得回退已经实机确认有效的中文 UI、`wineserver-launcher`、FreeType/zlib 修复和 Prefix 语义；
- 在没有分段计时证据前，不得再把 30 秒延迟归因于某一个组件并直接修改。

根目录待办原文：

- `wine`：2026-09-21 当前实机基线为：`wine.AppImage` 可以正常启动 `winecfg`，简体中文界面已经确认；此前的 `wine: could not exec wineserver`、FreeType/zlib 加载失败、locale 警告和实机截图中的 `wgl:internal_context_create` 报错均已不再出现。**唯一明确保留的问题是启动仍需约 30 秒，当前暂不继续试错。** 后续有充足 AI coding 额度时，必须先按阶段计时并用 `strace`/进程时间线区分 uruntime 挂载、AppRun、wrapper、wineserver/wineboot、winecfg 各阶段耗时，再根据证据修复；不得继续通过修改 locale、GPU 驱动打包、删除 Prefix 或叠加启动前 Wine 命令来猜测。已确认中文、wineserver、FreeType 和 Prefix 行为不得回退。

后续处理原则原文第 3 条：Wine 的后续修复必须以真实构建产物和实机功能验证为准；构建成功、静态检查通过或代码看起来合理都不能替代实机结论。
