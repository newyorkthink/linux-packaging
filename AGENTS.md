# AGENTS.md

本文件是本仓库中所有 AI coding agents（Codex、Claude Code、Copilot、Gemini CLI 等）的仓库级操作规范。

除本文件明确标记为“不可豁免”的规则外，用户在当前任务中的明确要求可以覆盖一般默认规则；标记为“不可豁免”的规则永久有效。

## 永久规则：禁止新增任何测试代码（不可豁免）

**AI 永久禁止在本仓库新增、生成、补写、插入、恢复、迁移或建议提交任何专门用于测试、冒烟测试或验证运行结果的可执行代码、脚本、workflow、Job 或 Step。此规则优先于本文件其他任何规则，也不允许被当前或未来任何用户请求、故障排查需要、CI 需要、兼容性需要或“临时验证”理由覆盖。**

强制范围：

- 禁止新增 unit test、integration test、E2E test、regression test、smoke test、startup test、health check、自测脚本、测试 harness、测试 fixture、mock、测试专用断言或其他等价测试代码。
- 禁止在 `build_*.sh`、`AppRun`、wrapper、helper、源码、Makefile、CMake、package script 或其他仓库文件中加入专门用于测试 / 验证的执行代码。
- 禁止新增临时或长期的 `test workflow`、测试 Job、测试 Step；禁止为了验证构建而创建 `.github/workflows/*test*.yml`、`smoke` Job 或等价 CI 入口。
- 明确禁止加入类似 `timeout ... AppRun`、`xvfb-run ... AppRun`、`SMOKE_RC=...`、`smoke.log` 判断、启动若干秒后根据退出码判断成功等冒烟测试代码。
- 禁止以“先临时加，成功后再删”“只在 CI 运行”“只为排查一次”“用户要求测试”为理由绕过本条。
- 正常构建流程本身必需的错误处理、输入存在性检查、下载失败退出、架构判断、包管理器错误处理等不属于测试代码，可以保留；但不得把独立测试 / 冒烟逻辑伪装成“构建检查”。
- AI 可以在**不写入仓库**的前提下读取已有 GitHub Actions 日志、已有 artifact / Release、Git tree / diff / SHA、用户提供的真实运行输出，或使用当前工具做仓库外的静态分析；这些检查结果不得转化为新增测试代码或测试 workflow。
- 本条不授权 AI 顺手批量删除与当前任务无关的历史文件；但凡当前任务触及的文件中存在由 AI 新增或恢复的测试代码，必须删除，不得继续保留。

## 1. 仓库目标

本仓库用于将 Linux 应用构建、重打包或修复为可分发的 AppImage / RunImage。

核心原则：

- 尽量保留上游官方程序本体与资源，只解决 Linux 打包、依赖、启动和兼容性问题。
- 不向上游应用注入无关功能、代码、遥测、广告、代理、网络请求或持久化逻辑。
- 构建产物应尽可能自包含；如果应用核心功能确实需要宿主系统集成或权限，只允许采用必要、最小、明确且可审计的方式，不得借此实施与应用功能无关的系统修改。
- 优先保证正确性、安全性、可审计性和构建隔离，不要为了减少 GitHub Actions Job 数量而破坏现有结构。

## 2. 修改范围：必须最小化

AI 必须遵守最小修改原则。

- 只修改完成当前任务所必需的文件。
- 不得顺手重构、格式化、重命名或清理无关项目。
- 不得因为“风格统一”而批量修改已经正常工作的构建脚本。
- 不得删除其他应用、其他构建任务、其他 Release 资产或历史兼容逻辑，除非用户明确要求。
- 新增应用时，应创建独立应用目录，并优先参考仓库中最相近的现有项目实现。
- 如果现有方案可复用，应复用，不要重新设计整套构建系统。

### 公共文档不得透露用户个人运行环境

本仓库是公开仓库。README、AGENTS、注释、故障记录、兼容性说明、Release 说明等公开文档不得因为 AI 从对话、截图、日志或历史信息中知道了用户的个人环境，就把这些个人环境信息写进仓库。

要求：

- 不得记录或强调用户本人使用的 Linux 发行版名称、发行版版本、内核版本、主机名、用户名、个人 HOME 路径、设备型号、网络环境或其他与公开打包说明无关的个人运行环境信息。
- 记录实机验证结果时，默认使用“Linux 实机验证”“目标 Linux 环境”“真实 Linux 环境”等中性表述，不得写成“用户的某某发行版”“在用户的某某系统上验证”等可关联个人环境的描述。
- 即使截图、终端日志或用户在对话中明确暴露了发行版名称，也不得仅为了增加文档细节而复制到公开仓库。
- 某个发行版名称如果确实属于上游官方支持范围、CI 构建镜像、依赖来源或项目兼容矩阵的客观技术信息，可以在必要时记录；但不得把它表述成用户个人使用环境，也不得加入与任务无关的个人环境细节。
- 用户明确要求把某项个人环境信息写入公开文档时，才可以按其明确范围处理；不得自行扩大披露范围。

### 每个应用目录必须维护 README

仓库中的每个独立应用目录都必须维护自己的 `README.md`。这里的“应用目录”是指直接承载某个 AppImage / RunImage 构建、迁移或修复逻辑的项目目录；不要求 `source/`、`dist/`、`AppDir/` 或 `.github/actions` 等内部构建子目录逐层创建 README。

README 必须基于当前目录的真实脚本、workflow、上游来源和已确认行为编写，不得只放一句应用简介，也不得凭印象补写未核实的技术细节。至少应包含：

- **用途与产物：** 说明这个目录打包什么应用、主要用途、最终产物类型与稳定资产名，以及上游软件来源。
- **技术栈：** 说明应用的主要技术体系，例如 Electron / Chromium、VS Code 系谱、Qt、GTK、Rust、Go、C / C++、Java、Wine 等；同时说明实际使用的上游包格式、目标架构以及与打包有关的关键运行时组件。
- **打包方式：** 说明当前采用 quick-sharun / sharun、linuxdeploy + appimagetool、直接 appimagetool、上游 AppImage 修复或其他哪一条路线；写清关键打包步骤、依赖部署、`AppRun` / wrapper、desktop / icon 处理、动态版本来源和对应 workflow 入口。
- **运行与兼容说明：** 说明重要的宿主运行要求、必要系统集成、关键兼容处理以及已经从正常构建日志、已有产物或真实运行反馈确认的行为；不得为了补充 README 而新增任何测试代码。
- **修复记录：** 持续记录已经实际发生并完成处理的构建、启动、依赖、输入法、沙盒、runtime、Release 或其他兼容性问题。每条修复记录至少写明日期、故障现象、根因、修改文件、具体修复内容和已知结果；能够明确对应提交时应同时记录 commit。

维护规则：

- 新增或迁移一个应用时，必须在同一次任务中创建该应用目录的 `README.md`，并根据最终实际实现写完整；不得只迁移构建脚本而遗漏 README。
- 修改现有应用前必须先完整阅读该目录现有 README，并把其中已经确认的打包方式、技术栈、兼容处理和修复历史视为文档基线；不得为了“整理”而重写、压缩或删除已有有效记录。
- 每次修改应用的构建脚本、workflow、依赖、启动方式、打包工具、运行时兼容逻辑或 Release 行为时，都必须同步检查并更新该应用 README 中受影响的说明；代码与 README 不得长期不一致。
- 每次实际修复一个故障，都必须在 README 的修复记录中**追加**一条对应记录，不覆盖、不删除、不改写以前已经确认的修复历史。单纯拼写、排版或无行为变化的文档整理，不得伪装成运行故障修复记录。
- 如果修改一个已有应用时发现该目录没有 README，本次任务在完成前必须补建，并根据现有脚本、workflow、提交历史和可核实事实把用途、技术栈、打包方式与已有关键修复补清楚；无法确认的历史不得猜测。
- 如果本次修改改变了技术栈判断或打包路线，既要更新 README 的当前状态说明，也要在修复 / 变更记录中说明为什么改变、改了什么以及已知结果，不能只改静态介绍而丢失变更原因。
- README 同样受上面的“公共文档不得透露用户个人运行环境”规则约束；不得把用户个人主机、路径、账号或其他无关环境信息写入公开修复记录。

