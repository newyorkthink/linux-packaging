# AGENTS.md

本文件是本仓库中所有 AI coding agents（Codex、Claude Code、Copilot、Gemini CLI 等）的仓库级操作规范。

除非用户在当前任务中明确要求例外，否则以下规则均视为强制约束。

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

## 3. 宿主系统安全：权限必须必要且最小

构建、打包和测试过程默认不得修改用户真实宿主系统。最终应用如果因为自身核心功能确实需要系统级权限或系统集成，可以使用必要权限，但必须与上游功能一致、范围最小、行为明确且可审计。

例如 VPN、代理、网络管理、TUN/TAP、路由、防火墙、设备访问、udev、系统服务等应用，可能天然需要 `sudo`、`pkexec`、Linux capabilities、systemd、网络配置或其他系统级操作；不得因为本规范而人为移除这些正常且必要的功能。

### 默认禁止

- 禁止执行与当前应用功能、构建或验证无关的系统修改。
- 禁止无理由修改 `/etc`、`/usr`、`/opt`、`/var`、`/boot`、系统服务、systemd unit、PAM、sudoers、shell profile 等宿主系统状态。
- 构建和测试过程禁止污染用户真实 `$HOME`；应使用项目目录或隔离的测试 HOME。最终应用正常运行时，可以按上游正常行为写入自己的 `~/.config`、`~/.local`、`~/.cache` 等应用数据目录。
- 禁止安装与应用核心功能无关的开机启动项、桌面自启动、后台 daemon、cron 或 systemd user service。
- 禁止修改与应用核心功能无关的防火墙、网络、DNS、代理、路由、内核参数、驱动或 udev 规则。
- 禁止执行与应用核心功能、构建或验证无关的提权操作。
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

清理操作必须限制在当前项目自己的已知构建目录中，例如 `source/`、`AppDir/`、`dist/`、`verify/`、测试 HOME 等。

## 4. Shell 构建脚本规范

新增或重写 Bash 构建脚本时：

- 使用 `#!/usr/bin/env bash`。
- 默认使用 `set -Eeuo pipefail`。
- 先解析脚本自身目录，例如：
  `SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"`。
- 构建文件路径尽量基于 `SCRIPT_DIR`，不要依赖调用者当前工作目录。
- 删除文件前必须确保目标是当前项目内部的确定路径。
- 对架构、下载结果、关键文件、ELF 类型等进行显式检查，失败时立即退出。
- 下载使用失败即退出、重试和合理超时参数。
- 对可获得的官方 SHA-256 / digest 进行校验；没有上游 digest 时至少记录本地 SHA-256。
- 不允许静默吞掉关键错误；`|| true` 只能用于明确允许失败且后续有检查的非关键步骤。
- 路径和变量必须正确引用，避免 word splitting 和 glob 意外展开。

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

## 6. AppImage 内容规则

AppImage 应只包含应用正常运行所需内容。

- 优先保留官方二进制、`resources`、desktop 文件和图标。
- desktop / icon 优先从官方包或上游源码中提取，不要擅自制作假图标或改变品牌。
- 允许为解决缺失依赖而补充必要共享库。
- 不要打包宿主机私有配置、凭据、token、SSH key、浏览器数据、缓存或个人文件。
- 不要把构建机的绝对路径、临时目录或用户 HOME 写死进最终产物。
- 不要为了“全打包”盲目复制整个 `/usr/lib`。
- 对 glibc、动态加载器、GPU 驱动、Mesa/NVIDIA/VAAPI 等高度宿主相关组件要谨慎；只有在明确必要并验证兼容性后才处理。
- `AppRun` / wrapper 默认只做启动 AppImage 所必需的环境准备；如果应用核心功能确实需要系统权限或系统集成，可以调用必要的辅助机制，但必须遵守第 3 节的最小权限和可审计要求，不得夹带无关系统修改。

### AppImage 打包方式由 AI 根据项目自行判定

本仓库不强制所有应用使用同一种 AppImage 打包工具。新增应用或处理尚未稳定的打包方案时，AI 必须先检查上游包类型、程序技术栈、ELF 与动态依赖、插件 / `dlopen` 依赖、目标发行版兼容性、glibc / loader 要求、FUSE / runtime 兼容性以及仓库中相近项目的成熟做法，然后选择**一套最合适的方案**。

