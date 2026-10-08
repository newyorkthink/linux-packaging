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
| Windows 原生模块 | 完整提取 ASAR 后，只移除已确认属于 Speak to Window 的 PE 格式 `gemini_native.node`；重新打包前必须确认当前产品层仍声明缺失模块时使用安全回退 |

Gemini 应用版本、Google CDN 安装包地址、安装包校验值以及 Electron runtime 版本均不写死在仓库中。上游发布新 stable 版本后，下一次正式构建会重新读取当前元数据。

Windows PE 原生模块不能由 Linux Electron 加载，因此不会进入最终产品层。当前 Gemini 产品层把 `gemini_native.node` 限定在 Speak to Window 的 Windows 前台窗口、光标和文本注入能力，并在加载失败时明确使用安全回退；Linux 启动入口也不启用对应功能。构建先在外置文件仍存在时完整提取 ASAR，再同时删除外置副本和提取目录中的副本并核对回退标记；若发现其他 PE `.node`、模块位于未识别路径或上游取消安全回退则停止构建，不会静默发布不兼容产品层。

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

构建脚本会按以下顺序识别 Electron 版本：

1. 优先读取当前 `Gemini.exe` 内嵌的 Electron 版本标识；
2. 如果上游隐藏该标识，则读取 `app.asar` 中的 `package.json` 元数据；
3. 如果两者都未提供 Electron 版本，再使用 `Gemini.exe` 内嵌 Chromium 精确版本与 Electron 官方发布元数据进行匹配；
4. 无法可靠确定精确版本时直接停止构建，不会自行固定或猜测某个 Electron 版本。

## 打包流程

`build_gemini.sh` 的正式构建流程如下：

1. 向 Google Omaha 更新服务查询 Gemini `prod` channel 的当前 Windows x64 正式版。
2. 验证返回的版本格式、`dl.google.com` 下载域名、Google DeepMind release 路径、完整安装包大小与 SHA-256。
3. 下载官方完整 NSIS 安装包并使用 `7z` 解包。
4. 定位唯一的 `resources/app.asar` 与对应 `Gemini.exe`。
5. 动态确定 Gemini 实际使用的 Electron 精确版本。
6. 从 Electron 官方 Release 下载对应 `electron-v<版本>-linux-x64.zip`，并按官方 `SHASUMS256.txt` 校验。
7. 以 Linux Electron runtime 为外壳，复制 Gemini 官方产品资源；Windows `.exe` / `.dll` 资源不进入最终 Linux 产品层。
8. 完整提取 `app.asar` 后调用 `patches/remove_windows_native_addon.sh`，从外置资源和提取目录同时删除已确认可安全回退的 PE 格式 `gemini_native.node`；发现其他 PE `.node` 或路径变化时停止构建。
9. 调用 `patches/disable_visible_on_all_workspaces.py`，在重新打包前取消 sticky 窗口并核对 Speak to Window 安全回退仍然存在。
10. 从官方 `Gemini.exe` 提取应用图标（`patches/extract_ico_png.py`），生成 `Exec=Gemini` 的 desktop，并用 `patches/Gemini` 作为简体中文启动器。
11. 使用仓库当前 `quick-sharun` 打包并输出 `dist/Gemini.AppImage`。

构建脚本不固定 `quick-sharun`、sharun 或其他 AppImage 打包工具版本，继续使用统一 AnyLinux 构建环境当前提供的工具链。

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

当前不再对主 `BrowserWindow` 注入背景色、尺寸或其它窗口属性。FastTab 先读窗口的 `_NET_WM_ICON`，Electron 默认放的是原子图，desktop 轮不到。启动器会在打开后把官方 PNG 写进这个属性，同时仍安装 `~/.local/share/applications/gemini.desktop`。i3 规则仍然匹配 `class="^gemini$"`。

## Windows 专用能力边界

本项目不是 Google 官方 Linux 客户端。以下 Windows 原生部分不会直接复制到 Linux：

- `GeminiAppLauncher.exe` 等 Windows launcher；
- Windows DLL；
- Windows 原生 Node `.node` 模块；
- 仅由 Windows API 实现的托盘、全局快捷键、自动启动或其他系统集成功能。

当前产品层仍会尝试连接 Windows named pipe `\\\\.\\pipe\\Google.Gemini.AppLauncher`。Linux 中不存在该 helper，因此终端可能持续出现 `helper_ipc` 重连日志；目前已确认这不会阻止主界面启动、登录和聊天。