### README 必须提供可直接执行的运行命令

对于需要额外后台服务、守护进程、helper、初始化程序或提权组件才能正常使用的复杂应用，README 不得只说明“先启动后台服务”，必须给出实际命令和执行顺序。

- README 中的运行命令默认以用户已经进入**相关文件所在当前目录**为前提，不写用户机器、CI、仓库 checkout 或构建目录的绝对路径。
- 主程序、后台服务或辅助程序位于当前目录时，优先写成 `./<程序名>`；确实需要 root 权限时写成 `sudo ./<程序名>`。不得写成 `/home/<用户名>/...`、`/tmp/...`、`<仓库绝对路径>/...` 这类环境相关命令。
- 如果需要先启动后台服务再启动主程序，必须按真实顺序分别给出命令，并明确哪条是后台服务、哪条是主程序、后台服务是否需要持续运行。
- 只有软件本身客观要求固定系统路径的命令，才允许使用该固定路径；普通启动示例一律以当前目录相对命令为主。
- README 中的命令必须与当前实际文件名、启动方式和权限要求一致；不需要后台服务或 `sudo` 时不得凭空添加。

### 新应用必须先横向研究仓库现有实现

新增应用、重做尚未稳定的打包方案或处理一种此前未接触的应用类型时，AI 不得只看当前目录或只找一个示例就开始编写。应先浏览仓库中多个已有应用的构建方式，理解本仓库已经形成的成熟模式后再决定实现。

要求：

- 除当前项目外，在仓库存在足够样例时，至少横向查看 2～3 个最相近的现有项目，并比较它们的上游来源、包格式、技术栈、构建工具、依赖部署、desktop / icon、AppRun、运行时兼容处理和 workflow 接入方式；不得复制其中的测试 / 冒烟代码。
- 先判断新应用属于哪一类，例如 Electron / VS Code 系谱、Qt、GTK、Rust / C / C++ 原生程序、DEB / RPM 重打包、上游 AppImage 修复等，再优先寻找同类成熟项目，不要拿技术栈完全不同的软件机械套模板。
- 对同一技术谱系的软件，应主动识别可复用的共同逻辑。例如 VS Code、Cursor、Trae 等基于 Electron / VS Code 体系的应用，在依赖、GTK / IBus、NSS、quick-sharun 输入项和 desktop 处理上存在大量共性，应优先复用仓库中已经验证的成熟思路，同时保留每个应用自身的上游包布局和特殊依赖差异。
- “参考多个项目”不是要求把多个脚本拼接在一起。最终仍应只保留当前应用需要的内容，禁止因为参考了别的应用就复制无关依赖、特殊 workaround、权限或环境变量。
- 如果仓库已经有同类应用的稳定打包路线，应优先沿用其经过验证的总体结构；只有当前应用存在明确差异或现有路线不适用时，才引入新的处理方式。
- 可以复用 `.github/actions/build-anylinux` 等仓库公共能力，但不要为了抽象而抽象；仅在确实存在稳定、重复且适合公共化的逻辑时才修改公共 action。
- 已经验证有效的现有项目仍是稳定基线。横向参考是为了减少重复试错和发现共性，不是授权 AI 顺手重构其他项目。

### 从其他仓库迁移应用时必须完整对齐并验证原构建

如果任务是把已经存在于另一个 GitHub / GitLab 仓库中的 AppImage、构建脚本或打包项目迁移到本仓库，原仓库应视为迁移基线，但不能只复制一个脚本或只看文件名。

#### 迁移完整性与 SHA 一致性：硬性门槛

在通过本仓库公开性、授权和安全规则审查后，对确认允许迁入本 Public 仓库的源文件集合，迁移默认指 **完整、逐字节、无遗漏地复制并验证**。迁移完整性检查优先级高于后续适配、重命名、精简、重构或构建优化。以下任意一项不满足，均视为迁移未完成，不得声称“完整迁移”或“全部一致”。

- **迁移前必须先建立完整源文件清单。** 必须递归枚举用户指定迁移范围内的全部文件，包括普通文本文件、二进制文件、隐藏文件、脚本、配置、许可证 / 授权文件、校验文件、压缩包、Debian / RPM 包、图标及其他资源；不得只看 GitHub 页面上“看起来重要”的文件。
- 源文件清单至少必须记录：**相对路径、文件名、文件类型、文件大小、Git blob SHA**。能够可靠取得原始字节时，应同时记录 **SHA-256** 作为额外校验；Git blob SHA 仍是 GitHub 仓库间逐字节一致性的强制身份校验项。
- **Public 仓库适用性必须先于复制。** 如果源范围内包含 secrets、token、SSH key、私有配置、未经授权的商业软件文件、破解 / 绕授权内容，或其他不适合公开分发的文件，不得为了满足“完整迁移”而把这些内容复制到本仓库。必须明确列出被排除文件及原因；需要保留此类文件时，应改放到合适的 Private 仓库。
- **允许公开迁移的源文件数量是硬基线。** 迁移完成后必须重新递归枚举目标应用目录，并逐项与允许迁移的源清单比对；这些源文件必须 **100% 覆盖，缺失文件数必须为 0**，不得因为文件“不常用”“可以在线下载”“属于二进制”或“构建时能重新获取”而省略。
- **所有要求原样迁移的文件，目标 Git blob SHA 必须与源 Git blob SHA 完全一致。** 文件名相同但 SHA 不同，视为不一致；文件大小相同但 SHA 不同，同样视为不一致。只检查文件存在、不检查 SHA，禁止视为完成。
- 对能够计算 SHA-256 的文件，源文件与目标文件的 SHA-256 也必须完全一致；任何一个字节不同都属于不一致。
- **二进制文件必须按原始字节迁移。** 如果 UTF-8 / 文本接口无法读取二进制，必须改用 raw、base64、Git blob 或其他不会改变字节内容的方法；不得把乱码文本、损坏解码结果或重新编码后的内容写入目标仓库。
- 工具暂时无法安全读取或写入某个应迁移文件时，必须明确停止并说明该文件尚未迁移；**不得跳过该文件继续声称完成，也不得擅自改成构建时联网下载来掩盖缺失。**
- `license.sha256`、签名、key、证书、数据库、归档文件等即使文件名看起来像文本，也必须先以源仓库元数据和实际内容类型为准；不得仅凭扩展名或文件名假定编码并进行文本转换。同时仍必须遵守本 Public 仓库的公开性和授权规则。
- **不得把“迁移”和“适配”混在同一步。** 必须先完成原始迁移文件的逐文件一致性核对，再进行本仓库需要的路径调整、动态版本改造、workflow 接入或其他适配。发生修改后的文件必须明确视为“适配后的派生文件”，不得继续描述为“与源文件一致”。
- **不得用网络重新下载的“等价文件”替代源仓库中的原始文件。** 即使文件名、版本号或大小相同，只要 Git blob SHA 未与源文件一致，就不能视为原样迁移。用户明确要求改用官方来源时属于适配任务，必须单独说明。
- 提交前必须执行一次 **源清单 vs 目标清单** 的最终逐文件核对：允许迁移文件总数、相对路径、文件大小、Git blob SHA 必须逐项检查；适用时同时检查 SHA-256。任何一项存在缺失、额外替代、SHA 不一致或无法确认，**禁止把迁移描述为完成**。该核对通过仓库外的元数据读取 / 比对完成，不得为此新增测试代码。
- 提交到 `main` 后必须再次读取目标仓库实际 tree / contents，确认所有目标文件真实存在，并再次核对 Git blob SHA。不得只根据“写入 API 返回成功”就认定迁移完成。
- 最终回复用户时必须明确报告：**源文件总数、允许公开迁移文件数、被排除文件数、已迁移文件数、缺失文件数、SHA 不一致文件数**。只有允许迁移范围内“缺失 = 0 且 SHA 不一致 = 0”时，才可以使用“完整迁移”“全部一致”“迁移完成”等表述。