允许并常用的路线包括：

- **quick-sharun / sharun：** 适合需要较强跨发行版兼容性、自包含运行库、非 FHS / 较旧发行版兼容，或现有相近项目已经通过该路线稳定运行的应用。quick-sharun 使用的 uruntime 具备在 FUSE 不可用时回退到其他运行方式的能力，因此不能把它简单等同于传统 AppImage 的 FUSE 依赖模型。
- **linuxdeploy：** 适合构建或整理 AppDir、自动收集 ELF 共享库和相关资源，以及配合 Qt / GTK 等插件部署运行时依赖。linuxdeploy 的核心职责是部署 AppDir；使用 `--output appimage` 时最终仍通过 AppImage 输出插件 / appimagetool 生成 AppImage。
- **linuxdeploy + 官方 appimagetool：** 如果需要 linuxdeploy 负责收集依赖，但希望使用当前官方 appimagetool / 官方最新 type2 runtime 生成最终 AppImage，可以让 linuxdeploy 只完成 AppDir 和依赖部署，不使用它的最终 AppImage 输出，然后再由官方 appimagetool 对完成的 AppDir 打包。需要当前较新的 runtime / FUSE 兼容行为时，优先考虑并验证这条链路。
- **官方 appimagetool 直接打包：** 适用于 AppDir 本身已经完整、依赖已经由上游、手工逻辑或其他工具正确部署的项目。appimagetool 的职责是把 AppDir 转为 AppImage，**不会替代 linuxdeploy / sharun 自动发现并补齐缺失运行库**。

选择规则：

- 不得把“quick-sharun”“linuxdeploy”“appimagetool”中的任意一种写成仓库唯一标准工具。
- 不得简单把工具名称永久等同于某个固定 FUSE 版本。最终 FUSE / runtime 行为取决于实际嵌入的 AppImage runtime 和工具版本；linuxdeploy 的 AppImage 输出链路也使用 appimagetool，相关 runtime 可能随版本变化。
- 如果实际验证发现 linuxdeploy 默认输出使用的 runtime 不符合当前目标环境，而 linuxdeploy 的依赖部署本身正常，应优先保留 linuxdeploy 的依赖收集结果，再改用当前官方 appimagetool / 指定官方 runtime 完成最终打包，而不是重写整套依赖部署逻辑。
- AI 应自行根据项目情况选择最稳妥的一套方案，不应因为存在多种工具就把选择题转交给用户；只有不同方案会造成用户可感知的功能、兼容范围、体积或运行权限差异时，才需要明确说明取舍。
- 已经验证稳定的现有项目，其打包方式视为稳定基线。不得仅因为 AI 更偏好另一种工具，就把 quick-sharun 改成 linuxdeploy、把 linuxdeploy 改成 quick-sharun，或改写为另一套 appimagetool 流程。
- 新应用可以在临时 test workflow 中验证所选路线；如果首选方案暴露明确兼容性问题，可以在完成原因分析后切换工具，但禁止依赖 GitHub Actions 反复盲试多套方案。
- 无论采用哪种路线，最终都必须验证 AppImage 可提取、关键依赖无缺失、desktop / icon / AppRun 正确，并根据项目情况执行隔离 smoke test；涉及 FUSE / runtime 兼容性时，应额外核对最终实际 runtime，而不是只根据构建命令推断。

## 7. GitHub Actions：保持统一工作流

正式、长期维护的标准 AppImage 构建统一放在：

`/.github/workflows/build.yml`

该 workflow 的既有设计是：

- 一个统一入口；
- 每个应用独立 Job；
- 每个 Job 独立运行环境；
- 不使用 Matrix；
- 通过 plan 阶段决定需要构建的项目；
- 能复用 `.github/actions/build-anylinux` 时优先复用。

### 新应用首次接入允许临时测试 workflow

新增一个尚未验证的应用时，允许先创建一个独立的临时 test workflow，用于隔离验证构建脚本、依赖、AppImage 打包、运行时依赖和 smoke test。这样可以避免在构建方案尚未稳定时直接修改正式统一 `build.yml`。

