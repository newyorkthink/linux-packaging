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

Qt 6 安装 `ibus`、`fcitx5-qt`。当前 quick-sharun 在 `DEPLOY_QT=1` 且依赖列表包含 Qt 6 Gui 库时，会通过 `platform*/*` 收集 `platforminputcontexts/` 中已安装的输入模块，无需重复传入这些 `.so` 路径。以下路径用于定位这两个模块：

```text
/usr/lib/qt6/plugins/platforminputcontexts/libibusplatforminputcontextplugin.so
/usr/lib/qt6/plugins/platforminputcontexts/libfcitx5platforminputcontextplugin.so
```

GTK 4、Qt 5 也安装对应的 `fcitx5-gtk` 或 `fcitx5-qt`，再把安装后真实存在的 IBus 和 Fcitx5 模块传进去。文件不存在就停止构建，不要悄悄省掉中文输入，也不要把 GTK 3 的模块塞进 GTK 4 或 Qt 程序。

## Qt 主题插件

这段检查只在包里有 Qt 6 时出现。quick-sharun 在 qt6/plugins 里按文件名找 kvantum、qtlxqt、qt6ct。找不到就打出对应的一段警告。三段可以在同一次打包里连续出现。四行正文相同，只有第一行的插件名不同。

```text
WARNING: Qt was deployed but there is no kvantum plugin!
This means the application will lack proper theme support!
Install the packages that provide theme support before deploying
In archlinux those are: qt6ct kvantum lxqt-qtplugin

WARNING: Qt was deployed but there is no qtlxqt plugin!
This means the application will lack proper theme support!
Install the packages that provide theme support before deploying
In archlinux those are: qt6ct kvantum lxqt-qtplugin

WARNING: Qt was deployed but there is no qt6ct plugin!
This means the application will lack proper theme support!
Install the packages that provide theme support before deploying
In archlinux those are: qt6ct kvantum lxqt-qtplugin
```

In archlinux those are 后面固定是 qt6ct、kvantum、lxqt-qtplugin。三个名字每次都写全，不表示三个都缺。缺的是第一行点名的那个：kvantum、qtlxqt 或 qt6ct。

Qt 6 程序打包前安装 qt6ct、kvantum、lxqt-qtplugin。装上后由 quick-sharun 收进包里，不用再把插件路径传给 quick-sharun。

## 有窗口的 Qt 程序

有窗口且使用 Qt 6 的程序，标准脚本是 [obs-studio/build_obs-studio.sh](./obs-studio/build_obs-studio.sh)。相对 mpv 的默认形状，这个脚本增加了中文环境、Qt 主题插件，以及同一次交给 quick-sharun 的录制程序、模块目录、模块数据和脚本模块。图标、desktop、DEPLOY_* 和传给 quick-sharun 的路径来自该程序自己的官方包。

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

## Electron

Electron 的程序和旁边的资源在同一个目录里。不论文件来自系统安装，还是来自官方 DEB 或 tar，都把这个目录的全部内容放进 `AppDir/bin`，再交给 quick-sharun。不要先抽出主程序，也不要在打包后再把资源拷回去或做链接。

系统里已经装好时，程序目录通常在 `/usr/lib/<应用>`。`/usr/bin` 里如果只是转去运行这个目录的 shell，不用它当入口。菜单、图标和许可证如果在 `/usr/share`，从那些原路径读取。

### 直接下载安装包的标准模板

**后续使用 quick-sharun、需要直接下载官方 Electron 安装包的应用，以 [Cursor](./cursor/build_cursor.sh) 和 [WorkBuddy](./workbuddy/build_workbuddy.sh) 这两个构建脚本为标准。** 当前两份模板都下载官方 DEB；其他归档格式沿用相同执行阶段，按真实包格式选择公共入口，并在应用的差异文档中说明。分类入口见 [打包分类](./docs/packaging-classification.md)。

这项分类按最终程序文件的来源划分：安装 Arch / AUR 软件包用于依赖、图标、desktop 或既定版本元数据；最终程序文件仍单独从官方下载并解包的安装包取得。不要把安装依赖误写成从系统安装目录取得最终程序。

存在对应的 Arch / AUR 软件包时，通过公共安装入口安装它及所需依赖；没有对应软件包时，按实际依赖准备运行库。quick-sharun 只能收集构建环境中已有的库。图标和 desktop 优先读取已安装软件包提供的路径；确无此来源时，再从官方包取得资源并留在 AppDir 外供工具收集。

两份标准模板固定采用以下顺序：