迁移前必须先做源仓库核查：

- 阅读源仓库中与该应用有关的完整文件集合，包括构建脚本、`AppRun` / wrapper、patch、desktop、icon、helper script、配置模板、本地 Action、workflow、Release 逻辑以及构建过程中引用的其他相对路径文件。
- 建立实际文件对应关系，确认源 workflow / build script 引用的每个仓库内文件在迁移后都有对应目标；如果目录结构或文件名发生变化，必须同步修改全部引用，不能留下失效路径。
- 不得只迁移 `build.sh` 却漏掉它依赖的 `AppRun`、patch、desktop、icon 或辅助脚本，也不得凭印象重新造一套“差不多”的文件。
- 源仓库中的 secrets 名称、仓库专用 token、branch/tag 条件、Release 名称、路径、仓库 owner/name 等不应机械复制；只迁移构建本身确实需要的逻辑，并适配本仓库现有约定。
- 如果源仓库脚本存在应用版本硬编码，迁移时仍必须遵守本文件“应用版本必须动态获取”的规则；“原仓库这样写”不是继续写死版本的理由。除非用户本人在当前任务中明确要求固定版本，否则 AI 不得自行锁版本。

### 必须核实源仓库 Actions 真实成功过

把其他仓库的 workflow 当作“已验证打包方案”之前，AI 必须尽可能核实它确实成功运行并产出了预期 AppImage，而不是仅因为 workflow 文件存在就假定正常。

要求：

- 查看源仓库与目标应用对应的 GitHub Actions / CI workflow 最近相关运行记录，确认相关 build Job 的实际结论是成功；不能只看 workflow YAML 静态内容。
- 应优先核对与准备迁移的脚本版本 / commit 相对应的成功 run。如果最新 run 失败，而旧 run 成功，必须理解失败原因，不能直接把“曾经成功”描述成“当前方案正常”。
- 工具允许时，应继续核对成功 run 的 Job、关键日志、artifact 或 Release 资产，确认它确实执行了目标应用的打包步骤并生成了非空、命名合理的 AppImage，而不是 workflow 因条件判断跳过了构建却整体显示成功。
- 如果源仓库的目标 workflow 从未成功、当前持续失败、产物缺失，或者当前工具无法读取足够证据，则不能把该方案称为“已验证正常”；应明确按“待验证迁移”处理，**不得为此在本仓库新增 test workflow 或任何测试代码。**
- 如果源仓库是 Public，不得为了节省 Actions 而省略对已有 build run / 日志 / artifact 的必要核对；如果源仓库是 Private，则仍应在权限允许范围内先读取已有 run / 日志，避免无意义地重新触发大量 CI。

### workflow 迁移方式

- 源仓库的 workflow 主要用于确认原始构建环境、系统依赖、环境变量、命令顺序、构建入口、artifact / Release 产物名和已经验证过的特殊处理。
- **禁止为了迁移创建任何临时 test workflow。** 新项目需要在本仓库构建时，直接按第 7 节接入正式统一 workflow 的正常 build Job；不得增加 test / smoke Job 或 Step。
- 原仓库 workflow 成功不代表可以把它作为本仓库新的长期独立 workflow 原样复制。普通 AppImage 项目仍必须按照第 7 节规则接入本仓库统一 `.github/workflows/build.yml`。
- 正式接入 `build.yml` 时，应保留原方案中真正影响成功构建的依赖和步骤，同时适配本仓库的 Job 隔离、plan、paths、`workflow_dispatch` 和公共 Action 结构；不得为了“完全照抄”破坏本仓库统一工作流设计，也不得复制源仓库的测试步骤。
- 迁移完成后通过本仓库正常 build run、Job 日志、artifact / Release 和仓库外静态检查核对结果；不得新增 build 之外的测试代码。

## 3. 宿主系统安全：权限必须必要且最小

构建、打包过程默认不得修改用户真实宿主系统。最终应用如果因为自身核心功能确实需要系统级权限或系统集成，可以使用必要权限，但必须与上游功能一致、范围最小、行为明确且可审计。

例如 VPN、代理、网络管理、TUN/TAP、路由、防火墙、设备访问、udev、系统服务等应用，可能天然需要 `sudo`、`pkexec`、Linux capabilities、systemd、网络配置或其他系统级操作；不得因为本规范而人为移除这些正常且必要的功能。

### 默认禁止

- 禁止执行与当前应用功能或构建无关的系统修改。
- 禁止无理由修改 `/etc`、`/usr`、`/opt`、`/var`、`/boot`、系统服务、systemd unit、PAM、sudoers、shell profile 等宿主系统状态。
- 构建过程禁止污染用户真实 `$HOME`；应使用项目目录或 CI 临时 HOME。最终应用正常运行时，可以按上游正常行为写入自己的 `~/.config`、`~/.local`、`~/.cache` 等应用数据目录。
- 禁止安装与应用核心功能无关的开机启动项、桌面自启动、后台 daemon、cron 或 systemd user service。
- 禁止修改与应用核心功能无关的防火墙、网络、DNS、代理、路由、内核参数、驱动或 udev 规则。
- 禁止执行与应用核心功能或构建无关的提权操作。
- 禁止使用宽泛或危险删除，例如 `rm -rf /`、`rm -rf "$HOME"`、未校验变量的 `rm -rf "$VAR"`。
- 禁止通过 AppImage 的 `AppRun`、wrapper、安装脚本或辅助程序偷偷扩大权限、安装无关软件、修改无关系统配置或建立未说明的持久化机制。

### 必要系统权限的允许条件

如果应用的正常核心功能确实依赖系统权限或系统集成，则可以保留或实现，但必须同时满足：

- 权限或系统修改确实是实现该功能所必需，而不是为了打包方便。
- 优先遵循上游官方实现、官方文档或发行版成熟打包方式，不自行扩大权限模型。
- 只请求完成该功能所需的最小权限，不得直接要求不必要的 root 权限。
- 修改范围必须精确，不得顺带改变无关系统状态。
- 涉及 `sudo`、`pkexec`、capabilities、systemd、udev、TUN/TAP、防火墙、路由、DNS 等操作时，代码中应能明确看出用途。
- 不得隐藏提权行为；用户触发系统级操作时，应遵循正常的系统授权流程。
- 能在退出、卸载或功能关闭时恢复的临时系统状态，应尽量正确恢复。
- 安全审计时必须把这些必要权限明确列出，不能把“应用需要权限”与“应用乱改系统”混为一谈。

GitHub Actions 的临时 CI 容器 / runner 内可以使用 `pacman`、`yay`、`apt` 等安装**构建依赖**。这只用于临时构建环境，不代表最终应用可以无条件修改用户系统。

