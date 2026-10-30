# Anylinux / quick-sharun 打包规范

本文件是本仓库用 quick-sharun 制作 AppImage 的强制规范，地位与 [`linuxdeploy_projects.md`](./linuxdeploy_projects.md) 相同。调用 `linuxdeploy` 的项目不要改走本文。

默认做法来自 [How to make truly portable AppImages](https://github.com/pkgforge-dev/Anylinux-AppImages/blob/main/HOW-TO-MAKE-THESE.md)，再用本仓库已经能工作的短脚本收窄：

- [`mpv/build_mpv.sh`](./mpv/build_mpv.sh)：`quick-sharun /usr/bin/mpv`
- [`htop/build_htop.sh`](./htop/build_htop.sh)：主程序加上运行时才会 dlopen 的库
- [`newsboat/build_newsboat.sh`](./newsboat/build_newsboat.sh)：同一个包里的两个 `/usr/bin` 入口一次传入

已经验证稳定的脚本继续以自身为准。不要为了套本文去批量改写 mpv、htop、newsboat。

## 强制前置：核实 pkgforge-dev 官方打包并原样复用专属代码

**任何新建、修改、修复、迁移或重写应用打包脚本的任务，都必须先到 [pkgforge-dev 官方组织](https://github.com/pkgforge-dev) 查找当前应用是否已有官方打包仓库。不得跳过查找，直接凭经验、旧脚本或本仓库模板编写。** **本项核实必须在展示草稿之前完成。必须提供所读固定 commit、原文件及对应原文；禁止先凭经验贴代码、再补查官方，或用“规则已经写明”代替实际核实。**

1. 查找只限当前应用及其名称别名。找到对应官方仓库后，核对其实际构建脚本、相关 workflow 及被调用的 hook、wrapper 和说明文件，确认官方是否有当前应用的专属处理；不得借此遍历整个组织或检查其他应用。
2. 官方存在专属处理时，必须先按下文判断当前场景是否必要；本次决定采用并直接复用的对应命令和源码，必须逐字原样保留在本仓库的 `build_*.sh` 中。命令、参数、路径、引号、大小写、通配符、管道、重定向、代码续行及执行顺序均不得改动；必要的变量赋值、函数定义和调用上下文不得漏掉。**逐字保留只针对可执行代码和命令本身，代码中的字符串及运行提示同样不得改写；上游注释不属于必须逐字保留的代码。**
3. **禁止修改本次决定直接复用的上游官方打包命令。** 不得作等价改写，不得增删参数、替换程序、改路径、调整顺序、拆分或合并命令，不得把官方的下载命令替换为复制命令或公共入口调用，禁止以“功能相同”代替原样复用。
4. 本次决定采用的官方独立 hook、wrapper 等配套文件，必须在本仓库中按独立文件保存，其可执行代码逐字保留，禁止自行重写、简化或内联改造成另一套实现。注释按第 5 项处理，原有版权和许可证声明必须保留。其构建引用仍放在本应用的 `build_*.sh` 中；本仓库自写的引用或复制命令不得冒称官方原命令。
5. 直接复用的官方代码块正上方，必须用一行中文注释，采用“复用官方代码：……”清楚说明其通用用途。说明必须泛化，不夹带具体应用名、专属路径或版本号。**本次涉及的上游注释过于简略或不清楚时，可以补充或替换为通顺、完整的中文说明，不要求逐字保留原注释；不得因此改动任何可执行代码。** 只处理本次复用涉及的注释，不得改写范围外或已经确认的其他原注释。引用独立配套文件时，应明确写“文件内容复用官方代码”，不得把自写的文件复制命令标成官方原命令；补充解释仍须遵守第 7 项的官方原因与证据要求。 **同一用途的来源标注和标准注释必须逐字一致。直接采用官方命令统一使用“复用官方代码：”；引用官方独立文件统一使用“文件内容复用官方代码：”，不得用“保留原有处理”或“参考官方”替代。与官方原文不同的既有兼容代码必须明确标为“本仓库兼容处理：”，并列出差异，禁止冒称原样复用。quick-sharun 的已定用途注释以 `anylinux_projects.md` 中的注释表为准；不得在草稿或实际文件中自行换词。**
6. 对应应用的 `docs/template-deviations.md` 必须记录官方仓库、原文件路径、固定 commit 的源码链接、复用的具体代码及其所在构建阶段、用途、影响和官方原始原因；涉及固定配置时同步记入该应用的 `docs/hardcoded.md`。该应用的 `README.md` 必须说明复用了哪些官方处理、来自何处、官方为何这样做，并链接对应详细记录。代码和说明必须在同一次获批修改中完成，不得只写“参考官方”。
7. 官方原因必须以其源码注释、README、文档或 Issue 中的实际说明为依据，并给出原始出处。官方没有解释原因时，必须明确写“官方未说明原因”，禁止用 AI 推测、习惯判断或“应该需要”冒充官方理由。官方没有专属处理时，按本仓库标准模板执行，不添加或罗列不存在的特殊步骤。


### 官方复用与本仓库兼容处理的注释

先对照已核实的官方原文判断来源，再选择下表注释。同一用途必须逐字复用，包括前缀、正文、标点、注释位置及相邻空行。不能只保留相同意思，也不能先换词再称为符合模板；其他用途应先在对应标准中明确注释，不借此批量改写已有稳定应用。

| 代码来源与用途 | 固定注释 |
| --- | --- |
| 官方原文：未传入参数时启用窗口模式 | `# 复用官方代码：未传入参数时启用窗口模式。` |
| 本仓库复制上述官方独立文件，文件内容原样复用 | `# 文件内容复用官方代码：未传入参数时启用窗口模式。` |
| 官方原文：固定运行时 locale | `# 复用官方代码：固定运行时 locale。` |
| 本仓库既有实现：在依赖收集后下载并校验独立辅助程序 | `# 本仓库兼容处理：在依赖收集后下载并校验独立辅助程序。` |
| 其他已确认保留的本仓库 locale 实现 | `# 本仓库兼容处理：清空全局 locale 覆盖，并固定数值解析所用的 locale。` |

官方独立 hook 必须保存为独立文件。构建脚本中的复制命令是本仓库的引用代码，不能标成官方原命令；官方文件内的有效命令、参数和顺序原样保留。与官方不同且已确认保留的本仓库 locale 实现必须标明来源，并在应用差异文档中同时列出官方原文、现有代码及保留原因。mpv 本次已明确改用官方 `LC_ALL=C.UTF-8`，旧 `LC_ALL=` / `LC_NUMERIC=C` 两行仅作为历史记录，不再执行。

### 先判断是否必要，采用和不采用都必须记录

**pkgforge-dev 的打包实现是核实来源，不代表其中每一步在本仓库都正确、必要或适用。不得因为“官方有”或“旧脚本有”就直接加入，也不得因为标准模板没有就直接删除已确认必要的处理。**

1. 逐项说明当前处理解决什么实际问题、由谁使用，以及标准模板、已安装软件包或公共入口是否已经覆盖。结合当前程序版本、目录布局和构建方式判断；没有实际需要或没有充分依据时，不加入正式构建。
2. 只有本次判定需要、适用于当前场景且在用户授权范围内的专属处理，才接入构建。决定直接复用官方实现后，可执行代码仍须逐字原样保留；不得借必要性判断改写官方命令。上游注释可以按上述要求补充中文说明。
3. **采用和不采用都必须写入当前应用的 `docs/pkgforge-differences.md`。** 每项写明官方仓库、固定 commit、原文件路径与源码链接、相关原始代码、可核实的作用、官方原因、当前决定、具体依据、影响和验证边界；官方未解释原因时明确写“官方未说明原因”，推断不得冒充官方理由。
4. `docs/template-deviations.md` 记录当前实际启用的模板差异，未采用项明确标记为“未启用”并链接上述判断；`docs/hardcoded.md` 记录实际固定配置的依据；README 概述采用和不采用的内容并提供文档入口。代码、注释和说明在同次修改中保持一致。
5. 标准模板没有的压缩设置、协议入口复制、运行开关、辅助程序和 hook 等，均须经过上述判断。只复制包内协议 desktop 不能证明宿主协议已登记；必须核实实际消费者和登记流程，不得把文件存在写成回调功能已实现。
6. 已确认稳定且本次未涉及的代码保持原样。用户明确要求暂不采用的处理，继续遵守下节要求；记录原文不构成启用授权。

### 采用项必须列出对应构建代码

- `docs/pkgforge-differences.md` 的取舍表必须包含“处理”“决定”“对应代码”“当前依据、用途与影响”四列，不能只写“采用”或所在阶段。
- 采用项必须列出实际完整命令，或引用本页的完整代码块，并提供对应 `build_*.sh` 的文件路径和精确行号链接。标准模板已有步骤同样要对应到实际代码；只提供官方源码链接不能代替本仓库的落地位置。
- 同一条命令覆盖多项处理时，各项指向同一条完整命令，不得为了分列说明而拆改命令、删减参数或用省略号冒充原文。是否属于标准步骤、直接复用官方代码或本仓库自写集成，必须标明。
- 未采用项写明“未启用”，不得填写成现有执行代码；如果使用标准步骤或公共入口替代官方做法，必须分别标明“官方命令未启用”和实际替代代码的位置，不能混为原样复用。
- 取舍表、代码原文、文件路径和行号必须与当前构建一致。使用固定 commit 的链接时，核对该快照与当前对应代码一致；后续代码变更或移动时同步更新说明和链接，不得因补文档擅自改动稳定代码。

### 用户明确暂不采用官方专属处理

用户明确要求当前只按基础模板打包、暂不加入已经核实的 pkgforge-dev 专属处理时，必须遵守以下要求：

1. 仅按本次批准的基础模板实现，不得主动把这些专属处理、hook、wrapper、补丁、额外依赖部署代码或运行开关接入正式构建和启动链；不得把“已保存说明”当成已获准启用。应用包自身的正常依赖安装继续按基础模板执行，不等于额外启用上述专属代码。
2. 在当前应用的 `docs/pkgforge-differences.md` 中记录官方仓库、所读 commit、原文件路径和固定源码链接，保存有关原始代码或配套文件内容，逐项说明其作用、官方给出的原因、本次未采用的决定及影响。官方未说明原因时如实注明；代码作用、依据源码作出的推断和官方原始理由必须分开，不得混为一谈。
3. 应用 README 必须说明当前采用的基础流程、哪些专属处理没有加入，以及对应的详细记录入口。`docs/template-deviations.md` 记录当前实际启用的参数和差异，暂不采用的内容单独标记为“未启用”，不得写成现有功能。
4. 后续用户明确要求加入某一处理时，必须只针对该处理重新查看 pkgforge-dev 对应仓库的当前源码，确认它是否仍存在、是否已改写或被移除，并核对当前应用版本及构建布局是否仍适用。历史文档中的固定 commit 只作为证据，不得直接照抄旧快照恢复处理。
5. 重新核实后，向用户说明该处理当前的原文、作用、实际影响和具体修改范围；只有取得针对本次加入的明确同意后才实施，并同步更新 README、差异文档及固定配置依据。官方已经删除或不再适用的处理，不得自动恢复。
6. 除这一明确批准的暂不采用范围外，其他已经核实并获准复用的官方代码继续遵守逐字保留要求；不得把此情况扩大成跳过官方来源核实或擅自删改其他应用的许可。

**先判断当前场景是否需要，再决定是否复用。对本次决定直接复用的官方专属代码，逐字原样保留要求优先于模板统一、公共入口替换、路径改写和注释统一的一般要求；不得为套用一般要求而修改这些官方命令，也不得反过来强制加入已经判定不必要或不适用的处理。** 未采用的处理按上述要求记录；其他代码仍遵守本仓库标准模板和公共入口规则。已决定复用的原文与现有目录、构建环境或其他强制规则冲突时，只报告具体冲突，禁止自行改写、删掉或绕过。

本规则不授权批量整改既有应用、修改当前任务之外的文件或跳过修改授权。查找和核实始终受当前任务范围约束。

## 强制前置：两项来源核实与程序来源

新增、迁移、重写或本次获授权修改 quick-sharun / sharun 应用时，必须在当前应用范围内完成以下两项独立核实；找到其中一项，不得省略另一项：

| 必须核实的事项 | 核实范围 |
| --- | --- |
| pkgforge-dev 是否已有对应打包 | 查找当前应用及其名称别名，核对对应仓库的实际构建脚本、workflow 和配套文件；专属代码继续遵守原样复用规则。 |
| AUR、软件官方网站等是否已有现成二进制包 | 核对 AUR 的 PKGBUILD、`.SRCINFO` 和 Sources 中的实际下载地址，以及软件官方网站、官方软件包仓库或 Release 提供的包。包括适用于目标平台和架构的 DEB、RPM、含预编译程序的 tar.gz、tar.xz、ZIP 等；不得把源码归档当成现成二进制包，也不得只查软件官网而漏查 AUR。 |

**Arch 官方仓库原生程序例外：** 当前选择 Arch 官方仓库提供的原生二进制包，且 `/usr/bin/<主程序>` 是可直接执行的真实程序时，先安装应用及依赖，再直接执行 `quick-sharun /usr/bin/<主程序>`；不另行下载同一主程序，也不预先复制到 `AppDir/bin`。mpv 按此路线执行，完整模板见 [原生程序系统入口标准](./anylinux_projects.md#arch-官方仓库原生程序系统入口标准)。这不是外部 DEB、预编译 tar 等下载路线的替代方案，不得扩大到 AUR 包、Electron 的 shell launcher 或需要保持完整相邻资源的程序目录。两项来源核实、原依赖覆盖和专属处理取舍要求仍须执行。

**除上述 Arch 官方仓库原生程序系统入口路线外，确认已有适用的 DEB、RPM、预编译归档等现成二进制包后，执行顺序固定为以下两个阶段，两个阶段都必须明确写入构建脚本，一项都不能省略：**

1. **先安装到构建系统。** 在隔离的 Arch 构建环境中安装当前应用及其真实运行依赖；存在对应 Arch / AUR 包时，安装该应用包，让包管理器拉入依赖。统一基础工具也必须安装，不能只装基础工具而省略应用安装。
2. **再独立下载并放入 AppDir/bin。** 在应用工作目录另行下载从当前 AUR 元数据、软件官方网站等核实得到的安装包，完成校验和解包后，将完整的真实程序目录原样放入 `AppDir/bin/`，保持程序与相邻资源的相对布局，再交给 quick-sharun 收集依赖和封装。

第一阶段的系统安装结果用于准备依赖、图标、desktop 及既定的版本元数据；最终程序文件必须来自第二阶段独立下载、解包的安装包。禁止把“安装后直接复制 `/usr/lib/<应用>/` 或 `/opt/<应用>/`”当成第二阶段，也禁止只下载解包而省略第一阶段。无法完成某一阶段时，报告具体阻塞，不得自行删掉该阶段或退回系统目录复制方案。

原脚本已经确认的基础工具和运行依赖必须逐项保留并核对覆盖关系。调用 `--base` 不等于已经证明原依赖全部齐备：必须对照公共基础包实际清单，已覆盖的依赖明确由公共入口保留，未覆盖的依赖在基础模板现有的应用依赖安装行补齐；不得漏包，也不得未经授权删除已验证的原安装命令。

固定的是上述两项核实和两个执行阶段；应用版本仍从当前 AUR 元数据或软件官方动态入口取得，不得因此锁定旧版本。安装、下载、校验和解包继续复用对应公共入口；已核实的 pkgforge-dev 专属代码继续按原样复用规则处理，发生具体冲突时按既有规则报告。

除上述 Arch 官方仓库原生程序系统入口路线外，该两阶段规则优先于系统 `/usr/bin` 或 `AppDir/shared/bin` 的一般示例；其他项目只有核实没有适用的现成二进制包时，才按对应一般示例判断。已经验证稳定且本次未涉及的应用保持原样，不得借本规则批量重写。

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
4. Arch 官方仓库原生程序将已安装的真实 `/usr/bin/<主程序>` 交给 quick-sharun，不预复制主程序。外部 DEB、预编译归档等路线将第二阶段独立下载、解包后放入 `AppDir/bin` 的完整程序交给 quick-sharun；其他无适用现成包的项目按对应一般示例判断。由 quick-sharun 收集依赖并生成 `AppRun`。
5. 再执行一次 `quick-sharun --make-appimage`。

上游文档里的 `get-debloated-pkgs.sh`、为了瘦身替换 Mesa / Qt / GTK 的做法，不是本仓库默认步骤。没有该应用自己的验证记录时不要加。

## Arch 官方仓库原生程序系统入口标准

适用于选择 Arch 官方仓库原生二进制包、且 `/usr/bin/<主程序>` 为真实可执行程序的路线。先安装基础包、应用及已确认依赖，再从系统入口收集；不另行下载同一主程序，不预复制程序到 `AppDir/bin`，不把 Electron 的 shell launcher 当成原生入口。本类已标准化项目见 [打包分类](./docs/packaging-classification.md)。

以下为基础模板。尖括号内容按当前应用实际值替换；没有额外运行依赖时只保留应用包参数，不保留占位符。同类项目必须逐字逐行保持公共代码、通用注释、缩进和空行，仅替换参数。应用专属段放在依赖收集之后、最终封装之前，并在应用的 `docs/template-deviations.md` 记录；不要求与 Electron 下载模板具有相同总行数。

```bash
#!/usr/bin/env bash

# 命令失败、用了没定义的变量，或管道里任一命令失败，就退出。
set -Eeuo pipefail

# 切到脚本所在目录，后面的 AppDir 和 dist 都写在这里。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 打包工具。GTK、输入法不要塞进这一行。
"$SCRIPT_DIR/../common/arch/install_packages.sh" --base
# 安装官方软件包及运行依赖。
"$SCRIPT_DIR/../common/arch/install_packages.sh" <应用包> <已确认的运行依赖>

# 清掉上次的打包目录。
rm -rf -- AppDir dist
mkdir -p dist

# 把当前机器架构传给 quick-sharun。
export ARCH="$(uname -m)"
# 使用系统里装好的图标。
export ICON=<系统图标路径>
# 使用系统里装好的桌面入口文件。
export DESKTOP=<系统桌面入口路径>
# 把 AppImage 写到脚本目录下的 dist。
export OUTPATH="$SCRIPT_DIR/dist"
# 固定最终 AppImage 的文件名。
export OUTNAME=<应用名>.AppImage

# 读取本次打包使用的版本。
VERSION="$("$SCRIPT_DIR/../common/build/read_app_version.sh" pacman <应用包>)"

# 收集程序及其运行依赖。
quick-sharun /usr/bin/<主程序>

# 把 AppDir 打成 AppImage。
quick-sharun --make-appimage

# 打包成功后用公共脚本记下版本。
"$SCRIPT_DIR/../common/build/save_appimage_version.sh" dist/<应用名>.AppImage "$VERSION" dist/version.txt
```

版本在第一次 quick-sharun 之前通过公共入口读取；最终 AppImage 成功生成后单行调用公共保存入口。ICON、DESKTOP 从当前软件包真实路径读取。APPNAME、MAIN_BIN、STARTUPWMCLASS、DEPLOY_GTK 等仅在当前程序确有需要时设置，不为凑齐 Electron 模板加入。

一次 quick-sharun 调用可以包含已确认必需的多个真实入口、辅助命令或 dlopen 库；没有依据时不添加。既有 htop、newsboat 等短写法只提供布局参考，不代表已经完成本轮标准化，不在分类表中提前登记。

[mpv/build_mpv.sh](./mpv/build_mpv.sh) 的基础部分遵守上面模板，另有三段经批准的专属处理，不能复制给其他应用：

- 原样采用 pkgforge-dev 的 `echo 'LC_ALL=C.UTF-8' >> ./AppDir/.env`。不再执行旧的 `LC_ALL=` / `LC_NUMERIC=C` 两行。
- 保留本仓库在依赖收集后下载独立 yt-dlp 的方式，改由公共入口动态选择正式资产、校验 GitHub SHA-256，并内置到 `AppDir/usr/bin/yt-dlp`。不采用运行时安装 yt-dlp 或自更新的官方 hooks。
- 独立保存并复制官方无参数窗口 hook；可执行代码原样保留，注释采用上表固定中文说明，不自写 AppRun。

完整来源、原文、采用与未采用原因见 [mpv 的 pkgforge 差异说明](./mpv/docs/pkgforge-differences.md)。固定配置、依赖覆盖和当前验证范围分别由 mpv 的配置说明及 README 记录。

## 命令行不加中文，GUI 默认要

不用再等用户提醒。新做、迁移或这次本来就要改的构建，按程序有没有窗口决定：

| 程序 | 中文环境 | 中文输入 |
| --- | --- | --- |
| 只在终端运行，没有窗口和输入框，例如 htop、newsboat | 不加 | 不加 |
| 有窗口，包括 GTK、Qt、Electron、播放器界面 | 要 | 要 |

已经验证稳定的脚本不要为了补上本节去批量重写。某个应用实机证明某一套输入模块会弄坏它时，在该应用 README 写明并只去掉那一套；中文环境仍保留。

**mpv 的已批准例外：** 本次按官方原文固定 `LC_ALL=C.UTF-8`，不执行下面的中文 locale 生成块，也不额外部署 GTK / Qt 输入模块。官方说明 mpv 只支持 C / C.UTF-8 数值 locale；这项选择会覆盖宿主 locale，不承诺保留宿主中文语言设置，详见 [模板差异](./mpv/docs/template-deviations.md)。其他 GUI 的默认要求不变。

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

除上述已批准的 mpv 例外外，不要设置 `LC_ALL`。个别程序还要 `LC_NUMERIC=C` 时，写在这四行后面，不要改掉 `LANG`。

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

`common/build/read_app_version.sh` 支持以下来源：

| 来源 | 参数 | 读取规则 |
| --- | --- | --- |
| package-json | package.json 的实际路径 | 用 jq 读取根对象中非空的字符串 version。 |
| pacman | 已安装的 Arch / AUR 包名 | 复用 common/arch/get_package_version.sh，去掉 epoch 和 pkgrel。 |
| text | 已下载文件对应的版本文本路径 | 读取公共下载入口记录的版本；用于链接提供版本而程序内无对应版本文件的情况，不用系统安装版本代替。 |

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