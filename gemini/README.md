# Gemini Linux 移植

本目录用于构建 **Google Gemini Linux x86_64 AppImage**。Google 当前没有提供官方 Linux 桌面包，因此这里采用实验性 Electron 产品层移植：动态取得 Google 官方 Windows x64 正式版，提取其 Electron 应用资源，再配合同版本官方 Electron Linux x64 runtime 生成 AppImage。

## 当前实现

| 项目 | 当前方案 |
| --- | --- |
| 上游应用 | Google 官方 Gemini Desktop Windows x64 stable channel |
| 上游版本 | 每次构建通过 Google Omaha `prod` 更新服务动态解析，不锁定 Gemini 版本 |
| Windows 包 | Omaha 返回的完整离线 NSIS 安装包，并使用同一响应中的 SHA-256 与文件大小校验 |
| 产品层 | 官方 `resources/app.asar` 及同目录应用资源 |
| Linux 运行时 | 从当前 Gemini 包动态识别 Electron 精确版本，再下载该版本官方 `linux-x64` runtime |
| Electron 校验 | 使用 Electron 官方 `SHASUMS256.txt` 校验 Linux runtime ZIP |
| 打包方式 | 仓库现有 `quick-sharun` AppImage 流程 |
| 支持架构 | `x86_64` |
| Release 产物 | `Gemini.AppImage`。启动器也叫 `Gemini`，对应 Windows 的 `Gemini.exe`，避免和 Gemini CLI 的 `gemini` 命令冲突 |
| Windows 原生模块 | 完整提取 ASAR 后，只移除已识别的 PE 格式 `gemini_native.node`；保留未知模块、路径和提取副本保护，不再匹配上游回退日志文字 |

Gemini 应用版本、Google CDN 安装包地址、安装包校验值以及 Electron runtime 版本均不写死在仓库中。上游发布新 stable 版本后，下一次正式构建会重新读取当前元数据。

Windows PE 原生模块不能由 Linux Electron 加载。已检查的 1.17.0 产品层仍会捕获模块加载异常，并处理模块不可用的情况；当前日志已变为 `Will use fallbacks`。构建先在外置文件仍存在时完整提取 ASAR，再通过原有脚本同时删除已识别模块的外置副本和提取副本；未知 PE `.node`、未知路径和缺少提取副本仍会中止构建。非 sticky 补丁只处理窗口调用，不再用上游日志文字判断原生模块兼容性。该静态结论不代替新版本的 GUI 或登录验收。

## 下载与运行

正式构建成功后，普通用户使用 `latest` Release 中的稳定资产：

```text
https://github.com/newyorkthink/linux-packaging/releases/latest/download/Gemini.AppImage
```

在 Linux x86_64 终端、AppImage 所在目录执行：

```bash
# 给 Gemini AppImage 添加执行权限
chmod +x Gemini.AppImage

# 启动 Gemini
./Gemini.AppImage
```

### 配置目录

Gemini 沿用 Electron 标准 `userData` 目录，Linux 默认保存在：

```text
~/.config/gemini
```

如果系统设置了 `XDG_CONFIG_HOME`，则目录为 `$XDG_CONFIG_HOME/gemini`。替换或更新 `Gemini.AppImage` 不会删除这里保存的登录状态、站点数据、权限和应用设置。启动器改名为 `Gemini` 不会改这个目录，配置目录仍由 Electron 产品名决定。

## 技术栈

Google Gemini Windows 桌面应用当前采用 Electron。Windows 正式安装还包含 Windows 专用的 launcher / 系统集成组件；本项目不通过 Wine 运行这些 Windows 可执行文件，而是仅迁移 Electron 产品层到官方 Linux Electron runtime。

构建脚本从当前 `Gemini.exe` 的 ASCII / UTF-16LE 内嵌标识读取 Electron 精确版本；无法识别时停止，不使用开发依赖范围替代，也不继续旧的 package.json 回退或 Chromium 反查分支。

1.17.0 的实际程序标识为 Electron `44.5.1`，同包 `package.json` 中却仍声明开发依赖 `^42.4.1`，因此不能直接照搬上游按该字段选择 runtime 的做法。

## 打包流程

`build_gemini.sh` 的正式构建流程如下：