清理操作必须限制在当前项目自己的已知构建目录中，例如 `source/`、`AppDir/`、`dist/`、`verify/` 等。

## 4. Shell 构建脚本规范

新增或重写 Bash 构建脚本时：

- 使用 `#!/usr/bin/env bash`。
- 默认使用 `set -Eeuo pipefail`。
- 先解析脚本自身目录，例如：
  `SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"`。
- 构建文件路径尽量基于 `SCRIPT_DIR`，不要依赖调用者当前工作目录。
- 删除文件前必须确保目标是当前项目内部的确定路径。
- 对架构、下载结果、关键文件、ELF 类型等构建前置条件进行必要的显式检查，失败时立即退出；这类构建守卫不得扩展成独立测试逻辑。
- 下载使用失败即退出、重试和合理超时参数。
- 对可获得的官方 SHA-256 / digest 进行校验；没有上游 digest 时至少记录本地 SHA-256。
- 不允许静默吞掉关键错误；`|| true` 只能用于明确允许失败且后续有正常构建处理的非关键步骤。
- 路径和变量必须正确引用，避免 word splitting 和 glob 意外展开。

### 构建脚本必须使用中文分区注释

构建脚本必须让用户能够快速看懂执行流程。新增、迁移或修改 build / setup 脚本时，应按实际执行阶段使用清晰的中文注释和分区标题组织代码。

- 关键阶段必须使用明显的中文分区注释，推荐 `###### 下载上游文件 ######`、`###### 准备构建环境 ######`、`###### 核心打包 ######`、`###### 整理产物 ######` 这类格式；具体名称按脚本实际内容调整，不得机械加入不存在的阶段。
- 每个分区只说明该区域真实用途，用户应能一眼区分“下载”“准备 / 解包”“核心打包”“产物整理 / 发布准备”等主要阶段；**禁止增加“测试 / 验证 / smoke test”分区。**
- 分区内部的重要非显然操作应使用简短中文注释说明目的，尤其是兼容性修复、依赖处理、patch 和特殊环境变量；不要求对每一行机械注释。
- 禁止只使用 `download`、`build` 等英文标题代替中文说明；命令、变量名、程序名本身保持原样。
- 为补充注释不得改写、重排或“顺手优化”已经验证有效的命令、参数和执行顺序。注释是可读性要求，不是重构授权。

## 5. 上游来源与供应链规则

优先级通常为：

1. 上游官方 GitHub / GitLab Release；
2. 上游官方网站提供的 Linux 包；
3. 官方仓库中的构建产物；
4. AUR / 发行版打包脚本作为依赖、文件布局和启动方式参考；
5. 其他第三方来源仅在没有合理官方来源并且任务确实需要时使用。

要求：

- 不得悄悄把官方来源替换成不明第三方二进制。
- AUR 可以作为打包逻辑参考，但应区分“参考 PKGBUILD”和“信任第三方二进制”。
- 不得使用与任务无关的远程安装脚本或 `curl ... | sh` 形式。
- 下载 URL、Release 资产名、架构和版本必须进行合理校验。
- 能固定 Action / 工具版本或 commit SHA 时，优先固定，避免无理由追踪未知代码。

### 禁止破解、绕授权和未经授权的商业软件魔改

本仓库的目标是 Linux 打包、依赖修复和兼容性处理，不是破解、绕过授权或重新分发未经授权修改的商业软件。AI 在新增应用、迁移其他仓库项目、参考第三方脚本或审计已有实现时，必须检查是否包含此类内容。

- 不得加入、迁移、保留或生成用于绕过付费、订阅、许可证、激活、试用期限、账号授权、功能限制、DRM 或其他访问控制的 crack、patch、keygen、loader、license bypass、激活脚本、二进制补丁或等价逻辑。
- 不得通过修改二进制、Electron/JS 资源、配置、网络请求、证书校验、授权服务器通信或运行时 hook 等方式，把商业软件的付费/受限功能改成未授权可用。
- 不得从其他仓库迁入所谓“破解版”“绿色破解”“解锁版”“去授权版”“premium unlocked”“pro unlocked”等构建方案，即使原仓库 Actions 能成功打包，也不能把其成功 CI 当作可迁移依据。
- 对闭源或商业软件，只允许在其许可和正常分发范围内进行必要的 Linux 重打包、依赖补齐、启动兼容、desktop/icon 整理等操作；不得夹带改变授权状态、商业功能或服务端访问权限的二次魔改。
- 正常的兼容性 patch、上游公开源码补丁、修复崩溃/缺库/启动问题的修改不属于破解，但必须与授权机制无关，并保持最小修改和可审计性。
- 如果第三方仓库同时包含正常打包逻辑和破解/绕授权逻辑，只能重新提取其中可独立验证的正常打包思路；不得复制、迁移或依赖破解部分，也不得把相关二进制产物带入本仓库。
- 如果无法确认某段 patch、loader、二进制修改或网络拦截是否用于授权绕过，应先按高风险处理，不得直接加入正式仓库或 Release。
- 发现已有项目误带此类内容时，不要继续扩散到其他应用或新 Release；应明确指出风险并优先移除相关逻辑或产物。

### 应用版本必须动态获取，AI 永久不得自行锁版本

本仓库默认用于持续构建当前最新稳定版软件。**除非用户本人在当前任务中明确要求固定某个应用版本，否则 AI 永久不得把应用版本、版本范围、带版本号的下载地址或版本判断锁死在仓库中。** 兼容性约束、补丁暂时只适配某版本、上游缺少可靠 latest 接口、构建失败或为了让 Actions 通过，都不是 AI 自行锁版本的授权。

如果动态获取或新版兼容出现问题，应先核实上游来源、版本解析、下载选择和兼容逻辑，并在已经验证的稳定基线基础上做最小修复。仍无法解决时，应明确停止并说明原因，等待用户决定；不得擅自回退或固定到旧版。

要求：

- GitHub / GitLab 上游应优先通过官方 `releases/latest`、Release API 或等价官方机制解析**最新稳定版**，并排除 draft / prerelease；不得长期维护 `VERSION=1.2.3`、固定 `v1.2.3` tag 或 `/download/v1.2.3/...` 这类会在上游更新后自动过期的写法。
- 上游官方网站提供 stable channel、latest 下载链接、重定向地址、公开 API 或当前下载页面时，应动态解析当前稳定版下载 URL，而不是把当时看到的 CDN 地址或版本路径复制进脚本。
- 如果项目通过 AUR / 发行版打包元数据获取上游信息，可以读取当前 PKGBUILD / package metadata 中的 `pkgver`、source 和 checksum，再解析实际下载地址；不得把一次查询得到的版本号重新硬编码回本仓库。
- 如果官方包本身包含版本元数据，可以在下载后从 `package.json`、包元数据、二进制版本信息等位置提取版本用于 `X-AppImage-Version`、日志和 Release 元数据，但该版本值不应反过来成为固定的下载选择条件。
- 动态获取最新版本时仍必须验证 tag / 版本格式、资产名称、架构、包类型和下载域名，避免因为上游页面变化而误下载其他平台、预发布版本或非预期资产。
- 如果上游提供 digest / checksum，应随当前版本动态获取并校验；不得把旧版本 checksum 用于新版本，也不得为了实现“自动最新版”而取消供应链校验。
- 上游发布新稳定版本后，在构建脚本本身没有其他兼容性变化的情况下，下一次构建应能够自动获取并打包新版本，而不需要先人工修改仓库中的版本号。
- **只有用户本人在当前任务中明确要求固定某个应用版本时，才允许锁定应用版本。** 未获得该明确要求时，即使上游没有可靠的动态版本入口、当前补丁只兼容某个版本、AUR / 上游布局发生变化或当前构建失败，AI 也不得自行锁版本。
- 如果确实无法可靠动态解析当前稳定版，或者新版需要额外兼容修复，应停止并明确说明具体阻塞点，等待用户决定；不得用“先锁旧版”“临时固定版本”作为默认解决办法。
- 默认不要自动选择 beta、nightly、insider、RC、prerelease 等版本，除非当前项目本身就是对应渠道或用户明确要求。
- **应用版本动态更新与供应链工具锁定是两回事。** GitHub Actions 的 commit SHA、经过验证的构建工具版本、补丁基线等可以为了安全性和可复现性固定；不要为了“不能写死版本”而把所有 Action / 工具都改成漂移的 `latest`。