从 Gemini 1.11.4 开始，官方 Windows 产品层已经包含 `gemini_native.node`。该模块本身不能由 Linux Electron 加载，因此构建只删除实际识别为 PE 的这个模块；当前产品层会捕获加载失败并让 Speak to Window 使用安全回退，主窗口、登录和聊天不依赖该 Windows 模块。Linux 不提供该模块负责的 Windows 前台窗口、光标、辅助功能树和文本注入能力；未来出现其他 PE `.node` 时不会套用这一结论。

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
- 已确认的 PE 格式 `gemini_native.node` 不进入最终 AppImage；出现其他 PE `.node` 或当前产品层的安全回退标记发生变化时构建会停止，不再回退或重新发布旧版资产。

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

### 2026-10-08：主窗口是 BaseWindow

- 现象：新包重启后切换器仍是 Electron 原子图。日志里的 `Path must be absolute` 来自崩溃报告目录，不是图标。
- 根因：Gemini 主窗口用的是 `BaseWindow`，并且优先加载 asar 里的 `icon.ico`。Linux 读不了这个 ico，就退回原子图。之前只包了 `BrowserWindow`。
- 处理：同时包住 `BaseWindow`，并每 0.5 秒把包外的官方 PNG 设回窗口。
- 修改文件：`gemini/patches/set_linux_window_icon.py`、`gemini/README.md`。

### 2026-10-08：官方图标要在窗口创建时就写上

- 现象：退出 FastTab / AltTab 后，Gemini 仍是 Electron 原子图。
- 根因：打包后 Electron 从 `shared/bin` 启动，`process.resourcesPath` 里没有 `gemini.png`，主进程补丁直接跳过。外部写入又会在窗口出现前随父进程退出。
- 处理：启动器把 PNG 绝对路径交给主进程，窗口一创建就用这张图。外部程序改为无视父进程退出，并把 256 图标缩到 128，避免 X 请求过大。
- 修改文件：`gemini/patches/Gemini`、`gemini/patches/set_linux_window_icon.py`、`gemini/patches/set_gemini_icon.c`、`gemini/README.md`。

### 2026-10-08：FastTab 改读窗口上的官方图标

- 现象：装了 `gemini.desktop` 之后，FastTab 里仍是 Electron 原子图。
- 根因：FastTab 先用 `_NET_WM_ICON`，有这个属性就不再看 desktop。Electron 自己写上了原子图。
- 处理：启动后把官方 PNG 写进 `WM_CLASS=gemini` 窗口的 `_NET_WM_ICON`。不改窗口尺寸、背景，也不改 `Gemini.AppImage` 这个大写文件名。
- 修改文件：`gemini/patches/set_gemini_icon.c`、`gemini/patches/png_to_argb.py`、`gemini/patches/Gemini`、`gemini/build_gemini.sh`、`gemini/README.md`。

### 2026-10-08：任务切换器改认 gemini.desktop

- 现象：上一包已经把窗口 `icon` 设成官方 PNG，任务切换器仍显示 Electron 原子图。
- 根因：切换器按 `WM_CLASS=gemini` 找 desktop 图标。包内 desktop 的 `StartupWMClass=Gemini` 对不上，于是回退到 Electron 自带图标。`BrowserWindow.setIcon` 改变不了这个结果。
- 处理：启动时安装 `~/.local/share/applications/gemini.desktop` 和 hicolor 里的官方 PNG，并设置 `CHROME_DESKTOP=gemini.desktop`。窗口类仍是 `gemini`。窗口属性里的图标也改为始终覆盖，不再只在上游没写 `icon` 时补。
- 修改文件：`gemini/patches/Gemini`、`gemini/patches/set_linux_window_icon.py`、`gemini/build_gemini.sh`、`gemini/README.md`。

### 2026-10-08：新版本没有白边

- 现象：以前记录的首次启动白边 / 白色空白，在当前新版本里没有再出现。
- 处理：标成不用再修。不要为白边改 `BrowserWindow` 背景、尺寸或产品层。

### 2026-10-08：窗口图标改用官方 PNG

- 现象：任务切换器里 Gemini 窗口仍显示 Electron 默认原子图标。
- 处理：从 `Gemini.exe` 提取的官方 PNG 放到 `resources/gemini.png`。主入口只在上游 `BrowserWindow` 选项没有 `icon` 时补上它。不改尺寸、背景色或其它窗口属性。
- 修改文件：`gemini/build_gemini.sh`、`gemini/patches/set_linux_window_icon.py`、`gemini/README.md`。

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
- 当前不再处理：首次启动白边 / 白色空白、任务切换器窗口图标、仅影响视觉或终端日志但不影响核心使用的问题。2026-10-08 补充：新版本已经没有白边，白边不用再修；窗口图标另见同日变更。
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