要求：

- 临时 test workflow 只用于新应用首次接入或明确需要隔离排查的构建问题，不作为长期正式构建入口。
- 可以直接在 `main` 上使用临时 test workflow，不需要为了测试另外创建测试分支。
- test workflow 应只包含当前新应用所需内容，不得顺带复制、修改或重构其他应用 Job。
- test workflow 必须提供当前 AI 实际能够触发的方式。若当前 GitHub 工具支持 `workflow_dispatch`，可以使用手动 dispatch；若当前工具没有 dispatch 接口，则应使用受限的 `push.paths` 等自动触发方式，使 AI 提交到 `main` 后 GitHub Actions 能自动运行。不得创建一个当前 AI 自己无法触发、随后又要求用户手工点击的测试 workflow。
- 使用 `push` 自动触发临时测试时，paths 必须精确限制在当前新应用目录和该临时 test workflow 本身，避免修改无关文件时反复触发测试。
- 测试阶段默认不要覆盖正式 `latest` Release 中其他应用资产；如确实需要测试上传产物，应保证资产范围只属于当前测试应用。
- test workflow 验证通过后，必须把该应用正式接入 `.github/workflows/build.yml`，并删除临时 test workflow，不能让两套正式构建入口长期并存。
- 正式接入时，应把新项目补入 `build.yml` 的相关位置，包括但不限于：push paths、`workflow_dispatch` 选项、plan 的 key/script/dir 映射以及对应独立 Job。
- 正式接入后必须保持 `KEYS`、`SCRIPTS`、`DIRS` 的顺序和一一对应关系。

### AI 触发与检查 GitHub Actions

- AI 在修改 workflow 或构建脚本前，必须先读取实际触发条件，并检查当前可用的 GitHub 工具能力，不能未经检查就声称“没有接口”“不能自动跑 Actions”或要求用户手工操作。
- `on: push` 是 GitHub 自身的自动触发机制。只要 AI 有权限把符合 `paths` 条件的修改提交到对应分支，提交本身即可触发 Actions，不需要额外的“运行 Actions”接口。
- 如果 workflow 已配置适用的 `push` 触发，AI 应完成必要修改并提交，让 GitHub Actions 自动运行，然后继续检查对应 workflow run / Job / 日志 / 产物；不能把正常可自动完成的步骤转交给用户。
- 如果任务需要 `workflow_dispatch`，应先确认当前工具是否提供 dispatch 能力。只有实际检查后确认当前工具确实不支持该操作时，才能说明这一项能力受限；不得把“缺少 workflow_dispatch 接口”扩大描述成“AI 无法使用 GitHub Actions”。
- 如果当前工具不能直接 dispatch，但允许安全地通过现有或临时受限 `push` 触发完成同等验证，应优先使用 push 自动触发，不要求用户手动点击 Run workflow。
- Actions 启动后，AI 应在当前工具允许的范围内主动检查运行状态、失败 Job、日志和产物。不能仅因为 Actions 是异步执行机制，就在能够读取运行结果的场景下直接停止在“已经提交，请用户自己看”的状态。
- 只有在当前工具真实缺少某个必需能力、权限不足或 GitHub 返回明确错误时，才说明具体限制，并准确指出是哪个操作不可用，不得笼统归因于“没有 GitHub 接口”。

### Public / Private 仓库与 Actions 额度