## 6. AppImage 内容规则

AppImage 应只包含应用正常运行所需内容。

- 优先保留官方二进制、`resources`、desktop 文件和图标。
- desktop / icon 优先从官方包或上游源码中提取，不要擅自制作假图标或改变品牌。
- 允许为解决缺失依赖而补充必要共享库。
- 不要打包宿主机私有配置、凭据、token、SSH key、浏览器数据、缓存或个人文件。
- 不要把构建机的绝对路径、临时目录或用户 HOME 写死进最终产物。
- 不要为了“全打包”盲目复制整个 `/usr/lib`。
- 对 glibc、动态加载器、GPU 驱动、Mesa/NVIDIA/VAAPI 等高度宿主相关组件要谨慎；只有在明确必要并确认兼容性后才处理。
- `AppRun` / wrapper 默认只做启动 AppImage 所必需的环境准备；如果应用核心功能确实需要系统权限或系统集成，可以调用必要的辅助机制，但必须遵守第 3 节的最小权限和可审计要求，不得夹带无关系统修改。

### AppImage 打包方式由 AI 根据项目自行判定

本仓库不强制所有应用使用同一种 AppImage 打包工具。新增应用或处理尚未稳定的打包方案时，AI 必须先检查上游包类型、程序技术栈、ELF 与动态依赖、插件 / `dlopen` 依赖、目标发行版兼容性、glibc / loader 要求、FUSE / runtime 兼容性以及仓库中相近项目的成熟做法，然后选择**一套最合适的方案**。

允许并常用的路线包括：

- **quick-sharun / sharun：** 适合需要较强跨发行版兼容性、自包含运行库、非 FHS / 较旧发行版兼容，或现有相近项目已经通过该路线稳定运行的应用。quick-sharun 使用的 uruntime 具备在 FUSE 不可用时回退到其他运行方式的能力，因此不能把它简单等同于传统 AppImage 的 FUSE 依赖模型。
- **linuxdeploy + 官方 appimagetool：** 凡选择 linuxdeploy 路线，linuxdeploy 只负责构建 / 整理 AppDir、自动收集 ELF 共享库和相关资源，以及通过 Qt / GTK 等插件部署运行时依赖；**最终 AppImage 必须单独使用官方 appimagetool 封装**，不得把 `linuxdeploy --output appimage` 作为本仓库 linuxdeploy 路线的最终输出方式。
- **官方 appimagetool 直接打包：** 适用于 AppDir 本身已经完整、依赖已经由上游、手工逻辑或其他工具正确部署的项目。appimagetool 的职责是把 AppDir 转为 AppImage，**不会替代 linuxdeploy / sharun 自动发现并补齐缺失运行库**。

### 使用 linuxdeploy 时最终必须由 appimagetool 封装

凡使用 linuxdeploy 的项目，标准链路固定为：先由 linuxdeploy 完成 AppDir 和依赖部署，再由官方 appimagetool 使用明确的 runtime 文件生成最终 AppImage。示例结构如下，实际路径和插件按项目填写：

```bash
export ARCH=x86_64; linuxdeploy --appdir <AppDir路径> --plugin <插件>
export ARCH=x86_64; appimagetool -n <AppDir路径> <输出AppImage> --runtime-file <runtime文件>
```

强制规则：

- linuxdeploy 命令不得附加 `--output appimage` 作为最终封装步骤；依赖部署完成后必须单独调用 appimagetool。
- appimagetool 和对应 runtime 应在最终封装前明确准备好，并使用失败即退出、重试和合理超时的下载逻辑；不得依赖打包阶段临时自动下载未知 runtime。
- **网络故障不是更换打包路线的理由。** 如果 appimagetool、runtime 或其官方下载源出现临时网络失败、GitHub / CDN 超时、重定向异常、HTTP 错误等，应重试；重试后仍失败则让当前构建明确失败，等待网络恢复或修正下载地址。
- 不得因为 appimagetool / runtime 下载失败，就临时改成 `linuxdeploy --output appimage`、改用旧 runtime、改用另一个 AppImage 输出插件、改成 quick-sharun / sharun，或使用其他未经当前项目验证的工具，只为了让 Actions 变绿。
- 不得加入“下载 appimagetool 失败就自动回退到 linuxdeploy 输出”“runtime 下载失败就自动换旧 runtime”之类 fallback。构建工具和最终 runtime 必须是明确、可审计、可复现的。
- 只有确认存在与网络无关的真实兼容性问题，并完成原因核实后，才可以考虑改变既定打包路线；已经验证有效的现有项目仍按稳定基线处理，不得因一次临时下载失败推翻整个方案。

### Qt 应用打包必须保持 Qt 主版本一致

无论使用 linuxdeploy、quick-sharun / sharun 还是其他 Qt 部署路线，都必须先根据主程序实际 ELF 依赖和随程序提供的 Qt 运行库确认 Qt 主版本，再选择对应的 Qt 部署环境、运行库和插件，禁止凭模板、包名或其他项目经验猜测。

- 主程序依赖 `libQt6*.so.6` 或上游运行时明确为 Qt 6 时，Qt 部署链路、qmake / qtpaths、Qt plugin 和额外补入的 Qt 组件必须全部使用 Qt 6；**不得用 Qt 5 环境、Qt 5 plugin 或 Qt 5 输入法插件给 Qt 6 主程序打包。** Qt 5 主程序同理不得混入 Qt 6 部署链路。
- 上游包如果同时残留其他 Qt 主版本的 plugin，必须隔离或移出当前 Qt plugin 搜索路径；已有运行日志或真实运行反馈发现 `Plugin uses incompatible Qt library` 等 Qt 主版本不兼容信息时必须修正，不得带病发布。
- 对需要标准 Linux 输入上下文支持的 Qt GUI 应用，**Qt 5 和 Qt 6 都必须按主程序实际 Qt 主版本检查对应 Qt plugin 根目录中的 `platforminputcontexts/`**，并完整保留 `libcomposeplatforminputcontextplugin.so`、`libfcitx5platforminputcontextplugin.so`、`libibusplatforminputcontextplugin.so` 及其必要运行库。三个 plugin 必须全部与主程序使用相同 Qt 主版本，不得把 Qt 5 输入上下文 plugin 塞给 Qt 6，也不得把 Qt 6 输入上下文 plugin 塞给 Qt 5。
- `platforminputcontexts/` 的最终路径由当前打包工具和 AppDir 布局决定，例如可能位于 `usr/plugins/platforminputcontexts/`、`lib/qt/plugins/platforminputcontexts/` 或 `lib/qt6/plugins/platforminputcontexts/`；不得把某一个路径写成 Qt5 / Qt6 通用的唯一固定路径。
- 如需核对最终 AppImage 中上述输入上下文 plugin 的实际存在性、Qt 主版本一致性和必要动态依赖，应通过已有产物、日志或仓库外检查完成；**不得为此新增测试代码、测试脚本或 workflow Step。**