1. 通过 `common/download/download_omaha_package.sh` 查询当前 `prod` 正式版，校验应用、版本、下载源、文件名、大小和 SHA-256，并记录来源版本。
2. 通过 `common/archive/extract_archive.sh` 解开官方完整 NSIS 包。
3. 定位唯一的 `resources/app.asar` 和对应 `Gemini.exe`，从实际程序识别精确 Electron 版本。
4. 通过 `common/download/download_latest_checksum_asset.sh` 从官方清单选择同版本 Linux x64 runtime，并校验 SHA-256；再通过公共归档入口解包 ZIP。
5. 以完整 Linux runtime 为外壳，复制产品资源；沿用既有沙盒文件处理，资源中的 Windows `.exe` / `.dll` 不进入最终产品层。
6. 完整提取 ASAR 后调用原有模块移除脚本，同时处理外置副本和提取副本，保留未知模块、路径和副本保护。
7. 调用单参数的非 sticky 补丁，只修改显式 all-workspaces 调用，再重新封装 ASAR；不再核对回退日志或 Speak to Window 开关名称。
8. 直接把包内 `resources/app.asar.unpacked/assets/icon.png` 交给 quick-sharun，不再运行 ICO 转换；旧提取脚本和历史记录保留。原样安装简体中文启动器，并生成大写入口对应的 desktop。
9. 通过公共版本入口读取来源版本并追加 desktop 元数据，使用原有运行项收集依赖；显式部署 GTK3，并按模板生成包内中文 locale。
10. 使用 `quick-sharun --make-appimage` 输出 `dist/Gemini.AppImage`，仅在最终产物有效时通过原有公共入口写入 `dist/version.txt`。

构建脚本不固定 `quick-sharun`、sharun 或其他 AppImage 打包工具版本，继续使用统一 AnyLinux 构建环境当前提供的工具链。

常规版本更新不需要人工修改版本号、摘要或日志字符串。上游若改变资源布局、版本标识、窗口调用或原生依赖，仍须重新核对，不承诺永远不需要维护。

## 维护说明

- [标准模板差异](docs/template-deviations.md)：公共步骤、移植路线、依赖覆盖与执行顺序。
- [pkgforge 采用与未采用项](docs/pkgforge-differences.md)：当前上游固定源码、原始命令、实际落地位置和取舍原因。
- [固定参数与原始故障](docs/hardcoded.md)：来源限制、目录、runtime、补丁、图标和既有配置依据。

## 已验证的 Linux 使用结果

2026-09-12 的正式构建与真实 Linux 使用已经确认：

- AppImage 可以正常启动并创建 Gemini 主窗口；
- Google 账号可以正常登录，Gemini Web 主界面可以正常加载与使用；
- Electron 本地 Settings 界面可固定为简体中文；
- Fcitx5 GTK 输入支持已补齐，相关正式构建成功；
- 摄像头、定位等权限请求可进入 Electron 权限处理流程；
- 当前实测 `WM_CLASS` 为 `"gemini", "gemini"`，窗口类型为 `_NET_WM_WINDOW_TYPE_NORMAL`。

上述确认范围只代表当前 Linux 移植层已经实际运行通过，不代表 Google 官方支持 Linux，也不代表所有 Windows 桌面原生功能已经移植。

### 当前上游兼容状态

2026-11-02 已核对 1.17.0：旧构建失败来自回退日志文字变更，不等于模块加载回退已经消失。本次移除日志字符串断言，保留实际 Electron 版本识别和必要窗口修补，直接使用包内 PNG。已完成 1.17.0 与 Electron 44.5.1 的实际资源组装、ASAR 修补和重封装；完整 AppImage、GUI 和登录结果尚未在本次检查中验证，既有旧版实测结果不变。

以下 2026-09 的判断与实现保留为当时的兼容历史，其中旧 Release 回退和日志标记守卫均已被后续方案替代，不作为恢复旧逻辑的指令。

2026-09-27，Google Omaha `prod` channel 已返回 Gemini `1.12.3`。静态解包官方安装包后确认 `gemini_native.node` 仍是 Windows PE x86-64 模块，但当前 `main.js` 使用 `try/catch` 加载它，加载失败会明确记录 `STC will use safe fallbacks`；所有调用点均先处理模块不可用的情况，Speak to Window 还受 `GEMINI_ENABLE_SPEAK_TO_WINDOW=true` 控制，Linux 启动入口没有启用该开关。

因此，下面 2026-09-17 将 `gemini_native.node` 的存在直接视为整个产品层不可移植的判断，已被 1.12.3 产品层的实际代码证据替代。旧记录继续保留作为当时的故障历史；当前构建会只删除这个已确认模块、确认安全回退标记仍存在，再继续打包当前动态解析到的正式版。Speak to Window 的 Windows 原生窗口定位与文本注入能力仍不属于 Linux 移植范围。

2026-09-17，Google Omaha `prod` channel 已返回 Gemini `1.11.4`。该正式包的 `resources/app.asar.unpacked/src/gemini_native.node` 是 Windows PE 原生 Node 模块，不能直接由 Linux Electron 加载。

当前没有可靠证据表明可以删除该模块、用空文件替代或直接复制到 Linux 后仍保持 Gemini 1.11.4 功能正确，因此构建不会绕过检测，也不会把 1.11.4 标记为 Linux 已发布版本。遇到该结构时，只复用 `latest` Release 中最后一个成功构建的 Linux 兼容 `gemini.AppImage`；复用前必须通过 Release 资产 ID 获取同一快照，并同时核对 Release digest、`software_versions.json` 中的 Gemini 条目和实际下载文件 SHA-256。

后续只有在 Google 再次发布不依赖 Windows 专用 `.node` 的产品层，或能够取得与该模块匹配且来源可靠的 Linux 实现时，才恢复对新 stable 的直接移植。

