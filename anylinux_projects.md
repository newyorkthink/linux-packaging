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

## 命令行不加中文，GUI 默认要

不用再等用户提醒。新做、迁移或这次本来就要改的构建，按程序有没有窗口决定：

| 程序 | 中文环境 | 中文输入 |
| --- | --- | --- |
| 只在终端运行，没有窗口和输入框，例如 htop、newsboat | 不加 | 不加 |
| 有窗口，包括 GTK、Qt、Electron、播放器界面 | 要 | 要 |

已经验证稳定的脚本不要为了补上本节去批量重写。某个应用实机证明某一套输入模块会弄坏它时，在该应用 README 写明并只去掉那一套；中文环境仍保留。

中文环境不依赖用户机器是否生成过 `zh_CN.UTF-8`。第一次 `quick-sharun` 生成 AppDir 之后、`--make-appimage` 之前写入：

```bash
mkdir -p AppDir/lib/locale
localedef --no-archive -i zh_CN -f UTF-8 AppDir/lib/locale/zh_CN.utf8
cat >> AppDir/.env <<'EOF'
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
LC_MESSAGES=zh_CN.UTF-8
LOCPATH=${SHARUN_DIR}/lib/locale
EOF
```

不要设置 `LC_ALL`。个别程序还要 `LC_NUMERIC=C` 时，写在这四行后面，不要改掉 `LANG`。

中文输入只装和这个程序实际 GUI 版本匹配的一套，和主程序放在同一次 `quick-sharun` 里。不要写 `AppRun.sh` 去设置输入法。

GTK 3 和用 GTK 3 的 Electron，安装 `ibus`、`fcitx5-gtk`：

```bash
quick-sharun /usr/bin/<主程序> \
  /usr/lib/gtk-3.0/3.0.0/immodules/im-ibus.so \
  /usr/lib/gtk-3.0/3.0.0/immodules/im-fcitx5.so
```

Qt 6 安装 `ibus`、`fcitx5-qt`，把这两个插件一并传入：

```text
/usr/lib/qt6/plugins/platforminputcontexts/libibusplatforminputcontextplugin.so
/usr/lib/qt6/plugins/platforminputcontexts/libfcitx5platforminputcontextplugin.so
```

GTK 4、Qt 5 也安装对应的 `fcitx5-gtk` 或 `fcitx5-qt`，再把安装后真实存在的 IBus 和 Fcitx5 模块传进去。文件不存在就停止构建，不要悄悄省掉中文输入，也不要把 GTK 3 的模块塞进 GTK 4 或 Qt 程序。

## 非必要不要自己写 AppRun.sh

quick-sharun 生成的 `AppRun` 就是启动入口。一般情况禁止再创建或覆盖：

- `AppRun.sh`
- `AppDir/AppRun`
- `AppDir/usr/bin/<程序名>` 这种只负责转发的 shell

需要补行为时，按这个顺序，仍然不要写 `AppRun.sh`：

1. 运行时环境变量写 `AppDir/.env`。中文 locale 用这里的 `LANG`、`LANGUAGE`、`LOCPATH`。
2. 启动前要改参数或准备目录时，写 `AppDir/bin/<名字>.hook`。上游现在用 `.hook`；本仓库已有的 `.src.hook` 只在该脚本本来就这样写时保留。hook 由生成的 `AppRun` 加载。说明见 [hook-system.md](https://github.com/pkgforge-dev/Anylinux-AppImages/blob/main/useful-tools/hooks/hook-system.md)。
3. 缺的是库或输入法模块时，先安装那个包，再把对应 `.so` 和主程序放在同一次 `quick-sharun` 参数里。

quick-sharun 上游生成的默认 `AppRun.sh` 会先按文件名顺序加载 `AppDir/bin/*.hook`，再把主程序放到当前参数最前面并执行。构建脚本不得为了设置环境或追加固定参数而预先创建自己的 `AppRun.sh`。

运行时需要相邻库目录或固定工作目录时，在第一次 `quick-sharun` 之后、`quick-sharun --make-appimage` 之前追加到现有 `.env`；必须使用运行时可解析的 `${SHARUN_DIR}`，并保留 quick-sharun 已经写入的内容。`.env` 是 quick-sharun 的通用运行时环境机制，与上游包是 Snap、DEB、tar 还是发行版 `/usr/bin` 入口无关；具体变量和值必须来自当前应用的真实布局。

`AppDir/shared/bin/` 不是 Snap 内自带的固定路径，也不是 quick-sharun 自动创建的统一目录。它是本仓库处理没有可用 `/usr/bin` 入口的非标准布局时，由当前构建脚本明确创建并选作解包目标的 AppImage 内部目录。对于 [BlueMail](./bluemail/build_bluemail.sh)和 [TradingView](./tradingview/build_tradingview.sh) 这类官方 Snap，构建脚本把需要保持相邻关系的 Electron 程序、库和资源完整解包到该目录，因此两个变量才指向 `shared/bin`。这不是所有 Snap 的固定写法，更不是所有 quick-sharun 项目的默认配置；目录布局不同的应用必须使用自己的真实路径，不需要额外库目录或固定工作目录时不得添加这些变量。

```bash
# BlueMail / TradingView 官方 Snap 布局示例：追加运行时环境，保留 quick-sharun 已写入的 .env 内容
cat >> "$APPDIR/.env" <<'ENV'
SHARUN_EXTRA_LIBRARY_PATH=${SHARUN_DIR}/shared/bin:${SHARUN_EXTRA_LIBRARY_PATH}
SHARUN_WORKING_DIR=${SHARUN_DIR}/shared/bin
ENV
```

hook 是 quick-sharun 生成入口提供的通用启动前扩展机制，同样不限定上游包格式；只要应用需要在启动前补固定参数或执行必要准备，就应优先使用 hook，而不是自行创建 `AppRun.sh`。应用每次启动都必须携带的固定参数统一写入 `AppDir/bin/90-<应用>-arguments.hook`。`90-` 是本仓库的顺序约定，不是上游保留编号：quick-sharun 当前内置 hook 使用 `01-`、`05-`、`07-` 和 `10-`，应用参数放在 `90-` 可在它们之后处理，并给真正的最终收尾保留 `99-`。固定参数放在用户参数之前，原有 `"$@"` 必须完整保留：

```bash
# 在上游内置 hook 之后追加应用固定参数，并保留用户传入参数
cat > "$APPDIR/bin/90-<应用>-arguments.hook" <<'HOOK'
set -- --固定参数 "$@"
HOOK
```

`STRACE_FLAGS` 只控制构建期间的 strace，传给 `quick-sharun --test` 或 `--simple-test` 的参数也只用于对应检查；这些都不会把固定参数写入最终 AppImage，不能代替运行时 hook。

只有 `.env` 和 hook 都解决不了，并且应用 README 写明了失败证据，才允许加别的启动包装。已有并且已经验证过的 `AppRun.sh` 不要为了本条删掉。

下面这些不算“特别情况”，不能用来给自己写 `AppRun.sh`：

- 程序在 `/usr/bin`，只是想包一层“更好启动”；
- 官方给的是下载器或更新器，真正的程序要另外取得。入口必须是能直接打开的程序，不能是安装器；
- 为了保险复制 `/usr/lib`。命令行程序不要预装输入法；GUI 只装和它自己的 GTK / Qt 版本匹配的那一套；
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