linuxdeploy 额外规则：

- 使用 linuxdeploy 前应先把项目需要的自定义 `AppRun` 写入 AppDir。linuxdeploy 在存在非空 `apprun-hooks` 时会把原有 `AppRun` 重命名为 `AppRun.wrapped`，再生成新的顶层 `AppRun` 负责加载 hooks 并执行 `AppRun.wrapped`；**不得手工编写或覆盖 `AppRun.wrapped`，也不得在 linuxdeploy 完成后重新覆盖它生成的顶层 `AppRun`。**
- linuxdeploy 完成后必须核对最终 `AppRun`、`AppRun.wrapped` 和 `apprun-hooks` 的实际关系及执行链，确认自定义启动逻辑仍位于 `AppRun.wrapped` 并由 linuxdeploy 生成的顶层 `AppRun` 正确调用。

### quick-sharun / sharun 打包阶段必须使用 Arch Linux

- quick-sharun / sharun 的**实际依赖收集、Qt / GTK plugin 部署和 AppDir 构建阶段固定使用 Arch Linux 环境**；不得在 Ubuntu / Debian 中通过 `apt` 安装 Qt、Fcitx5 或其他打包依赖后直接执行 quick-sharun / sharun。
- GitHub Actions 的外层 runner 可以为了运行 Linux job / Docker 容器而使用 Ubuntu，但如果当前 Job 不是直接运行在 Arch Linux container 中，则必须在执行 quick-sharun / sharun 之前先进入明确的 Arch Linux container / chroot；`pacman` 安装依赖、Qt / Fcitx5 plugin 来源和 quick-sharun / sharun 本体执行都必须发生在 Arch Linux 内。
- Qt 项目在 Arch Linux 中仍必须遵守上面的 Qt 主版本一致规则：Qt5 主程序使用对应 Qt5 runtime / plugin，Qt6 主程序使用对应 Qt6 runtime / plugin；Fcitx5 输入上下文也必须选择相同 Qt 主版本，禁止跨主版本混装。
- 成品跨发行版兼容性只能依据已有正常构建结果、已有运行日志或真实运行反馈确认；**不得为了兼容性确认向仓库加入跨发行版 smoke test 或其他测试代码。**

选择规则：

- 不得把“quick-sharun”“linuxdeploy”“appimagetool”中的任意一种写成仓库所有项目的唯一标准工具；但**一旦当前项目选择 linuxdeploy，最终封装必须遵守上面的 appimagetool 规则**。
- 不得简单把工具名称永久等同于某个固定 FUSE 版本。最终 FUSE / runtime 行为取决于实际嵌入的 AppImage runtime 和工具版本；因此 linuxdeploy 路线必须显式使用已选定的 appimagetool / runtime，而不是依赖 linuxdeploy 输出插件隐式决定最终 runtime。
- AI 应自行根据项目情况选择最稳妥的一套方案，不应因为存在多种工具就把选择题转交给用户；只有不同方案会造成用户可感知的功能、兼容范围、体积或运行权限差异时，才需要明确说明取舍。
- 已经验证稳定的现有项目，其打包方式视为稳定基线。不得仅因为 AI 更偏好另一种工具，就把 quick-sharun 改成 linuxdeploy、把 linuxdeploy 改成 quick-sharun，或改写为另一套未经验证的流程。
- 新应用应直接按正式构建路线接入正常 build workflow；禁止创建临时 test workflow、smoke Job 或其他测试入口。
- 最终产物的可提取性、关键依赖、desktop / icon / AppRun 等信息如需核对，只允许通过已有产物、已有日志或仓库外静态检查完成，不得把核对逻辑写成仓库测试代码。

## 7. GitHub Actions：保持统一工作流

### 所有打包均在 GitHub Actions 中执行

本仓库的所有正式打包、重打包、构建和 Release 产物生成，默认且统一在 GitHub Actions 的临时 runner / container 中执行。除非用户在当前任务中明确要求本地复现，否则不得把用户的真实 Linux 主机或其他真实主机当作打包环境。

要求：

- 不要求用户在本机执行 `build_*.sh`、`yay`、`pacman`、`apt`、`quick-sharun`、`linuxdeploy`、`appimagetool` 等构建步骤；应由 workflow 自动完成。
- 构建脚本中的 `mkdir`、`rm`、依赖安装、临时 `$HOME` 写入、`~/version`、`AppDir/`、`source/` 等操作，默认作用于 GitHub Actions 临时 runner / container。只要这些命令没有进入最终 `AppRun` / wrapper 或被打进运行时逻辑，就不得误判为“会在用户本机执行”。
- 审计“是否会改用户本机”时，必须严格区分 **CI 构建期行为** 与 **最终 AppImage / RunImage 运行时行为**；不能因为 build script 在 Actions 中写了临时文件，就声称发布产物启动后也会写同样的位置。
- 最终用户侧默认只下载并运行 Release 产物；不得为了完成构建要求用户在真实主机上安装构建依赖、创建构建目录或运行打包脚本。
- 新应用和修复也必须通过正式 GitHub Actions build workflow 完成；**不得为此创建临时 test workflow、测试 Job、测试 Step 或测试分支。**

正式、长期维护的标准 AppImage 构建统一放在：

`/.github/workflows/build.yml`

该 workflow 的既有设计是：

- 一个统一入口；
- 每个应用独立 Job；
- 每个 Job 独立运行环境；
- 不使用 Matrix；
- 通过 plan 阶段决定需要构建的项目；
- 能复用 `.github/actions/build-anylinux` 时优先复用。

### 永久禁止临时 test workflow 和测试 Job

- 不得因为“新应用首次接入”“隔离排查”“临时验证”“smoke test”“先跑通再删”等理由创建任何独立 test workflow。
- 不得在正式 `build.yml` 中增加仅用于测试、冒烟、启动若干秒、断言运行结果的 Job 或 Step。
- 新应用应直接接入正式统一 `build.yml` 的正常构建流程；若当前方案证据不足，应先继续研究上游、现有仓库实现、已有 Actions 日志和产物，不得用新增测试代码代替研究。
- 已有外部 / 上游 test workflow 可以作为理解其环境的参考，但不得把其中的测试代码迁入本仓库。

### AI 触发与检查 GitHub Actions

- AI 在修改 workflow 或构建脚本前，必须先读取实际触发条件，并检查当前可用的 GitHub 工具能力，不能未经检查就声称“没有接口”“不能自动跑 Actions”或要求用户手工操作。
- `on: push` 是 GitHub 自身的自动触发机制。只要 AI 有权限把符合 `paths` 条件的修改提交到对应分支，提交本身即可触发 Actions，不需要额外的“运行 Actions”接口。
- 如果 workflow 已配置适用的 `push` 触发，AI 应完成必要修改并提交，让 GitHub Actions 自动运行，然后继续检查对应 workflow run / Job / 日志 / 产物；不能把正常可自动完成的步骤转交给用户。
- 如果任务需要 `workflow_dispatch`，应先确认当前工具是否提供 dispatch 能力。只有实际检查后确认当前工具确实不支持该操作时，才能说明这一项能力受限；不得把“缺少 workflow_dispatch 接口”扩大描述成“AI 无法使用 GitHub Actions”。
- Actions 启动后，AI 应在当前工具允许的范围内主动检查运行状态、失败 Job、日志和产物。不能仅因为 Actions 是异步执行机制，就在能够读取运行结果的场景下直接停止在“已经提交，请用户自己看”的状态。
- 只有在当前工具真实缺少某个必需能力、权限不足或 GitHub 返回明确错误时，才说明具体限制，并准确指出是哪个操作不可用，不得笼统归因于“没有 GitHub 接口”。