### 当前基准版与已知非致命问题

当前版本作为 Linux/i3wm 的**稳定基准版**维护，优先保证启动、登录、聊天、中文、Fcitx5 输入和单工作区使用正常，不再为了纯视觉问题继续修改 Google 的主窗口产品逻辑。

已知但当前不处理的问题：

- i3 平铺模式下可能出现窗口内容区域未立即完全铺满；当前建议使用 floating 规避；
- `helper_ipc`、Crashpad、Fontconfig、Glycin 等已记录日志目前均未影响核心使用。

已确认不用再修：

- 白边 / 白色空白。新版本没有这个问题，不要再为它改窗口背景、尺寸或产品层。

上面「已知但当前不处理」的两项仍是非致命边界。白边已经确认不用再修，后面的版本也不要把它重新加回待修项。

### i3wm

当前稳定基线建议在 i3wm 中把 Gemini 设为 **floating + 非 sticky**：

```ini
# Gemini window layout
for_window [class="^gemini$"] floating enable, sticky disable
```

原因：

- Gemini 在 i3 平铺模式下可能出现窗口内容区域未立即完全铺满；当前建议使用 floating 规避。新版本没有白边，不要再按白边处理；
- 改为 floating 后当前实测使用正常，不影响 Gemini 主界面、登录和聊天；
- `sticky disable` 明确限制窗口只出现在当前工作区，不在多个工作区重复显示；
- 该 i3 规则按 `WM_CLASS="gemini"` 匹配，与具体 Gemini 应用版本无关，后续更新 AppImage 通常无需修改。

构建侧仍保留 all-workspaces 的最小 Linux 兼容修补：仅将上游显式的 `setVisibleOnAllWorkspaces(true)` / `setVisibleOnAllWorkspaces(!0)` 改为 `false`。如果 Google 后续版本修改了这段产品层结构、脚本无法可靠识别，构建会停止，不会猜测性修改。

当前不再对主 `BrowserWindow` 注入背景色、尺寸或其它窗口属性。任务切换器里的 Electron 原子图没有改掉，相关补丁已删除，见下方 2026-10-08 记录。i3 规则仍然匹配 `class="^gemini$"`。

## Windows 专用能力边界

本项目不是 Google 官方 Linux 客户端。以下 Windows 原生部分不会直接复制到 Linux：

- `GeminiAppLauncher.exe` 等 Windows launcher；
- Windows DLL；
- Windows 原生 Node `.node` 模块；
- 仅由 Windows API 实现的托盘、全局快捷键、自动启动或其他系统集成功能。

当前产品层仍会尝试连接 Windows named pipe `\\\\.\\pipe\\Google.Gemini.AppLauncher`。Linux 中不存在该 helper，因此终端可能持续出现 `helper_ipc` 重连日志；目前已确认这不会阻止主界面启动、登录和聊天。

从 Gemini 1.11.4 开始，官方 Windows 产品层已经包含 `gemini_native.node`。该模块不能由 Linux Electron 直接加载，因此构建继续只删除实际识别为 PE 且名称和路径符合既有规则的模块。1.17.0 的代码仍会捕获加载失败；其调用还涉及 Windows 原生集成，不再把整个模块描述为仅属于 Speak to Window。Linux 不提供对应的原生实现，未来出现其他 PE `.node` 时不会自动套用当前结论；本次没有验证新版本的 GUI 或登录功能。

实际运行中还可能看到以下非致命日志：

- `Failed to initialize Electron Crashpad reporting: Path must be absolute`：当前 AppImage 环境中的 Crashpad 初始化不兼容，不影响主界面；
- `MaxListenersExceededWarning`：曾在 helper 重连过程中观察到，当前未确认其根因，不能视为主程序崩溃；
- `Fontconfig warning`：宿主字体缓存版本提示，不属于 Gemini 产品层故障；
- `Glycin running without sandbox`：当前 quick-sharun 运行环境提示，已验证不阻止 Gemini 主界面运行。

除非这些日志后续造成实际功能故障，否则不为了“消除日志”去修改 Google 的 `app.asar` 产品逻辑。

## GitHub Actions

Gemini 接入仓库统一正式 workflow：

```text
.github/workflows/build.yml
```

触发规则与其他正式 AppImage 一致：

- `gemini/**` 推送到 `main` 时选择 Gemini 构建任务；
- `workflow_dispatch` 可以选择 `gemini/build_gemini.sh`；
- `workflow_dispatch` 选择 `all` 或每日计划构建时包含 Gemini；
- 构建成功后覆盖 `latest` Release 中的 `Gemini.AppImage`，并把本次动态取得且实际打包的上游版本写入版本清单；
- 已确认的 PE 格式 `gemini_native.node` 不进入最终 AppImage；出现其他 PE `.node`、未知路径或缺少提取副本时仍会停止。构建不再依赖上游日志措辞，也不回退或重新发布旧版资产。

本项目不新增独立 test workflow、smoke Job 或运行时测试 Step。

## 本地构建

