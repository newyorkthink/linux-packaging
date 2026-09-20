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