### Public / Private 仓库与 Actions 额度

- 在因为 Actions 额度、运行次数或 CI 成本而改变执行策略之前，AI 必须先读取仓库元数据，明确当前仓库是 **Public** 还是 **Private**，不得凭用户账户类型、仓库名称或经验猜测。
- **Public 仓库：** 不得为了“节省 GitHub Actions 额度”而跳过、关闭、延迟或要求用户手动执行本来正常且必要的构建、打包和 Release 流程；正常 CI/CD 需要自动运行就应正常自动运行。
- **Public 仓库：** 不得因为用户使用 GitHub 免费账户，就擅自把 Private 仓库的 Actions 分钟限制逻辑套用到 Public 仓库，也不得因此取消 `push` 自动触发或减少必要构建 Job。
- **Private 仓库：** 应同时考虑 Actions 分钟和无效运行成本。提交前要尽量完成仓库外静态检查，精确限制 `paths` / 触发条件，避免明显无意义的重复构建和用 Actions 反复试错；但正常必要的构建和发布流程仍应执行。
- 仓库可见性可能改变，因此每次涉及“是否要省 Actions”“是否自动触发”的判断，都应以当前实际 repository visibility 为准，而不是沿用旧结论。
- 无论 Public 还是 Private，都应避免配置错误导致的无限触发、无意义 schedule、重复 Job 或明显无效运行；区别在于 Public 仓库不能把“省额度”作为减少正常必要 CI/CD 的理由。

### 正式 workflow 规则

- 不得把已经验证并正式接入的普通 AppImage 项目再长期拆成独立 workflow。
- 不要把已有独立 Job 改成 Matrix，除非用户明确要求整体架构重构。
- 不要为了节省 public repository 的 Actions 使用量而合并本来应该隔离的构建任务；构建正确性和隔离性优先。
- `.github/workflows/build_runimage.yml` 是另一类构建入口；普通 AppImage 任务不要擅自迁移过去。
- 只有当现有统一 workflow 明确无法满足正式构建需求，或者用户明确要求时，才考虑长期新增独立 workflow；新增的长期 workflow 也不得包含测试代码。

## 8. Release 规则

仓库使用 `latest` Release 作为持续更新的发布入口时：

- 只更新当前任务对应的资产。
- 不得删除或覆盖其他应用资产。
- 资产名必须稳定、清楚，并与现有命名约定保持一致。
- 构建失败时不得伪造成功产物或上传空文件。
- 不要无理由删除整个 `latest` Release、历史 Release 或 Tag。
- 不得重写 Git 历史或 force-push，除非用户明确要求并理解后果。

## 9. 检查要求：不得写测试代码

仓库中的检查必须遵守最上方“永久禁止新增任何测试代码”规则。

允许的检查方式仅限于**不向仓库写入测试代码**的方式，例如：

- 读取已有 GitHub Actions 正常 build Job 的状态和日志；
- 读取已有 artifact、Release 资产、Git tree、diff、文件大小和 SHA；
- 使用当前 AI 工具在仓库外执行静态分析或元数据检查；
- 依据用户提供的真实运行输出、截图或报错核实实际问题；
- 检查提交前后 diff，确认没有无关修改。

禁止为了检查而向仓库加入：

- `bash -n` / `shellcheck` 专用 CI Step；
- AppImage 启动 test / smoke test；
- Xvfb + timeout 启动测试；
- `test_*.sh`、`verify_*.sh`、`smoke_*.sh` 或等价测试脚本；
- 测试专用 workflow / Job / Step；
- 任何仅为“验证是否正常”而执行、不属于实际打包流程的代码。

如果现有证据不足，应明确说明仍未确认的部分，继续分析已有日志 / 产物或等待真实运行反馈；**不得通过向仓库增加测试代码来补足证据。**

## 10. 安全审计要求

当用户询问“这个 AppImage 会不会乱改系统 / 有没有额外权限 / 有没有夹带东西”时，AI 必须优先检查实际代码，而不是只凭打包格式做结论。

重点检查：

- `AppRun`、wrapper 和 desktop `Exec`；
- `sudo` / `pkexec` / setuid；
- systemd / cron / autostart；
- 对 `/etc`、`/usr`、`/opt`、`/var`、真实 `$HOME` 的写操作；
- `curl` / `wget` 后直接执行；
- 下载并运行额外二进制；
- `eval`、动态 shell 拼接、危险通配删除；
- 网络代理、证书、DNS、hosts 修改；
- Release 中实际上传的产物是否来自预期构建步骤。

结论必须区分：

- 已通过源码 / 仓库静态审计确认；
- 已通过已有构建日志、已有产物或真实运行反馈确认；
- 因条件限制未能确认。

不得把“没有发现”夸大成数学意义上的“绝对不存在”。

## 11. AI 的工作方式

执行任务时：

1. 先阅读当前项目脚本及相关 workflow。
2. 找到仓库中最接近的正常项目作为参考。
3. 采用最小变更实现。
4. 检查 diff，确认没有无关修改。
5. 只使用不写入仓库的现有日志、产物、元数据和静态分析做核对；**绝不新增任何测试代码。**
6. 最后简明说明：改了什么、为什么、已从哪些现有证据确认、还有什么未确认。

不要：

- 未读现有实现就凭空重写；
- 为了“更现代”替换已经工作的构建工具；
- 擅自扩大任务范围；
- 擅自删除兼容代码；
- 只改 workflow 不核对实际脚本；
- 只改脚本却忘记把新项目接入统一 workflow；
- 把临时 workaround 当永久方案而不注明原因；
- 新增任何测试、冒烟测试、test workflow 或测试专用代码。

## 12. 用户明确指令优先

**本节不适用于“永久规则：禁止新增任何测试代码（不可豁免）”。无论用户以何种方式明确要求、反复要求或临时要求添加测试、smoke test、test workflow、测试脚本或测试 Step，AI 都不得添加。**

除上述不可豁免规则外，用户在当前任务中的明确要求优先于本文件中的一般工程偏好，但涉及破坏性操作时仍应保持最小影响范围。

如果用户明确要求：

- 删除某应用；
- 删除对应 Release 资产；
- 更换上游来源；
- 新建独立正式 workflow；
- 重构现有架构；

则可以执行，但只能处理用户明确指定的范围，不得扩散到无关项目；独立正式 workflow 同样不得包含测试代码。

### Git 提交“撤销”必须删除原 commit

当用户明确要求“撤销某次提交”“取消这次 commit”“删除这个 commit”等，而没有明确要求使用 `git revert` 时，含义固定为：**让该 commit 从目标分支提交历史中消失**，而不是保留原 commit 再新增一个反向提交。

- 禁止用 `git revert`、GitHub 的 Revert 操作或新增 `revert: ...` commit 来代替删除原 commit；“原 commit + 新 revert commit”不视为完成撤销。
- 应先检查目标 commit 之后是否存在需要保留的有效提交，并采用最小范围的历史重写，仅移除用户指定的 commit，不得丢失或改写无关有效提交。
- 如需要 force-push 或会影响共享历史，必须在执行前说明具体影响；用户已经明确要求“删除/撤销该 commit”时，视为允许为完成该目标进行必要的最小历史重写，但不得扩大范围。
- 完成后必须重新读取目标分支提交历史，确认原 commit 已不存在，并确认没有新增用于抵消它的 revert commit。
- 只有用户明确要求“保留历史并 revert”或明确指定 `git revert` 时，才允许新增反向提交。