- 在因为 Actions 额度、运行次数或 CI 成本而改变执行策略之前，AI 必须先读取仓库元数据，明确当前仓库是 **Public** 还是 **Private**，不得凭用户账户类型、仓库名称或经验猜测。
- **Public 仓库：** 不得为了“节省 GitHub Actions 额度”而跳过、关闭、延迟或要求用户手动执行本来正常且必要的 Actions。对于构建、测试、打包、Release 验证等正常 CI/CD，需要自动运行就应正常自动运行；正确性、完整验证和正常 CI/CD 需求优先。
- **Public 仓库：** 不得因为用户使用 GitHub 免费账户，就擅自把 Private 仓库的 Actions 分钟限制逻辑套用到 Public 仓库，也不得因此取消 `push` 自动触发、减少必要 Job 或省略必要测试。
- **Private 仓库：** 应同时考虑 Actions 分钟和无效运行成本。提交前要尽量完成静态检查，精确限制 `paths` / 触发条件，避免明显无意义的重复构建和用 Actions 反复试错；但必要的构建、测试和验证仍然必须执行，不能为了省额度直接跳过关键验证。
- 仓库可见性可能改变，因此每次涉及“是否要省 Actions”“是否自动触发”“是否运行测试”的判断，都应以当前实际 repository visibility 为准，而不是沿用旧结论。
- 无论 Public 还是 Private，都应避免配置错误导致的无限触发、无意义 schedule、重复 Job 或明显无效运行；区别在于 Public 仓库不能把“省额度”作为减少正常必要 CI/CD 的理由。

### 正式 workflow 规则

- 不得把已经验证并正式接入的普通 AppImage 项目再长期拆成独立 workflow。
- 不要把已有独立 Job 改成 Matrix，除非用户明确要求整体架构重构。
- 不要为了节省 public repository 的 Actions 使用量而合并本来应该隔离的构建任务；构建正确性和隔离性优先。
- `.github/workflows/build_runimage.yml` 是另一类构建入口；普通 AppImage 任务不要擅自迁移过去。
- 只有当现有统一 workflow 明确无法满足正式构建需求，或者用户明确要求时，才考虑长期新增独立 workflow。

## 8. Release 规则

仓库使用 `latest` Release 作为持续更新的发布入口时：

- 只更新当前任务对应的资产。
- 不得删除或覆盖其他应用资产。
- 资产名必须稳定、清楚，并与现有命名约定保持一致。
- 构建失败时不得伪造成功产物或上传空文件。
- 不要无理由删除整个 `latest` Release、历史 Release 或 Tag。
- 不得重写 Git 历史或 force-push，除非用户明确要求并理解后果。

## 9. 验证要求

只“构建成功”不等于任务完成。能执行时应进行适当验证。

至少根据项目类型选择以下检查：

- `bash -n` 检查 shell 语法；
- `shellcheck`（环境可用时）；
- `file` 检查产物及关键 ELF；
- `desktop-file-validate`；
- AppImage `--appimage-extract` 验证可提取；
- `ldd` / ELF 依赖审计，确认没有非预期的缺失共享库；
- 检查 AppDir 中是否误带宿主用户文件、凭据和绝对路径；
- 使用隔离 `HOME` / `XDG_*` 目录进行 smoke test；
- GUI 应用在 CI 中可使用 Xvfb + timeout 做非交互启动测试；
- 输出 SHA-256 便于审计。

冒烟测试不得污染真实用户 HOME。

如果由于 CI、图形环境、网络或上游服务限制无法完整验证，应明确指出未验证的部分，不能把“未测试”描述成“已确认正常”。

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

- 已通过源码静态审计确认；
- 已通过构建/运行测试确认；
- 因条件限制未能验证。

不得把“没有发现”夸大成数学意义上的“绝对不存在”。

## 11. AI 的工作方式

执行任务时：

1. 先阅读当前项目脚本及相关 workflow。
2. 找到仓库中最接近的正常项目作为参考。
3. 采用最小变更实现。
4. 检查 diff，确认没有无关修改。
5. 能测试则测试，不能测试则说明限制。
6. 最后简明说明：改了什么、为什么、验证了什么、还有什么未验证。

不要：

- 未读现有实现就凭空重写；
- 为了“更现代”替换已经工作的构建工具；
- 擅自扩大任务范围；
- 擅自删除兼容代码；
- 只改 workflow 不核对实际脚本；
- 只改脚本却忘记把新项目接入统一 workflow；
- 把临时 workaround 当永久方案而不注明原因。

## 12. 用户明确指令优先

用户在当前任务中的明确要求优先于本文件中的默认工程偏好，但涉及破坏性操作时仍应保持最小影响范围。

如果用户明确要求：

- 删除某应用；
- 删除对应 Release 资产；
- 更换上游来源；
- 新建独立 workflow；
- 重构现有架构；

则可以执行，但只能处理用户明确指定的范围，不得扩散到无关项目。