正式构建脚本按照仓库统一 **Arch Linux x86_64 + `yay` + `quick-sharun`** 构建环境编写。本地复现时应使用满足这些依赖的构建环境，不应把脚本当作 Debian 系安装脚本直接运行。

在 Arch Linux x86_64 终端、仓库根目录执行：

```bash
# 进入 Gemini 构建目录
cd gemini

# 给构建脚本添加执行权限
chmod +x build_gemini.sh

# 执行 Gemini AppImage 构建
./build_gemini.sh
```

构建成功后的正式产物位于：

```text
dist/Gemini.AppImage
```

## 变更记录

### 2026-11-02：澄清构建环境与可选依赖说明

- 现象：上游差异表把容器升级、`libnss_nis` 和精简依赖混列为未启用，未区分公共准备阶段与应用脚本。
- 核对：正式 workflow 的共享 Action 包含容器软件包升级；Gemini 未额外指定安装 `libnss_nis`，也未调用 `get-debloated-pkgs`。
- 处理：拆分三项状态，补齐代码来源、用途和取舍依据；明确目录清理与依赖安装的作用范围，涵盖 Actions 容器和本地 Arch 构建环境。
- 修改文件：`gemini/README.md`、`gemini/docs/pkgforge-differences.md`、`gemini/docs/template-deviations.md`、`gemini/docs/hardcoded.md`。构建脚本、启动器、补丁和 workflow 均未修改。
- 验证：对照现有 workflow、共享 Action 和安装入口核对说明，检查完整 diff、链接及文档一致性；保留全部既有历史、原始命令和验证边界。

### 2026-11-02：接入公共入口并移除过时的回退日志断言