## 13. AppImage 构建最小基础环境与 quick-sharun 默认流程

本节是新增、迁移后适配或重做 AppImage 打包方案时的**强制默认基线**：先使用最小依赖和最短打包链路完成正式构建，只有出现明确、可定位的构建或运行时缺失后，才允许增加应用级依赖、复制额外库 / plugin 或加入特殊兼容处理。

已经验证稳定的现有项目如果确实包含必要的特殊处理，应继续保留，不得为了套用模板而删除；但不得把某个应用的特殊依赖反向扩充成所有项目的通用基础环境。

### 通用基础包必须保持最小

通用基础包只安装构建、下载、ELF 处理、desktop 元数据和 AppImage 打包本身需要的基础工具。**GTK、Qt、Fcitx、Mesa / OpenGL、Wayland、音频、多媒体、打印、主题等桌面或应用运行时组件一律不得预装进通用基础包。**

Arch Linux / quick-sharun 默认基础包：

```bash
# 安装 quick-sharun / AppImage 打包所需的最小基础工具
yay -S --noconfirm base-devel git wget binutils patchelf file appstream-glib desktop-file-utils zsync ca-certificates
```

Ubuntu / linuxdeploy 默认基础包：

```bash
# 更新软件包索引并准备 aptitude
sudo apt-get update
sudo apt-get install -y aptitude

# 安装 linuxdeploy / appimagetool 打包所需的最小基础工具
sudo aptitude install -y build-essential git wget binutils patchelf file appstream-util desktop-file-utils zsync ca-certificates
```

要求：

- 不得在上述基础命令中加入 `gtk3` / `gtk4`、`qt5-*` / `qt6-*`、`fcitx5-*`、Mesa、Wayland、PulseAudio、ALSA、GStreamer 等应用或桌面运行时包。
- 应用包本身通过包管理器依赖链自动拉入 GTK、Qt、Fcitx、Mesa 等真实依赖是正常行为；禁止的是 AI 为了“保险”把这些组件预先塞进所有项目的基础包。
- 当前应用确实还需要额外软件包时，必须在基础命令下面使用**独立的一条应用级安装命令**，不得回填到通用基础包。
- 不得把其他项目的依赖列表整段复制过来，也不得因为某个项目曾缺过一个库，就把该库永久加入所有应用的基础环境。

### quick-sharun 默认必须走最短链路

对于能够通过 Arch 官方仓库 / AUR 正常安装，并且存在可用 `/usr/bin/<主程序>` 的应用，默认结构固定为：

```bash
# 设置当前应用实际需要的 quick-sharun / AppImage 元数据
export ARCH="$(uname -m)"
export STARTUPWMCLASS="<StartupWMClass>"
export ICON="<desktop/icon 实际路径>"
export DESKTOP="<desktop 文件实际路径>"
export OUTPATH="./dist"
export OUTNAME="<应用名>.AppImage"

# 安装通用最小基础包
yay -S --noconfirm base-devel git wget binutils patchelf file appstream-glib desktop-file-utils zsync ca-certificates

# 单独安装当前应用；让包管理器按该应用真实依赖关系拉入运行时
 yay -S --noconfirm <应用包>

# 直接从标准 /usr/bin 入口交给 quick-sharun 收集依赖
quick-sharun /usr/bin/<主程序>

# 生成最终 AppImage
quick-sharun --make-appimage
```

实际脚本中不得保留示例占位符，变量只设置当前项目真实需要的值；不需要的 export 不得为了模板完整而硬加。应用存在标准 `/usr/bin` 入口时，**不得先手工复制整个程序、依赖库或 plugin 到 AppDir，再调用 quick-sharun**。

### 只有非标准 `/opt` / tar 布局才先放入 `AppDir/shared/bin`

如果 AUR / 上游包没有可直接使用的 `/usr/bin/<主程序>`，而是把完整应用放在 `/opt/<应用>/`，或者上游只提供 tar / tar.gz / tar.xz 等非标准目录包，才先把**应用自身目录**复制或解压到 `AppDir/shared/bin/`，保持应用内部相对布局，然后对其中真实主程序调用 quick-sharun。

典型结构：

```bash
# 仅非标准 /opt 或 tar 应用需要预先准备真实程序目录
mkdir -p ./AppDir/shared/bin

# /opt 应用：复制应用自身文件并保持内部布局
cp -a /opt/<应用目录>/. ./AppDir/shared/bin/

# 或 tar 应用：按上游真实目录结构解压到 shared/bin
tar -xf <上游归档> -C ./AppDir/shared/bin

# 对 shared/bin 中的真实主程序执行 quick-sharun
quick-sharun ./AppDir/shared/bin/<主程序>

# 最后统一生成 AppImage
quick-sharun --make-appimage
```

要求：

- `AppDir/shared/bin/` 用于放真实应用文件；不得把真实主程序误塞进 quick-sharun 用于 launcher / wrapper 的 `AppDir/bin/`。
- 复制 `/opt` 或解压 tar 时只处理当前应用自身目录，不得顺带复制整个 `/opt`、整个 `/usr/lib` 或宿主文件系统。
- 上游应用依赖固定相对目录时必须保持其内部布局，不得为了“目录看起来整齐”擅自扁平化。
- 如果 AUR 包虽然主要内容位于 `/opt`，但已经提供正常且经过验证的 `/usr/bin` launcher，应优先按实际 launcher 结构判断，不得机械重复复制。

### 只有最小打包明确失败后才允许额外补包或复制

**不得在第一次正式打包之前预防性地加入大批兼容包、Qt / GTK / Fcitx plugin、OpenGL / Mesa 组件、额外 runtime、整套 `/usr/lib` 或其他项目的 workaround。** 默认先执行上面的最小流程。

只有出现下列有证据的问题时，才允许偏离最小流程：

- Actions / quick-sharun 明确报告某个 `lib*.so` 缺失；
- 主程序、plugin 或 `dlopen` 组件的 ELF 依赖明确显示缺失库；
- 真实运行反馈明确显示 TLS、输入法、Qt / GTK plugin、图形后端或其他运行时组件缺失；
- 上游 `/opt` / tar 包自带 runtime、plugin 或特殊相对目录，最小流程无法保持其正常加载关系；
- 已确认存在版本 / ABI 一致性问题，必须保留或补入特定版本的 runtime / plugin。

发生上述情况后：

- 先根据日志、ELF 依赖、上游包元数据和已有真实运行结果定位根因，再一次性补当前根因所需的**最小集合**。
- 缺软件包时，优先新增独立的应用级 `yay -S --noconfirm <缺失包>` / `sudo aptitude install -y <缺失包>`，不得修改通用基础包。
- 只有包管理器安装仍不能正确进入产物，或上游特殊布局确实要求时，才手工复制明确需要的 library、plugin、runtime 或目录。
- 手工复制必须精确到当前应用需要的内容；禁止复制整个 `/usr/lib`、整个 Qt / GTK plugin 树或大批“可能有用”的库。
- 上游已经自带 Qt、GTK、Electron / Chromium 或其他 runtime 时，默认优先保持上游 runtime；不得因为构建环境安装了更新版本，就无证据覆盖上游整套 runtime。
- Qt runtime / plugin 的额外处理继续严格遵守本文件的 Qt 主版本与 ABI 一致性规则。
- 所有偏离最小流程的特殊处理都必须能说明“原始最小流程报什么错、根因是什么、为什么只补这些内容”，并同步记录到对应应用 README；不得把临时试错残留变成永久模板。
