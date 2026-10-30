# mpv 固定配置依据

本文件解释实际固定输入“为什么这样写、具体值、用途及现有原始依据”。这些是当前包布局、标准输出约定或本次明确选择的行为，不代表每个值都有一次已经复现的故障。没有原始报错时如实说明，不用推测补造日志；模板结构差异见 [template-deviations.md](./template-deviations.md)，官方取舍见 [pkgforge-differences.md](./pkgforge-differences.md)。

## 当前固定输入

| 内容 | 固定取值与用途 | 选择依据及原始记录 |
| --- | --- | --- |
| 程序包和真实入口 | `mpv`、`/usr/bin/mpv`；安装 Arch 官方二进制并直接收集系统入口。 | [Arch mpv 包文件表](https://archlinux.org/packages/extra/x86_64/mpv/files/) 及本仓库原有入口；不是下载器或自写 shell，不为它制造 AppDir/bin 副本。没有新增入口故障记录。 |
| 应用级安装参数 | `mpv mpv-mpris glycin libheif xorg-server xorg-server-common xorg-server-xvfb`。 | 均为原脚本依赖；原有另外 10 个依赖由未修改的 --base 覆盖，完整映射见模板差异。保留安装不等于已确认最终 MPRIS 加载。 |
| 图标 | `/usr/share/icons/hicolor/scalable/apps/mpv.svg`。 | [Arch 包文件表](https://archlinux.org/packages/extra/x86_64/mpv/files/) 提供该文件，保留仓库原有 SVG；不机械替换成 pkgforge 的 PNG。无新增图标故障记录。 |
| 桌面入口 | `/usr/share/applications/mpv.desktop`。 | 同一 Arch 包提供，交给 quick-sharun；不另外改写 Exec、Icon 或窗口类。 |
| 架构与产物 | ARCH 从 `uname -m` 获取；当前 workflow 为 x86_64；`dist/mpv.AppImage`、`dist/version.txt`。 | 沿用应用清单中 `mpv` 的标准构建与资产约定；OUTPATH 从脚本所在目录生成，不含个人主机路径。这里的 yt-dlp_linux 资产仅对应当前 x86_64 路线，不据此承诺其他架构。 |
| 版本来源 | 公共版本入口的 `pacman mpv` 参数。 | 读取实际安装包并去掉 epoch、pkgrel；最终产物非空后公共保存入口写版本。不是固定 mpv 版本号。 |
| 独立辅助程序 | `yt-dlp/yt-dlp`、`yt-dlp_linux`、`AppDir/usr/bin/yt-dlp`。 | [yt-dlp 正式 Release 动态入口](https://github.com/yt-dlp/yt-dlp/releases/latest) 和现有本仓库内置方式；公共脚本动态取当前稳定资产、校验 GitHub SHA-256。不锁定 tag、旧下载地址或旧摘要。旧 patchelf 注释原文保存在下面，不声称本次复现破坏。 |
| locale | `echo 'LC_ALL=C.UTF-8' >> ./AppDir/.env`。 | [官方 make-appimage.sh](https://github.com/pkgforge-dev/mpv-AppImage/blob/953226d87422e9ef2307afacd2e049b1ee0a7f56/make-appimage.sh#L19-L22) 明确说明 mpv 的数值 locale 约束；本次经批准按原文采用。没有提供该故障的完整原始运行日志；不编造报错。 |
| 无参数窗口 hook | `mpv-launch-gui.src.hook`、`--player-operation-mode=pseudo-gui`。 | [官方独立 hook](https://github.com/pkgforge-dev/mpv-AppImage/blob/953226d87422e9ef2307afacd2e049b1ee0a7f56/AppDir/bin/mpv-launch-gui.src.hook) 说明双击无参数时需要该参数；可执行代码原样保留，文件作为 hook 加载。 |

## 旧实现原始记录

以下原样保留 [本次重写前 build_mpv.sh](https://github.com/newyorkthink/linux-packaging/blob/ccea4dfd3895d6ad5f905234d0aa369e6a2c70af/mpv/build_mpv.sh) 的两段注释和命令，供追溯旧处理依据。它们是旧源码记录，不是本次已经复现的错误日志。当前下载已改为公共入口；当前 locale 已明确改成官方 C.UTF-8，禁止按以下历史块恢复。

```bash
# Download standalone yt-dlp directly to AppDir to avoid patchelf corruption
mkdir -p AppDir/usr/bin
wget https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_linux -O AppDir/usr/bin/yt-dlp
chmod +x AppDir/usr/bin/yt-dlp

# Fix 'Non-C locale detected' for mpv
# Clear LC_ALL so it doesn't override LC_NUMERIC, keeping Chinese UI (LANG) intact
echo "LC_ALL=" >> AppDir/.env
echo "LC_NUMERIC=C" >> AppDir/.env
```

未取得当时运行命令输出、完整报错和复现记录，因此不把上述注释扩写成某个环境或版本已经确认的根因。当前 C.UTF-8 的原因直接来自官方源码说明及本次明确决定；它覆盖宿主 locale，不承诺保留中文界面。独立 yt-dlp 的放置顺序继续保留，但本次只核对了静态构建顺序和公共下载校验接口。

固定路径、资产名、参数或来源后续变化时，同次更新本页、模板差异与 README；不要只改脚本或依据旧记录自动恢复未启用功能。