| 阶段 | 固定做法 |
| --- | --- |
| 脚本初始化 | 严格模式，定位并切到脚本目录。 |
| 安装依赖 | 一行安装基础包，一行安装应用及其已确认依赖。 |
| 准备工作目录 | 清理 AppDir、dist、旧安装包和解包目录，再创建 AppDir/bin 与 dist。 |
| 下载 | 一条公共下载命令；当前两份 DEB 模板均排成三行，参数由调用方提供。 |
| 解包 | 一行调用公共解包入口。 |
| 复制程序 | 一行复制完整程序目录，保持相邻资源布局。 |
| 打包元数据 | 按 ARCH、APPNAME、MAIN_BIN、STARTUPWMCLASS、ICON、DESKTOP、OUTPATH、OUTNAME、DEPLOY_GTK 的顺序设置。 |
| 读取版本 | 在原有打包前位置，用一行公共调用赋给 VERSION。 |
| 收集依赖 | 一行调用 quick-sharun，附加参数只保留当前程序已确认需要的运行命令。 |
| 中文环境 | 在第一次 quick-sharun 后生成包内 locale，并追加到现有 .env。 |
| 最终封装 | 调用 quick-sharun --make-appimage。 |
| 保存版本 | 成功后用一行调用公共保存入口，不加续行符。 |

**总行数、代码结构、执行阶段、通用注释全文以及空行的位置和数量都属于模板。** 对照时逐行核对，不得忽略空行后宣布一致。软件名称、软件包、下载接口、路径、版本来源、元数据选项和必要辅助命令可以不同；具体原因写入该应用的 `docs/template-deviations.md`，固定配置依据写入 `docs/hardcoded.md`。不得把某个应用的专属参数机械复制给其他程序。

通用注释直接沿用两份标准脚本，保持泛化表述和原位置。版本读取统一使用 `# 读取本次打包使用的版本。`，保存统一使用 `# 打包成功后用公共脚本记下版本。`，注释均紧贴对应的单行调用。

### 公共版本读取与保存

`common/build/read_app_version.sh` 支持两种来源：

| 来源 | 参数 | 读取规则 |
| --- | --- | --- |
| package-json | package.json 的实际路径 | 用 jq 读取根对象中非空的字符串 version。 |
| pacman | 已安装的 Arch / AUR 包名 | 复用 common/arch/get_package_version.sh，去掉 epoch 和 pkgrel。 |

公共入口默认只向 stdout 返回版本，供调用方赋给 `VERSION`。`--version-file <路径>` 可保留既有构建版本文件写入，`--desktop <路径>` 可保留缺少 `X-AppImage-Version` 时追加版本的处理；这两项仅在当前程序确有需要时传入。所有输出路径都由应用脚本提供，公共代码不得写死应用名或布局。

下列代码用于说明调用格式，所有尖括号占位内容都须按实际应用替换后使用。应用脚本在各自原位置只保留一种来源的一行调用：

```bash
# 读取本次打包使用的版本。
VERSION="$("$SCRIPT_DIR/../common/build/read_app_version.sh" package-json "<package.json路径>")"
```

```bash
# 读取本次打包使用的版本。
VERSION="$("$SCRIPT_DIR/../common/build/read_app_version.sh" pacman "<已安装的包名>")"
```

读取必须在依赖安装、官方程序解包和复制完成之后，保留在第一次 quick-sharun 之前。Cursor 原有的构建版本文件和 desktop 版本字段通过可选参数在这个阶段处理；WorkBuddy 继续使用 AUR 安装版本。新增来源时扩展公共入口的来源分支，并补充对应说明和验证，不在应用脚本中重新实现解析。

保存仍调用现有 `common/build/save_appimage_version.sh`，只在最终 AppImage 成功生成后执行；其产物非空检查和版本写入行为保持不变：

```bash
# 打包成功后用公共脚本记下版本。
"$SCRIPT_DIR/../common/build/save_appimage_version.sh" "dist/<应用名>.AppImage" "$VERSION" dist/version.txt
```

两次公共调用分别服务于打包前和打包后的阶段，不挪动既定顺序。

### 依赖收集与中文环境

两种程序来源都在打包元数据阶段设置 `DEPLOY_GTK=1`，在版本读取之后对完整程序目录执行 `quick-sharun AppDir/bin/*`，并按真实需求保留额外运行参数。

GTK 3 输入模块由 quick-sharun 收集。构建环境里要已经装有这些模块，调用处不再传入模块路径。`chrome-sandbox` 留在程序目录里，不单独删除。显式设置 `MAIN_BIN` 后由工具生成 AppRun，不批量改写上游 desktop 的 `Exec`、`Icon` 或 Desktop Actions。

中文 locale 仍按有窗口程序的写法，加在第一次 quick-sharun 之后、`--make-appimage` 之前。没有这种并列资源、只是缺少 `/usr/bin` 入口的程序，仍按非标准布局放在 `AppDir/shared/bin`。

## 和 linuxdeploy 的分界

| 路线 | 规范 |
| --- | --- |
| Arch 包、`/usr/bin` 入口、标准 matrix | 本文 |
| 构建脚本实际调用 `linuxdeploy` | [`linuxdeploy_projects.md`](./linuxdeploy_projects.md) |

同一个应用不要两套一起上。选错路线时改脚本，不要用一个 `AppRun.sh` 把两条路线粘起来。