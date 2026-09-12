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

## Windows 专用能力边界

本项目不是 Google 官方 Linux 客户端。以下 Windows 原生部分不会直接复制到 Linux：

- `GeminiAppLauncher.exe` 等 Windows launcher；
- Windows DLL；
- Windows 原生 Node `.node` 模块；
- 仅由 Windows API 实现的托盘、全局快捷键、自动启动或其他系统集成功能。

主 Gemini Electron 界面、登录、聊天及纯 Web/Electron 功能是否完整兼容 Linux，仍以正式构建产物的真实 Linux 使用结果为准。README 不把“成功生成 AppImage”等同于全部桌面原生功能已经得到上游支持。

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
