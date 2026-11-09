# Android Tools 固定配置依据

本文记录 [当前构建脚本](../build_android-tools.sh) 中固定路径、名称与参数的用途及来源。实际流程差异见 [template-deviations.md](./template-deviations.md)，上游源码与采用决定见 [pkgforge-differences.md](./pkgforge-differences.md)。这些配置只属于当前程序，不作为其他应用的默认值。

## 固定配置与选择依据

| 配置 | 当前取值及用途 | 依据与影响 |
| --- | --- | --- |
| 官方 ZIP 地址 | `https://dl.google.com/android/repository/platform-tools-latest-linux.zip` | Google 的 Linux Platform Tools 最新版入口；URL 固定但下载的软件版本不锁定。来自上游依赖脚本与本仓库既有流程。 |
| 临时文件和目录 | `bin.zip`、`platform-tools/`、`AppDir/bin/`、`dist/` | 在当前应用目录内下载、解压、移动及封装；清理旧产物时必须保留预置图标和 PATH hook。 |
| 构建架构 | `ARCH="$(uname -m)"` | 构建时取容器真实架构；当前 Actions 的 Android Tools 正式任务使用 x86_64 构建环境。 |
| 应用名称 | `APPNAME=android-tools` | 与本仓库目录及固定 AppImage 资产名称对应；上游为 `Android_Tools`，本仓库沿用已有命名。 |
| 主程序入口 | `MAIN_BIN=adb` | Google ZIP 中的真实命令；上游同样指定 adb。其他工具通过同一 AppImage 参数或 PATH hook 分派。 |
| 桌面元数据 | `DESKTOP=DUMMY` | 原有 CLI 打包配置，由 quick-sharun 生成隐藏的 dummy desktop；不添加图形界面或用户可见菜单程序。 |
| 输出路径和名称 | `OUTPATH="$SCRIPT_DIR/dist"`、`OUTNAME=android-tools.AppImage` | 保持仓库发布清单中的资产名称，供统一 Actions 发布；最终版本写入 `dist/version.txt`。 |
| 更新信息 | `UPINFO="gh-releases-zsync|${GITHUB_REPOSITORY%/*}|${GITHUB_REPOSITORY#*/}|latest|android-tools.AppImage.zsync"` | 保留本仓库 `latest` Release 的固定 zsync 资产表达式；只是更新元数据，不代表配置了自动更新 hook 或证明远端存在该资产。 |
| 图标 | `AppDir/.DirIcon`、`AppDir/android-tools.png` | 两文件 Git blob 相同，沿用上游 PNG 图标；保留后可供 quick-sharun 获取 AppImage 图标。 |
| PATH hook | `AppDir/bin/make-symlinks-in-path.hook` | 上游独立文件原样保留；显式 `--make-symlinks` 时建立 `adb`、`fastboot` 等名称到 AppImage 的符号链接。 |
| 上游许可证文件 | `LICENSE` | 原样保留 pkgforge-dev 打包仓库的 GPL-3.0 文本；不能据此认定 Google 官方平台工具采用 GPL-3.0。 |
| 构建环境精简 | `get-debloated-pkgs --add-common --prefer-nano ! mesa ! vulkan` | 由 GitHub Actions 使用的 pkgforge Arch Linux 构建工具链提供；`mesa`、`vulkan` 是排除项。 |
| 精简后基础包 | 原有 `yay -S --noconfirm` 依赖恢复命令 | 历史日志已经出现 `unzip` 和 `patchelf` 缺失；原命令和执行顺序继续保留。 |
| 版本来源 | `AppDir/bin/source.properties` 的 `Pkg.Revision` | `awk` 动态读取实际下载的版本；缺失或解析为空时退出，不写死平台工具版本。 |
| udev 自动安装 | 不设置 `ADD_HOOKS` | 原有自动安装触发过启动弹窗；历史已验证去除后可正常调用 adb，具体见 README 修复记录。 |

## 既有故障与验收依据

- 精简环境后缺少 `unzip`、`patchelf` 的历史证据，以及恢复依赖后的成功构建，见 [README 修复记录](../README.md#修复记录)。
- 移除自动 udev 安装后的成功构建及实机 `adb version`、`adb devices` 验收仍以 [README 现有记录](../README.md#运行与兼容说明) 为准。
- 当前只维护配置和来源说明；不把静态核对或历史成功记录冒充本次代码提交的新构建结果。
