# Anylinux / quick-sharun 打包规范

本文件是本仓库用 quick-sharun 制作 AppImage 的强制规范，地位与 [`linuxdeploy_projects.md`](./linuxdeploy_projects.md) 相同。调用 `linuxdeploy` 的项目不要改走本文。

默认做法来自 [How to make truly portable AppImages](https://github.com/pkgforge-dev/Anylinux-AppImages/blob/main/HOW-TO-MAKE-THESE.md)，再用本仓库已经能工作的短脚本收窄：

- [`mpv/build_mpv.sh`](./mpv/build_mpv.sh)：`quick-sharun /usr/bin/mpv`
- [`htop/build_htop.sh`](./htop/build_htop.sh)：主程序加上运行时才会 dlopen 的库
- [`newsboat/build_newsboat.sh`](./newsboat/build_newsboat.sh)：同一个包里的两个 `/usr/bin` 入口一次传入

已经验证稳定的脚本继续以自身为准。不要为了套本文去批量改写 mpv、htop、newsboat。

## 上游流程里本仓库要遵守的部分

上游的基本顺序只有这五步：

1. 在 Arch 上安装应用和它自己的依赖。不要在会把 32 位库放进 `/usr/lib` 的发行版上打包。
2. 使用 quick-sharun。本仓库的 Arch 构建容器里已经有这个命令，**不要再把 `quick-sharun.sh` wget 进应用目录**。
3. 设置 `ICON`、`DESKTOP`、`OUTPATH`、`OUTNAME`。用软件包自带的图标和 desktop；上游没有时才在应用目录里补。
4. 把已经安装好的程序入口交给 quick-sharun，让它收集依赖并生成 `AppRun`。
5. 再执行一次 `quick-sharun --make-appimage`。

上游文档里的 `get-debloated-pkgs.sh`、为了瘦身替换 Mesa / Qt / GTK 的做法，不是本仓库默认步骤。没有该应用自己的验证记录时不要加。

## 一般情况就写成 mpv 这样

Arch 官方或 AUR 包安装后有 `/usr/bin/<主程序>` 时，新脚本只保留下面这个形状。备注说明每一行为什么在，不要再加启动脚本。

```bash
#!/usr/bin/env bash
# mpv 这类程序的默认写法：安装官方包，把 /usr/bin 入口交给 quick-sharun。
# quick-sharun 自己生成 AppRun。这里不要写 AppRun.sh。
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 打包工具。GTK、Qt、输入法不要塞进这一行。
"$SCRIPT_DIR/../common/arch/install_packages.sh" --base
# 应用本身。包管理器会拉入它声明的依赖。
"$SCRIPT_DIR/../common/arch/install_packages.sh" mpv

rm -rf -- AppDir dist
mkdir -p dist

export ARCH="$(uname -m)"
export ICON=/usr/share/icons/hicolor/scalable/apps/mpv.svg
export DESKTOP=/usr/share/applications/mpv.desktop
export OUTPATH="$SCRIPT_DIR/dist"
export OUTNAME=mpv.AppImage

# 入口是已经安装好的官方程序，不是安装器，也不是自己写的 shell。
quick-sharun /usr/bin/mpv
quick-sharun --make-appimage

# 成功之后才记版本。epoch 和 pkgrel 去掉。
version="$(pacman -Q mpv | awk '{print $2}')"
version="${version#*:}"
version="${version%-*}"
printf '%s\n' "$version" > dist/version.txt
```

对照：

| 写法 | 什么时候用 |
| --- | --- |
| `quick-sharun /usr/bin/mpv` | 一个官方入口。这是默认。 |
| `quick-sharun /usr/bin/htop /usr/bin/lsof /usr/lib/libsensors.so*` | 主程序还会拉起别的命令，或 dlopen 某个库。这些路径跟主程序放在同一次调用里。 |
| `quick-sharun /usr/bin/newsboat /usr/bin/podboat` | 同一个包有两个都要保留的入口。 |

`mpv/build_mpv.sh` 里另外三处是 mpv 自己的，别的程序不要照抄：

- 下载独立的 `yt-dlp` 放进 AppDir；
- 在 `AppDir/.env` 里写 `LC_NUMERIC=C`，避免非 C locale 影响 mpv；
- `AppDir/bin/mpv-launch-gui.src.hook`：没有参数时补 `--player-operation-mode=pseudo-gui`。

旧脚本里的 `yay -S` 和直接 `wget` 保持不动。新脚本，以及这次修改已经碰到的安装或下载，改成 `common/arch/install_packages.sh` 和 `common/download/download_file.sh`。

## 非必要不要自己写 AppRun.sh

quick-sharun 生成的 `AppRun` 就是启动入口。一般情况禁止再创建或覆盖：

- `AppRun.sh`
- `AppDir/AppRun`
- `AppDir/usr/bin/<程序名>` 这种只负责转发的 shell

需要补行为时，按这个顺序，仍然不要写 `AppRun.sh`：

1. 运行时环境变量写 `AppDir/.env`。中文 locale 用这里的 `LANG`、`LANGUAGE`、`LOCPATH`。
2. 启动前要改参数或准备目录时，写 `AppDir/bin/<名字>.hook`。上游现在用 `.hook`；本仓库已有的 `.src.hook` 只在该脚本本来就这样写时保留。hook 由生成的 `AppRun` 加载。说明见 [hook-system.md](https://github.com/pkgforge-dev/Anylinux-AppImages/blob/main/useful-tools/hooks/hook-system.md)。
3. 缺的是库或输入法模块时，先安装那个包，再把对应 `.so` 和主程序放在同一次 `quick-sharun` 参数里。

只有 `.env` 和 hook 都解决不了，并且应用 README 写明了失败证据，才允许加别的启动包装。已有并且已经验证过的 `AppRun.sh` 不要为了本条删掉。

下面这些不算“特别情况”，不能用来给自己写 `AppRun.sh`：

- 程序在 `/usr/bin`，只是想包一层“更好启动”；
- 官方给的是下载器或更新器，真正的程序要另外取得。入口必须是能直接打开的程序，不能是安装器；
- 为了保险复制 `/usr/lib`，或预先装一套用不到的 GTK / Qt / 输入法；
- 双击时要补默认参数。这用 hook 改 `"$@"`，mpv 的 GUI hook 就是这种写法。

## 仅当没有 /usr/bin 入口时

上游包把程序放在 `/opt/<应用>/`，或只提供 tar，没有可用的 `/usr/bin/<主程序>` 时，才把**应用自己的目录**放到 `AppDir/shared/bin/`，保持内部相对路径，然后：

```bash
quick-sharun ./AppDir/shared/bin/<真实主程序>
quick-sharun --make-appimage
```

不要把主程序塞进 quick-sharun 用来放启动器的 `AppDir/bin/`。不要复制整个 `/opt` 或整个 `/usr/lib`。如果包已经提供可用的 `/usr/bin` 启动器，仍走上一节，不要再复制一份。

## 和 linuxdeploy 的分界

| 路线 | 规范 |
| --- | --- |
| Arch 包、`/usr/bin` 入口、标准 matrix | 本文 |
| 构建脚本实际调用 `linuxdeploy` | [`linuxdeploy_projects.md`](./linuxdeploy_projects.md) |

同一个应用不要两套一起上。选错路线时改脚本，不要用一个 `AppRun.sh` 把两条路线粘起来。
