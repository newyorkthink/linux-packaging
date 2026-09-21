# Wine Staging AppImage

## 用途与设计目标

本目录构建固定资产名 `wine.AppImage`。它只跟踪 WineHQ 当前最新的 **Wine Staging**，不构建 stable/devel，也不把目标 Wine 版本写死在仓库里。每次构建会读取 WineHQ Ubuntu Jammy 的 amd64/i386 `Packages` 索引，选择两种架构共同存在的最新 staging 版本，并使用索引中的 SHA-256 校验下载包。

这里选择 Ubuntu 22.04（Jammy）作为运行库基线：Wine 本体保持最新 staging，同时比使用 Ubuntu 24.04 运行库有更低的 glibc 门槛。GitHub Actions 的构建 runner 是 Ubuntu 24.04，但包内用户态依赖来自 Jammy。

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

AppImage 默认把 Wine/Windows 程序的界面消息语言固定为 `zh_CN.UTF-8`。Jammy `locales-all` 已经提供独立的 `usr/lib/locale/zh_CN.utf8` 数据，wrapper 通过 `LOCPATH=$APPDIR/usr/lib/locale` 使用它；构建阶段同时强校验 `LC_MESSAGES/SYS_LC_MESSAGES` 必须真实存在，因此不依赖目标电脑是否生成中文 locale。

如果宿主导出了 `LC_ALL`，它会按 glibc 规则覆盖单独的 `LC_MESSAGES`。wrapper 现在先把宿主 `LC_ALL` 的当前有效值保留到字符集、日期、数字、排序等其他 locale 分类，再在 AppImage 子进程中取消 `LC_ALL` 并单独设置 `LC_MESSAGES=zh_CN.UTF-8`；因此中文 UI 可以生效，同时日期、数字、排序、字符集和输入法仍保持宿主原来的实际环境。

同时加入 `fonts-wqy-zenhei` 作为简体中文字体后备；宿主已有更合适的中文字体时，Fontconfig 仍可按正常规则选择。Wine 11.18 自身包含 `zh_CN` 翻译资源，Wine 初始化时会从 `LC_MESSAGES` 解析用户 UI language。

## NVIDIA X11 的 EGL / GLX 兼容

Wine 11 在 X11 默认使用 EGL，并保留注册表 `HKCU\Software\Wine\X11 Driver\UseEGL=N` 作为官方 GLX fallback。部分 NVIDIA / 异常 EGL 设备环境会在 Wine 初始化 OpenGL context 时出现长时间停顿或失败。

wrapper 只在 **X11 + NVIDIA 驱动已加载 + 当前 Prefix 没有显式全局 `UseEGL` 值** 时写入 `UseEGL=N`，让 Wine 走 GLX；纯 Wayland 不处理。用户已经设置的全局 `UseEGL` 不覆盖，Wine 自己的 `AppDefaults\<程序>\X11 Driver\UseEGL` 应用级设置仍保持更高优先级。这个兼容处理只写 Wine 的图形后端注册表值，不设置或改写 `WINEPREFIX` 路径，也不打包任何宿主 NVIDIA/Mesa 驱动。

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