- 现象：[Actions run 41279519905 的 Gemini Job](https://github.com/newyorkthink/linux-packaging/actions/runs/41279519905/job/124775779381) 已下载并校验 1.17.0 及 Electron 44.5.1，却因 `Gemini product layer no longer declares the safe fallback for the optional Windows native addon` 中止。实际产品仍捕获模块加载失败，日志已改为 `Will use fallbacks`。
- 根因：非 sticky 补丁同时承担了原生模块兼容判断，并硬匹配旧英文日志与功能开关。另查明包内开发依赖 `^42.4.1` 与实际程序使用的 Electron 44.5.1 不同，不能按该字段替换现有运行时识别。
- 修改文件：`gemini/build_gemini.sh`、`gemini/patches/disable_visible_on_all_workspaces.py`、`gemini/patches/remove_windows_native_addon.sh`、`gemini/README.md`、`gemini/docs/template-deviations.md`、`gemini/docs/pkgforge-differences.md`、`gemini/docs/hardcoded.md`、`docs/packaging-export-registry.md`。模块移除脚本只修正用途注释，可执行命令保持原样。
- 处理：主脚本按已核对的标准阶段接入公共下载、摘要和归档入口；保留实际程序版本识别、原生模块移除顺序及非 sticky 修补，去掉过时日志断言；直接使用官方 PNG，退出 ICO 转换链；原样保留中文启动器、既有运行依赖和历史记录，并补齐模板元数据与包内中文 locale。
- 上游：核对 pkgforge commit `e7bf2237e223c0cb8b2625dfdd0b1d2f211ccabc` 的依赖、封装、workflow 和说明；原样采用包内 PNG 的 `ICON` 设置。没有照搬不适用的开发依赖版本读取，也没有恢复自更新、瘦身包、窗口图标注入或其他未启用处理。
- 已验证：28 项检查通过；已在真实 1.17.0 产品代码上复现旧断言失败，完成 Electron 44.5.1 官方下载校验、实际资源组装、ASAR 提取、两处原生模块移除、非 sticky 修补与重封装；其余产品资源逐项保持原样，PNG 字节不变，版本与 desktop 元数据一致。临时工具、样本及测试不进入提交。
- 验证边界：本次没有执行完整 Arch quick-sharun AppImage 构建、图形启动、登录或中文输入测试；此前已确认的旧版 Linux 使用结果保持有效。推送由现有 workflow 正常处理，提交后不等待或监控 Actions。

### 2026-10-23：兼容官方 ICO 仅含 DIB 的图标资源

- 现象：[Actions run `39902547034` 的 Gemini Job](https://github.com/newyorkthink/linux-packaging/actions/runs/39902547034/job/120261371409) 已完成 Gemini 1.16.0 和 Electron 44.5.1 的下载与校验，随后在图标提取时报 `Gemini ICO does not contain a usable embedded PNG frame` 并退出。
- 根因：按 Google Omaha 返回的大小和 SHA-256 校验同版官方安装包后，确认与 `resources/app.asar` 对应的 `Gemini.exe` 只有一个 ICO，其中 6 帧全部为 DIB，没有内嵌 PNG。原提取脚本只接受 PNG，因此不能处理该版图标；调用处还只选择排序后的第一个 ICO，存在遗漏其他图标组的限制。
- 修改文件：`gemini/build_gemini.sh`、`gemini/patches/extract_ico_png.py`、`gemini/README.md`。
- 处理：构建脚本将全部官方 ICO 所在目录传给提取脚本；仍优先原样复制最大的内嵌 PNG。没有可用 PNG 时，按尺寸和色深选择 DIB，将每个候选单独封装为临时单帧 ICO，再由已有 `icoutils` 依赖提供的 `icotool` 转换为 PNG；损坏帧不会阻断其余候选，全部不可用时仍停止构建。未新增软件包依赖。
- 已验证：原脚本在官方 1.16.0 的实际 ICO 上复现同一报错；新脚本生成 256×256 RGBA PNG，并完成图像解码检查。隔离临时目录中的 11 项验证覆盖 PNG 字节原样保留、多个 ICO 的选择、32 位和 24 位 DIB 转换、损坏帧与越界条目跳过、全部损坏及空目录失败；Bash / Python 语法和完整 diff 检查通过。临时工具、样本和验证代码不进入提交。
- 范围：只修复构建时的 AppImage / desktop 图标提取。原有产品层补丁、中文启动器、输入法、动态版本、Electron runtime 和 quick-sharun 流程保持原样，不恢复已删除的任务切换器窗口图标补丁。
- 验证边界：本次未执行完整 AppImage 构建或实机运行；提交后不监控 Actions，正式构建及运行结果未验证。

### 2026-10-08：窗口图标没改掉，补丁已删除

- 现象：FastTab 和 AltTab 里 Gemini 仍是 Electron 默认原子图。实机换新包、退出切换器、重启之后都一样。
- 试过、没有生效、已经从构建里删掉的东西：
  - 约 490 行。文件是 `patches/set_linux_window_icon.py`、`patches/set_gemini_icon.c`、`patches/png_to_argb.py`，以及 `build_gemini.sh` 和启动器 `patches/Gemini` 里配合它们的调用。
  - 主进程里给 `BrowserWindow` / `BaseWindow` 补官方 PNG。
  - 启动时写 `~/.local/share/applications/gemini.desktop` 和 hicolor 图标。
  - 另外用 X11 把官方 PNG 写进窗口的 `_NET_WM_ICON`。
- 为啥没效果：切换器先用窗口上已有的 Electron 原子图。上面这些写法没有换成你在切换器里看到的官方星标。不改 FastTab / AltTab 就没能改掉这个结果。
- 现在：这些补丁不在仓库里，也不会打进下一个 `Gemini.AppImage`。AppImage 自己的 desktop 图标仍从 `Gemini.exe` 提取，那是安装包图标，不是切换器里的窗口图标。
- 留下的：大写 `Gemini` 文件名和启动器、`software_key`、白边不用再修、i3 的 `class="^gemini$"`。

### 2026-10-08：切换器原子图，五次都无效，补丁已删除

目标：FastTab 和 AltTab 里 Gemini 窗口显示的是 Electron 默认原子图，要换成官方星标。禁止改 FastTab、AltTab。白边已确认新版本没有，和这次无关，不要再修。大写 `Gemini` 文件名不要改回去。

每次用户都换了当次打出来的包装上实机看，结果都是原子图。下面每一条都无效，不要再试同一写法。

1. 无效。`patches/set_linux_window_icon.py` 在重新打包的 `app.asar` 里，只给没有 `icon` 的 `BrowserWindow` 补上从 `Gemini.exe` 抽出的官方 PNG。切换器仍是原子图。
2. 无效。启动器 `patches/Gemini` 启动时写入 `~/.local/share/applications/gemini.desktop` 和 hicolor 里的官方 PNG，并设置 `CHROME_DESKTOP=gemini.desktop`、`StartupWMClass=gemini`。桌面文件对上了窗口类，切换器仍是原子图。`BrowserWindow` 的 `icon` 也没改变这个结果。
3. 无效。新增 `patches/png_to_argb.py`（104 行）和 `patches/set_gemini_icon.c`（163 行）。启动器后台用 X11 把官方 PNG 写进 `WM_CLASS=gemini` 窗口的 `_NET_WM_ICON`。切换器仍是原子图。
4. 无效。主进程补丁改为窗口一创建就读 `GEMINI_ICON_PATH`。原因是打包后 `process.resourcesPath` 里没有 `gemini.png`，外部进程还会在窗口出现前退出。改完切换器仍是原子图。
5. 无效。主窗口实际是 `BaseWindow`，不是 `BrowserWindow`，而且会优先用 asar 里的 `icon.ico`。补丁改成包住 `BaseWindow`，并每 0.5 秒把包外官方 PNG 设回去。切换器仍是原子图。

行数：这五次加在一起大约 490 行，主要在上面三个补丁文件，以及 `build_gemini.sh`、`patches/Gemini`、本 README。提交 `208732e` 把补丁从构建里拿掉，该提交删 477 行、加 24 行。三个文件整份删除：`set_gemini_icon.c` 163 行、`set_linux_window_icon.py` 117 行、`png_to_argb.py` 104 行。

结论：只改 Gemini 包没有换成切换器里看到的官方星标。不要把这五次再加回去，也不要改 FastTab 或 AltTab 来硬编码 Gemini。AppImage 自己的图标仍从 `Gemini.exe` 提取，那只是安装包图标。

### 2026-10-08：新版本没有白边

- 现象：以前记录的首次启动白边 / 白色空白，在当前新版本里没有再出现。
- 处理：标成不用再修。不要为白边改 `BrowserWindow` 背景、尺寸或产品层。

### 2026-10-08：产物和启动器改为 Gemini

- 现象：AppImage 和启动器都叫小写 `gemini`，和 CC Switch 管理的 Gemini CLI 命令 `gemini` 撞名。
- 处理：对齐 Windows 主程序 `Gemini.exe`。Release 资产、desktop `Exec`/`Icon` 和 AppDir 启动器改为 `Gemini`，版本清单的 `software_key` 也是 `Gemini`。配置目录仍是 `~/.config/gemini`。
- 构建脚本改为调用已有公共入口清理目录、安装依赖、下载校验和写入 `version.txt`。Linux 专用改动拆到 `gemini/patches/`：去掉 Windows 原生模块、取消 sticky 窗口、提取 ICO 里的 PNG、简体中文启动器。
- 旧的 `gemini.AppImage` 不会被同名覆盖，下次正式构建成功后 `latest` 上会同时留下旧资产，需要的话再手动删掉。

### 2026-09-12：新增 Gemini Linux 实验性移植

- 现象：Google 已发布 Gemini Windows/macOS 桌面应用，但没有官方 Linux 桌面包；官方下载页的 Windows `GeminiSetup.exe` 是 Google Updater 引导器，不能直接作为完整产品层来源。
- 根因：实际 Windows 正式包由 Google Omaha 更新服务按 App ID 和 stable channel 下发，Linux 又缺少 Google 官方 Gemini runtime。
- 修改文件：`gemini/build_gemini.sh`、`gemini/README.md`、`.github/workflows/build.yml`。
- 处理：改为直接查询 Google Omaha `prod` channel，动态取得并校验完整 x64 NSIS 包；提取官方 Electron 产品层，动态确定 Electron 精确版本，搭配同版本官方 Linux x64 runtime 后由 quick-sharun 封装。
- 边界：Windows launcher / DLL / Windows 原生 Node 模块不作为 Linux runtime 使用；发现 Windows PE `.node` 时构建主动停止。首次正式构建及真实 Linux 功能兼容结果以对应 Actions 与实际产物为准。

### 2026-09-12：修复官方 ICO 中异常 DIB 导致的构建失败

- 现象：首次正式 Actions 已成功完成 Google Omaha 查询、108.8 MB 官方 NSIS 下载与 SHA-256 校验、产品层解包、Electron 44.2.0 识别以及对应 Linux x64 runtime 下载校验，但在应用图标阶段由 `icotool` 报 `incorrect total size of bitmap` 并退出。
- 根因：`Gemini.exe` 的官方 ICO 资源中存在一个 DIB bitmap 条目，其声明大小与实际数据不一致；`icotool -x` 会因为该单个异常条目终止整个 ICO 解包。该错误与 Gemini NSIS、`app.asar` 或 Electron runtime 无关。
- 修改文件：`gemini/build_gemini.sh`、`gemini/README.md`。
- 修复：继续使用 `wrestool` 从官方 `Gemini.exe` 提取 ICO，但不再让 `icotool` 解码全部 bitmap；改为使用 Python 标准库读取 ICO 目录并直接选择官方内嵌的最大 PNG 帧，原始 PNG 字节不做重编码。
- 已知结果：首次 Actions 已确认上游完整包与 Electron 44.2.0 runtime 解析链正确；本次修复只替换失败的图标解码步骤，不改 Omaha、产品层、Electron 或 quick-sharun 路径。

### 2026-09-12：补齐 quick-sharun 的 hostname 构建依赖

- 现象：ICO 修复后的正式 Actions 已成功选择并写出官方 256×256 PNG 图标，随后进入 quick-sharun 时报告 `/usr/bin/hostname is NOT present`。
- 根因：Gemini 打包命令明确把 `/usr/bin/hostname` 作为运行项交给 quick-sharun，但 Arch Linux 构建容器中的该命令由 `inetutils` 提供，初始依赖列表漏装了这个包。
- 修改文件：`gemini/build_gemini.sh`、`gemini/README.md`。
- 修复：在既有基础依赖中补充 `inetutils`，并把 `hostname` 加入构建前命令存在性检查；不修改 Omaha、Electron、产品层、图标、输入法、sandbox 或 workflow。

### 2026-09-12：补齐 Fcitx5 中文输入

- 现象：Gemini AppImage 已可正常启动、登录并显示中文界面，但在文本输入框中无法使用宿主机 Fcitx5 输入中文。
- 根因：构建环境只有 GTK3，本次 AppImage 未包含 `fcitx5-gtk` 提供的 `im-fcitx5.so` 与对应 Fcitx5 GTK 客户端运行库，因此 Electron/GTK 输入上下文无法接入宿主 Fcitx5。
- 修改文件：`gemini/build_gemini.sh`、`gemini/README.md`。
- 修复：仅在正式构建环境补装 `fcitx5-gtk`，继续使用现有 quick-sharun GTK3 部署逻辑自动收集输入法模块、客户端库及 GTK 输入模块缓存；不修改已验证有效的 Gemini 产品层、Omaha、Electron 版本识别、登录、图标和启动逻辑。

### 2026-09-12：固定 Linux 桌面界面为简体中文

- 现象：Gemini Web 主界面可以显示中文，但桌面壳层 Settings 等本地 Electron 界面仍可能显示英文。
- 修改文件：`gemini/build_gemini.sh`、`gemini/README.md`。
- 修复：启动 wrapper 固定 `LANGUAGE=zh_CN:zh`，并向 Electron/Chromium 传递 `--lang=zh-CN`；不覆盖宿主机完整 locale，也不修改 Gemini 账号、Web 请求或产品层逻辑。
- 已验证：正式 Actions #394 构建成功，真实 Linux 运行中 Settings 已显示为简体中文。

### 2026-09-12：整理真实 Linux 基线

- 正式 Actions #389 已确认补入 Fcitx5 GTK 输入模块后的 Gemini 构建成功。
- 真实 Linux 使用已确认 AppImage 启动、Google 登录、Gemini 主界面、简体中文桌面壳层正常。
- i3wm 实测 `WM_CLASS="gemini", "gemini"`、窗口类型为 `_NET_WM_WINDOW_TYPE_NORMAL`；后续确认上游会在窗口创建后再次设置 all-workspaces，单次 i3 `sticky disable` 会被覆盖，因此最终改为构建期最小修补该 Electron 调用。
- `helper_ipc`、Crashpad、Fontconfig、Glycin 等现有日志按“已知非致命边界”记录，不为清理日志主动修改已验证可用的产品层。

### 2026-09-12：修复 i3wm 下 Gemini 跨所有工作区显示

- 现象：`WM_CLASS="gemini", "gemini"` 且窗口类型为 `_NET_WM_WINDOW_TYPE_NORMAL`，但 Gemini 仍会出现在所有 i3 工作区；`for_window [class="gemini"] sticky disable` 和对当前窗口执行 `sticky disable` 均会被应用随后重新设置覆盖。
- 根因：Gemini 产品层会在窗口创建后调用 Electron `setVisibleOnAllWorkspaces(true)`（压缩代码也可能写为 `!0`），Linux/i3 将其映射为 sticky/all-workspaces。
- 修改文件：`gemini/build_gemini.sh`、`gemini/README.md`。
- 修复：构建时解包当前官方 `app.asar`，只把显式的 `setVisibleOnAllWorkspaces(true/!0)` 改为 `false` 后重新打包；若当前上游找不到该模式则停止构建，避免误改其他产品逻辑。窗口仍保持普通 i3 平铺窗口。

### 2026-09-12：确定最终 Linux / i3wm 基准版

- 正式 Actions #401 已成功构建撤回 BrowserWindow 注入后的版本，恢复 Google 上游窗口 resize / 内容自适应逻辑。
- 当前保留：动态上游版本解析、官方 Electron runtime、Fcitx5、简体中文环境、all-workspaces 最小修补。
- 当前不再处理：首次启动白边 / 白色空白、任务切换器窗口图标、仅影响视觉或终端日志但不影响核心使用的问题。2026-10-08 补充：新版本已经没有白边，白边不用再修。窗口图标试过约 490 行补丁，切换器里仍是原子图，补丁已删除，不要再按那些写法改。
- i3wm 最终推荐规则为 `for_window [class="^gemini$"] floating enable, sticky disable`；floating 用于规避当前平铺窗口适配问题，`sticky disable` 确保 Gemini 只存在于当前工作区。
- 后续策略：每次 Google Gemini Desktop stable 更新仍由构建脚本动态获取；新版本发布后重新观察这些已知问题是否由上游修复，再决定是否调整兼容层。当前版本作为后续排查和升级对比的稳定基线。

### 2026-09-17：处理 Gemini 1.11.4 的 Windows 原生 Node 模块

- 现象：正式构建已成功解析并下载 Google Omaha `prod` channel 的 Gemini 1.11.4，但 NSIS 解包后发现 `resources/app.asar.unpacked/src/gemini_native.node`，该文件为 Windows PE 原生 Node 模块。
- 根因：现有 Linux 移植路径只能够复用跨平台 Electron 产品资源并替换 Linux Electron runtime；Windows 原生 `.node` 不能由 Linux Electron 直接加载，而当前没有来源可靠、ABI 匹配的 Linux 对应模块。
- 修改文件：`gemini/build_gemini.sh`、`gemini/README.md`、仓库根 `README.md`。
- 处理：保留 Windows PE `.node` 检测，不删除模块、不伪造替代文件，也不发布已知不可加载的 1.11.4 产品层；检测到该结构时，通过 GitHub Release API 取得 `latest` Release 当前资产 ID，下载并校验 `software_versions.json` 与既有 `gemini.AppImage`，要求 Release digest、版本清单 SHA-256 和实际文件 SHA-256 完全一致后才复用最后兼容产物。
- 版本语义：回退路径写入的是最后兼容 AppImage 的真实版本，不写入当前不可移植的 1.11.4，因此 `software_versions.json` 不会产生“资产仍是旧版、版本号却显示 1.11.4”的错误状态。
- 并发处理：每次读取都基于 Release 资产 ID；如果全量构建期间 `software_versions.json` 正在被其他 Build 替换，当前快照失效时会重新读取 Release 元数据后重试，不依赖可能短暂缓存旧内容的固定下载地址。

### 2026-09-17：清单丢失 gemini 条目时仍保留已发布 AppImage

- 故障现象：全量构建时 `software_versions.json` 没有 `gemini` 对象，回退路径 12 次重试后失败；`latest` 上的 `gemini.AppImage` 仍在。
- 处理：清单缺条目时改为校验并复用已发布 AppImage，用 AppImage 自带的 `--appimage-extract '*.desktop'` 读取 `X-AppImage-Version`（uruntime / DwarFS 不能靠 `strings`），再写回清单。仍不发布当前含 Windows PE `.node` 的 1.11.4。

### 2026-09-27：恢复打包当前 Gemini 正式版

- 故障现象：Actions run `36309432672` 的 Gemini Job 已正确解析、下载并校验官方 `1.12.3`，但发现 `gemini_native.node` 后转入旧版资产回退；`latest` Release 已没有 `gemini.AppImage`，12 次读取均得到 `expected exactly one 'gemini.AppImage' asset, got 0`，最终构建失败。
- 根因：旧逻辑只根据 PE `.node` 的存在就判定整个产品层不可移植，没有检查当前产品层怎样加载该模块。对官方 `1.12.3` 的 `app.asar` 静态解包确认，模块加载位于 `try/catch` 中，缺失时明确进入 Speak to Window 安全回退；相关调用点均处理模块不可用，且该功能默认未在 Linux 启动入口启用。
- 修改文件：`gemini/build_gemini.sh`、`gemini/README.md`。
- 修复：删除依赖旧 Release 资产的整段回退逻辑；继续动态取得当前官方 stable 和匹配的 Linux Electron runtime，只从复制后的产品层移除实际识别为 Windows PE 的 `gemini_native.node`，其他 PE `.node` 一律停止构建。重新打包 `app.asar` 前必须确认当前上游仍包含安全回退日志与 Speak to Window 功能开关，标记消失时立即停止，避免以后无条件删除变成静默破坏。
- 兼容边界：Linux AppImage 不提供该 Windows 模块负责的前台窗口、光标、辅助功能树和文本注入能力；本次没有伪造替代模块、锁定版本或修改 Google Web 功能。已完成官方安装包与产品层静态检查，正式 Actions 构建和真实 Linux 运行结果仍待验证。

### 2026-09-27：修复 ASAR 外置模块删除顺序

- 故障现象：Actions run `36315245489` 已进入当前正式版直接移植路径，但脚本先删除 `app.asar.unpacked/src/gemini_native.node`，随后执行 `asar extract` 时因 ASAR 索引仍引用该外置文件而报 `ENOENT`。
- 根因：ASAR 的 unpacked 文件内容保存在 `app.asar.unpacked` 中；完整提取归档时，外置文件必须仍然存在。前一次修复正确识别了应移除的 Windows 模块，但删除时机早于归档提取。
- 修改文件：`gemini/build_gemini.sh`、`gemini/README.md`。
- 修复：先完整提取 `app.asar`，再确认模块名称和外置路径均符合预期，同时删除 `app.asar.unpacked` 中的 Windows PE 副本及提取目录中将被重新打包的副本；安全回退标记、Speak to Window 开关及未知 PE 模块停止构建的保护保持不变。
- 验证边界：本次应完成官方 1.12.3 产品层的解包、模块移除、回退校验和 ASAR 重新打包；正式 Actions 构建和真实 Linux 运行结果仍以提交后的独立结果为准。

## 2026-09-23 自根目录原样迁入

以下原文来自当时根目录 `README.md` 的「当前待处理」，未改写。

- `gemini`：2026-09-17 Google Omaha `prod` channel 的 Gemini 1.11.4 已包含 Windows PE 原生 Node 模块 `resources/app.asar.unpacked/src/gemini_native.node`，现有“Windows Electron 产品层 + 官方 Linux Electron runtime”路径不能安全直接移植该模块。当前构建保留原生模块检测，不删除或绕过，并在遇到此类上游版本时通过 Release 资产 ID、Release digest、`software_versions.json` 和实际文件 SHA-256 校验后继续保留最后一次成功构建的 Linux 兼容 `gemini.AppImage`，版本清单仍记录真实兼容版本。1.11.4 的原生模块 Linux 实现仍未解决；在没有来源可靠、ABI 匹配的 Linux 对应实现前不得强行发布。
