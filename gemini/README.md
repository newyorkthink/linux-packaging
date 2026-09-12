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
| Release 产物 | `gemini.AppImage` |

Gemini 应用版本、Google CDN 安装包地址、安装包校验值以及 Electron runtime 版本均不写死在仓库中。上游发布新 stable 版本后，下一次正式构建会重新读取当前元数据。

## 下载与运行

正式构建成功后，普通用户使用 `latest` Release 中的稳定资产：

```text
https://github.com/newyorkthink/linux-packaging/releases/latest/download/gemini.AppImage
```

在 Linux x86_64 终端、AppImage 所在目录执行：

```bash
# 给 Gemini AppImage 添加执行权限
chmod +x gemini.AppImage

# 启动 Gemini
./gemini.AppImage
```

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
5. 检查 `resources` 中是否存在 Windows PE 格式的原生 `.node` 模块；发现此类模块时停止构建，避免把无法在 Linux 加载的原生模块直接发布。
6. 动态确定当前 Gemini 实际使用的 Electron 精确版本。
7. 从 Electron 官方 Release 下载对应 `electron-v<版本>-linux-x64.zip`，并按官方 `SHASUMS256.txt` 校验。
8. 以 Linux Electron runtime 为外壳，替换为 Gemini 官方 Electron 产品资源；Windows `.exe` / `.dll` 资源不进入最终 Linux 产品层。
9. 从官方 `Gemini.exe` 提取应用图标，生成 Linux desktop entry。
10. 使用仓库当前 `quick-sharun` 打包并输出 `dist/gemini.AppImage`。

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

### i3wm

实测 Gemini 上游产品层会在窗口创建后主动设置 visible-on-all-workspaces；在 Linux/i3wm 中表现为窗口出现在所有工作区。单纯使用 `for_window [class="gemini"] sticky disable` 只在窗口创建阶段执行一次，随后会被应用自己的再次设置覆盖，因此不作为最终方案。

当前构建会在打包阶段对官方 `app.asar` 做最小 Linux 兼容修补：仅将显式的 `setVisibleOnAllWorkspaces(true)` / `setVisibleOnAllWorkspaces(!0)` 改为 `false`。如果上游代码结构变化、无法识别该调用，构建会直接停止，不会猜测性修改其他逻辑。

修补只影响跨工作区可见性；Gemini 窗口仍保持 `_NET_WM_WINDOW_TYPE_NORMAL`，i3 下默认继续使用正常平铺行为，不会被改成 floating。

## Windows 专用能力边界

本项目不是 Google 官方 Linux 客户端。以下 Windows 原生部分不会直接复制到 Linux：

- `GeminiAppLauncher.exe` 等 Windows launcher；
- Windows DLL；
- Windows 原生 Node `.node` 模块；
- 仅由 Windows API 实现的托盘、全局快捷键、自动启动或其他系统集成功能。

当前产品层仍会尝试连接 Windows named pipe `\\\\.\\pipe\\Google.Gemini.AppLauncher`。Linux 中不存在该 helper，因此终端可能持续出现 `helper_ipc` 重连日志；目前已确认这不会阻止主界面启动、登录和聊天。

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
- 构建成功后仅覆盖 `latest` Release 中的 `gemini.AppImage`。

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
dist/gemini.AppImage
```

## 变更记录

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
