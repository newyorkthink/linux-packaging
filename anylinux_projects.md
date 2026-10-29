# Anylinux / quick-sharun 打包规范

本文件是本仓库用 quick-sharun 制作 AppImage 的强制规范，地位与 [`linuxdeploy_projects.md`](./linuxdeploy_projects.md) 相同。调用 `linuxdeploy` 的项目不要改走本文。

默认做法来自 [How to make truly portable AppImages](https://github.com/pkgforge-dev/Anylinux-AppImages/blob/main/HOW-TO-MAKE-THESE.md)，再用本仓库已经能工作的短脚本收窄：

- [`mpv/build_mpv.sh`](./mpv/build_mpv.sh)：`quick-sharun /usr/bin/mpv`
- [`htop/build_htop.sh`](./htop/build_htop.sh)：主程序加上运行时才会 dlopen 的库
- [`newsboat/build_newsboat.sh`](./newsboat/build_newsboat.sh)：同一个包里的两个 `/usr/bin` 入口一次传入

已经验证稳定的脚本继续以自身为准。不要为了套本文去批量改写 mpv、htop、newsboat。

## 强制前置：核实 pkgforge-dev 官方打包并原样复用专属代码

**任何新建、修改、修复、迁移或重写应用打包脚本的任务，都必须先到 [pkgforge-dev 官方组织](https://github.com/pkgforge-dev) 查找当前应用是否已有官方打包仓库。不得跳过查找，直接凭经验、旧脚本或本仓库模板编写。**

1. 查找只限当前应用及其名称别名。找到对应官方仓库后，核对其实际构建脚本、相关 workflow 及被调用的 hook、wrapper 和说明文件，确认官方是否有当前应用的专属处理；不得借此遍历整个组织或检查其他应用。
2. 官方确有专属处理时，必须将对应命令和源码逐字原样复用到本仓库的 `build_*.sh`。命令、参数、路径、引号、大小写、通配符、管道、重定向、代码续行及执行顺序均不得改动；必要的变量赋值、函数定义和调用上下文不得漏掉。**逐字保留只针对可执行代码和命令本身，代码中的字符串及运行提示同样不得改写；上游注释不属于必须逐字保留的代码。**
3. **禁止修改上游官方打包命令。** 不得作等价改写，不得增删参数、替换程序、改路径、调整顺序、拆分或合并命令，不得把官方的下载命令替换为复制命令或公共入口调用，禁止以“功能相同”代替原样复用。
4. 官方独立提供的 hook、wrapper 等配套文件，必须在本仓库中按独立文件保存，其可执行代码逐字保留，禁止自行重写、简化或内联改造成另一套实现。注释按第 5 项处理，原有版权和许可证声明必须保留。其构建引用仍放在本应用的 `build_*.sh` 中；本仓库自写的引用或复制命令不得冒称官方原命令。
5. 直接复用的官方代码块正上方，必须用一行中文注释，采用“复用官方代码：……”清楚说明其通用用途。说明必须泛化，不夹带具体应用名、专属路径或版本号。**本次涉及的上游注释过于简略或不清楚时，可以补充或替换为通顺、完整的中文说明，不要求逐字保留原注释；不得因此改动任何可执行代码。** 只处理本次复用涉及的注释，不得改写范围外或已经确认的其他原注释。引用独立配套文件时，应明确写“文件内容复用官方代码”，不得把自写的文件复制命令标成官方原命令；补充解释仍须遵守第 7 项的官方原因与证据要求。
6. 对应应用的 `docs/template-deviations.md` 必须记录官方仓库、原文件路径、固定 commit 的源码链接、复用的具体代码及其所在构建阶段、用途、影响和官方原始原因；涉及固定配置时同步记入该应用的 `docs/hardcoded.md`。该应用的 `README.md` 必须说明复用了哪些官方处理、来自何处、官方为何这样做，并链接对应详细记录。代码和说明必须在同一次获批修改中完成，不得只写“参考官方”。
7. 官方原因必须以其源码注释、README、文档或 Issue 中的实际说明为依据，并给出原始出处。官方没有解释原因时，必须明确写“官方未说明原因”，禁止用 AI 推测、习惯判断或“应该需要”冒充官方理由。官方没有专属处理时，按本仓库标准模板执行，不添加或罗列不存在的特殊步骤。

**对经核实的官方专属代码，逐字原样复用要求优先于模板统一、公共入口替换、路径改写和注释统一的一般要求；不得为套用这些一般要求而修改官方命令。** 非官方专属代码仍遵守本仓库的标准模板和公共入口规则。原文与现有目录、构建环境或其他强制规则冲突时，只报告具体冲突，禁止自行改写、删掉或绕过官方处理。

本规则不授权批量整改既有应用、修改当前任务之外的文件或跳过修改授权。查找和核实始终受当前任务范围约束。

## 强制前置：两项来源核实与先安装再独立下载

新增、迁移、重写或本次获授权修改 quick-sharun / sharun 应用时，必须在当前应用范围内完成以下两项独立核实；找到其中一项，不得省略另一项：

| 必须核实的事项 | 核实范围 |
| --- | --- |
| pkgforge-dev 是否已有对应打包 | 查找当前应用及其名称别名，核对对应仓库的实际构建脚本、workflow 和配套文件；专属代码继续遵守原样复用规则。 |
| AUR、软件官方网站等是否已有现成二进制包 | 核对 AUR 的 PKGBUILD、`.SRCINFO` 和 Sources 中的实际下载地址，以及软件官方网站、官方软件包仓库或 Release 提供的包。包括适用于目标平台和架构的 DEB、RPM、含预编译程序的 tar.gz、tar.xz、ZIP 等；不得把源码归档当成现成二进制包，也不得只查软件官网而漏查 AUR。 |

**确认已有上述现成二进制包后，执行顺序固定为以下两个阶段，两个阶段都必须明确写入构建脚本，一项都不能省略：**

1. **先安装到构建系统。** 在隔离的 Arch 构建环境中安装当前应用及其真实运行依赖；存在对应 Arch / AUR 包时，安装该应用包，让包管理器拉入依赖。统一基础工具也必须安装，不能只装基础工具而省略应用安装。
2. **再独立下载并放入 AppDir/bin。** 在应用工作目录另行下载从当前 AUR 元数据、软件官方网站等核实得到的安装包，完成校验和解包后，将完整的真实程序目录原样放入 `AppDir/bin/`，保持程序与相邻资源的相对布局，再交给 quick-sharun 收集依赖和封装。

第一阶段的系统安装结果用于准备依赖、图标、desktop 及既定的版本元数据；最终程序文件必须来自第二阶段独立下载、解包的安装包。禁止把“安装后直接复制 `/usr/lib/<应用>/` 或 `/opt/<应用>/`”当成第二阶段，也禁止只下载解包而省略第一阶段。无法完成某一阶段时，报告具体阻塞，不得自行删掉该阶段或退回系统目录复制方案。

原脚本已经确认的基础工具和运行依赖必须逐项保留并核对覆盖关系。调用 `--base` 不等于已经证明原依赖全部齐备：必须对照公共基础包实际清单，已覆盖的依赖明确由公共入口保留，未覆盖的依赖在基础模板现有的应用依赖安装行补齐；不得漏包，也不得未经授权删除已验证的原安装命令。

固定的是上述两项核实和两个执行阶段；应用版本仍从当前 AUR 元数据或软件官方动态入口取得，不得因此锁定旧版本。安装、下载、校验和解包继续复用对应公共入口；已核实的 pkgforge-dev 专属代码继续按原样复用规则处理，发生具体冲突时按既有规则报告。

该两阶段规则优先于仅从系统 `/usr/bin` 入口直接打包或先放入 `AppDir/shared/bin` 的一般示例；只有核实没有上述适用的现成二进制包时，才按对应的一般示例判断。已经验证稳定且本次未涉及的应用保持原样，不得借本规则批量重写。

## 强制边界：禁止反复扩大查找、检查与修改范围

**禁止无新情况地反复核对、反复核查、重复搜索、重复读取、重复下载和重复验证。此类 AI 操作会过多消耗用户的 AI 对话额度、时间和工具调用次数。** 同一任务必须集中完成当前范围内必要的一轮检查，直接复用已有且仍适用的材料、证据和用户确认；不得以“再确认一次”“最后再检查一下”或“保证完整”为由追加检查轮次。只有相关内容发生变化、现有证据确实不足或本次检查失败时，才补查直接涉及的缺失部分，不得重新执行整套核查；完成后立即交付。

- 必须围绕用户当前指定的文件、应用和问题一次集中处理。禁止在查找、读取、分析、修改或验证过程中反复增加目录、文件、应用、问题和操作；不得以“官方核实”“避免遗漏”“再确认一次”或“保证完整”为由扩大范围。
- 已有完整且仍适用的内容、证据和用户确认必须直接复用。只有相关文件发生变化、原证据确实不足或本次检查失败时，才可在原任务范围内补查；禁止无依据地重复搜索、重复读取、重复下载和重复验证。
- 用户逐项提问或确认时，只回答和处理当前这一项。询问“官方有没有”时，只依据官方源码回答是否存在及原始做法，禁止擅自改成删除、替换、重写或追加处理方案；其他已确认事项保持不动。
- 必须扩大范围才能继续时，先说明当前阻塞、拟增加的具体文件和操作，取得用户后续明确同意后才能执行。AI 自己提出的计划、只读操作或已经开始的核查，均不构成扩大范围的授权。

## 上游流程里本仓库要遵守的部分

上游的基本顺序只有这五步：

1. 在 Arch 上安装应用和它自己的依赖。不要在会把 32 位库放进 `/usr/lib` 的发行版上打包。
2. 使用 quick-sharun。本仓库的 Arch 构建容器里已经有这个命令，**不要再把 `quick-sharun.sh` wget 进应用目录**。
3. 设置 `ICON`、`DESKTOP`、`OUTPATH`、`OUTNAME`。用软件包自带的图标和 desktop；上游没有时才在应用目录里补。
4. 已有适用的 DEB、预编译 tar.gz 等包时，将第二阶段独立下载、解包后放入 `AppDir/bin` 的完整程序交给 quick-sharun；仅未找到上述现成包时，才按对应一般示例使用系统安装入口。由 quick-sharun 收集依赖并生成 `AppRun`。
5. 再执行一次 `quick-sharun --make-appimage`。

上游文档里的 `get-debloated-pkgs.sh`、为了瘦身替换 Mesa / Qt / GTK 的做法，不是本仓库默认步骤。没有该应用自己的验证记录时不要加。

## 一般情况就写成 mpv 这样

仅在完成两项来源核实、未找到适用的现成二进制包，且 Arch 官方或 AUR 包安装后有 `/usr/bin/<主程序>` 时，新脚本才使用下面这个形状。已有 DEB、预编译 tar.gz 等包时，必须执行前述两阶段规则。备注说明每一行为什么在，不要再加启动脚本。

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

本节保留既有非标准布局的示例；当前新建或修改的应用，已经从 AUR、软件官方网站等确认有适用的现成二进制包时，必须执行前述两阶段规则，不得套用本节替代独立下载步骤。

上游包把程序放在 `/opt/<应用>/`，或只提供 tar，没有可用的 `/usr/bin/<主程序>` 时，才把**应用自己的目录**放到 `AppDir/shared/bin/`，保持内部相对路径，然后：

```bash
quick-sharun ./AppDir/shared/bin/<真实主程序>
quick-sharun --make-appimage
```

不要把主程序塞进 quick-sharun 用来放启动器的 `AppDir/bin/`。不要复制整个 `/opt` 或整个 `/usr/lib`。如果包已经提供可用的 `/usr/bin` 启动器，仍走上一节，不要再复制一份。

## Electron

Electron 的程序和旁边的资源在同一个目录里。当前新建或修改的应用，必须先核实 pkgforge-dev 是否已有打包，以及 AUR、软件官方网站等是否已有现成二进制包。已有 DEB、预编译 tar.gz 等包时，先安装到构建系统，再独立下载、解包，将完整程序目录原样放进 `AppDir/bin`，不得用系统安装目录复制替代第二阶段。不要先抽出主程序，也不要在打包后再把资源拷回去或做链接。

系统里已经装好时，程序目录通常在 `/usr/lib/<应用>`。`/usr/bin` 里如果只是转去运行这个目录的 shell，不用它当入口。菜单、图标和许可证如果在 `/usr/share`，从那些原路径读取。

### 直接下载安装包的标准模板

**后续使用 quick-sharun、需要直接下载官方 Electron 安装包的应用，以 [Cursor](./cursor/build_cursor.sh) 和 [WorkBuddy](./workbuddy/build_workbuddy.sh) 这两个构建脚本为标准。** 当前两份模板都下载官方 DEB；其他归档格式沿用相同执行阶段，按真实包格式选择公共入口，并在应用的差异文档中说明。分类入口见 [打包分类](./docs/packaging-classification.md)。

这项分类按最终程序文件的来源划分：先安装 Arch / AUR 软件包，准备依赖、图标、desktop 或既定版本元数据；再从已核实的 AUR 下载来源、软件官方网站等单独下载并解包安装包，取得最终程序文件。两个阶段都必须保留，不得从系统安装目录直接复制程序来替代第二阶段。

存在对应的 Arch / AUR 软件包时，通过公共安装入口安装它及所需依赖；没有对应软件包时，必须先核实可行的系统安装方式和真实依赖，无法完成则报告具体阻塞，不得只准备运行库就省略应用的系统安装。quick-sharun 只能收集构建环境中已有的库。图标和 desktop 优先读取已安装软件包提供的路径；确无此来源时，再从已下载的安装包取得资源并留在 AppDir 外供工具收集。

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