- **2026-09-21：修复 Wine 11.18 在 NVIDIA X11 上启动约 20 秒并继续修正中文 UI。** 实机新包已不再出现 `wineserver` / FreeType 故障，但 `winecfg` 打开前仍停顿约 20 秒并输出 `wgl:internal_context_create Failed to create internal global context`，且界面继续显示英文。Wine 11 在 X11 默认启用 EGL，同时官方仍支持 `HKCU\Software\Wine\X11 Driver\UseEGL=N` 强制 GLX；Wine Bugzilla 也已有 Wine 11/EGL 初始化异常通过禁用 EGL规避的案例。wrapper 现在仅在 NVIDIA + X11 且当前 Prefix 没有显式全局 `UseEGL` 时写入 `N`，已有设置不覆盖，Wayland 不处理。中文方面确认 glibc 的 `LC_ALL` 优先级高于 `LC_MESSAGES`；现在保留宿主 `LC_ALL` 对其他 locale 分类的实际效果后取消子进程 `LC_ALL`，再固定 `LC_MESSAGES=zh_CN.UTF-8`。构建同时强校验包内 `zh_CN.utf8/LC_MESSAGES/SYS_LC_MESSAGES`，避免再次出现“环境变量已写但 locale 数据不可用”的假修复。
- **2026-09-21：补齐简体中文 UI locale 与中文字体后备。** FreeType 修复后的实机截图确认 Wine 11.18 `winecfg` 已正常启动且此前 FreeType 缺失提示消失，但界面仍为英文。Wine 11.18 在 `ntdll/unix/env.c` 中从 `LC_MESSAGES` 解析用户 UI language；当前 wrapper 没有提供中文消息 locale。现在加入 Jammy `locales-all` 与 `fonts-wqy-zenhei`，wrapper 设置 `LOCPATH=$APPDIR/usr/lib/locale`、`LC_MESSAGES=zh_CN.UTF-8` 和 `LANGUAGE=zh_CN:zh`。只固定界面消息语言，不改 `LANG`、`LC_ALL`、日期、数字、排序、输入法或 `WINEPREFIX`。新成品仍需实机确认 winecfg 中文显示。
- **2026-09-21：修复包内 FreeType 已存在但 Wine 仍反复报告找不到 FreeType。** `wineserver` 修复后的实机反馈确认 `winecfg` 已能正常打开，同时终端反复出现 `Wine cannot find the FreeType font library`。对应构建日志确认 `libfreetype6`、`libpng16-16`、`libbrotli1` 和 `zlib1g` 均已同时部署 amd64/i386，因此不是漏装 FreeType。进一步核对 AppImageBuilder v2 源码确认其会把 `libz.so*` 归入 glibc compat runtime；较新的宿主选择 system runtime 后不会把 compat 库目录加入正常搜索路径，而 Wine 的 FreeType 后端通过 `dlopen()` 加载 `libfreetype.so.6`，其 32 位依赖链因此会在 zlib 处失败。现在由 `wine-staging.yml` 的 `after_runtime` 只把已打包的 32/64 位 zlib 恢复到正常 multiarch 库目录，同时保留 compat 中原文件；不复制旧 glibc、不修改 `WINEPREFIX`，也不要求宿主安装额外 32 位字体库。修改依据实机日志、当前成功构建日志和 AppImageBuilder/Wine 源码交叉核对；新成品仍需正常构建后由实机确认该提示消失。
- **2026-09-21：修复 `wine: could not exec wineserver`。** 用户实机运行当前 `wine.AppImage` 时，Wine 主程序能够启动但内部 `wineserver` 启动失败。Wine 当前源码在 `dlls/ntdll/unix/loader.c` 中通过 `posix_spawn()` 启动 server，而 AppRun v2 的 hook 只覆盖 `exec*` 路径；AppImageBuilder v2 同时会为包内 ELF 设置依赖 runtime 工作目录的相对解释器，因此 Wine 直接 spawn 真实 `wineserver` 时绕过了 AppRun 的运行时切换。现在新增绝对 `/bin/sh` 的 `wineserver-launcher`，由 `after_runtime` 在 AppImageBuilder 完成后放入 AppDir，并由 wrapper 通过 `WINESERVER` 指向它；launcher 随后用正常 `exec` 启动真实 server，使执行重新进入 AppRun hook。未改动默认 `~/.wine`、用户自定义 `WINEPREFIX`、WineHQ 双架构包、Mono/Gecko 或 GPU 驱动策略。源码与配置已按上游 Wine/AppRun 执行路径核对；提交后不监控 Actions，新的构建产物及实机运行结果仍需由本次正常构建确认。
- **2026-09-20：修复 AppImageBuilder 间接带入 Mesa 驱动后导致构建中止。** 在提交 `5a14f62` 的 Actions 构建中，Wine 11.18、amd64/i386、Mono 11.3.0 和 Gecko 2.47.4 均已下载并通过校验，但 AppImageBuilder 解析 Jammy 通用 GL/Vulkan 装载器的替代依赖时仍部署了 Mesa vendor 文件，最终被封装前的 GPU 驱动检查拦截。`build_wine.sh` 现在会在 AppImageBuilder 完成后精确移除 DRI、特定 VDPAU 驱动、Vulkan ICD、NVIDIA 库及 Mesa EGL/GLX vendor 库，并继续用原检查阻止残留文件进入产物；通用 OpenGL/Vulkan 装载器仍保留。修复已依据该失败日志和脚本静态检查确认，后续 Actions 构建及实机运行尚未验证。
