# AdsPower Global AppImage

用于将 AdsPower Global 官方 Linux x64 版本重新封装为 AppImage。

## 用途与产物

- 打包对象：AdsPower Global，多账号管理与指纹浏览器桌面应用。
- 最终产物：`adspower-global.AppImage`，由统一 `build.yml` 中的 `build_adspower_global` Job 构建并发布到仓库 `latest` Release。
- 上游来源：AdsPower 官方下载页及官方 `version.adspower.net` Linux x64 DEB。
- AUR `adspower-global` 仅用于核对 Linux 依赖、`/opt/AdsPower Global/` 程序布局、desktop / icon 名称和启动入口，不作为程序二进制来源。

## 技术栈

AdsPower Global 为专有桌面应用，Linux 包包含 Chromium / Electron 体系相关运行文件，主程序入口为 `adspower_global`。官方 Linux x64 DEB 将完整应用安装在 `/opt/AdsPower Global/`，同时提供 GTK3、NSS、X11、音频等系统运行依赖。

当前仅构建 x86_64 AppImage。AdsPower 官方下载页标明 Linux 版本面向 Ubuntu Desktop 22.04 或更高版本；本目录只负责在不修改应用授权逻辑的前提下进行便携化重打包与依赖收集。

## 打包方式

- 路线：Arch Linux AnyLinux 构建环境 + quick-sharun。
- 版本：不锁版本。脚本每次从 AdsPower 官方下载页解析当前 Linux x64 稳定版 DEB 地址，并从官方文件名取得实际版本号。
- 程序来源：直接下载 `version.adspower.net` 官方 DEB，不重新编译、不修改应用业务代码。
- 依赖来源：运行依赖名称参考当前 AUR `adspower-global` 配方，在构建容器内通过 Arch 软件包安装；AUR 本身不提供本项目的应用二进制。针对已反馈的 Fcitx5 中文输入缺失，单独补装 `fcitx5-gtk`。
- 程序布局：解包官方 DEB 后将完整 `/opt/AdsPower Global/` 复制到 `AppDir/bin/`，由 quick-sharun 将真实 ELF 部署到 `shared/bin/` 并在 `bin/` 生成对应入口；`icudtl.dat`、PAK、快照、`locales/`、`resources/` 与随包运行库保留在 `bin/`，匹配 Chromium / Electron 通过 `/proc/self/exe` 定位资源的行为。
- desktop / 图标：从官方 DEB 提取 `adspower_global.desktop` 和 hicolor 官方 PNG 图标，只把 `Exec` / `Icon` 调整为 AppImage 内入口，并写入动态版本元数据。
- 依赖部署：将 `AppDir/bin/*` 交给 quick-sharun，覆盖主程序、`chrome-sandbox`、`chrome_crashpad_handler` 与随包运行库；设置 `STRACE_BINARY=adspower_global`、`STRACE_FLAGS='--no-sandbox'`，仅在构建容器中探测主程序动态依赖，不改变最终入口的 sandbox 参数。
- Chromium / Electron runtime：保留 `URUNTIME_PRELOAD=1`，让 uruntime 在程序多进程运行期间持续保留 AppImage 挂载点；该设置不能替代正确的 ICU 和应用资源布局。
- 中文输入法：安装 `fcitx5-gtk` 后继续沿用 quick-sharun 已启用的 GTK3 部署逻辑，由其自动收集 `im-fcitx5.so`、客户端运行库及输入模块缓存；不启动输入法守护进程，也不覆盖宿主输入法配置。
- 中文环境：依赖部署完成后向 `AppDir/.env` 写入 `LANGUAGE=zh-CN`，让 AppImage 运行时优先使用简体中文 locale，不修改宿主机全局 locale。
- workflow：通过 `.github/workflows/build.yml` 的独立 `build_adspower_global` Job 构建，沿用仓库统一 AnyLinux 构建与 `latest` Release 发布流程。

## 运行与兼容说明

- 仅支持 x86_64。
- 默认保持 AdsPower 官方程序和授权机制，不破解、不绕过订阅、许可证、账号或其他访问控制。
- 不修改宿主系统的内核参数、浏览器 sandbox 策略或其他全局配置。
- 当前 ICU 与应用资源部署已由最新 AppImage 实机启动确认可进入登录页；登录行为与输入法支持分别处理。
- Fcitx5 中文输入通过包内 GTK3 前端连接宿主已经运行的 Fcitx5 会话；本 AppImage 不启动输入法守护进程，也不覆盖输入法环境变量。
- AppImage 内设置 `LANGUAGE=zh-CN` 作为简体中文运行环境偏好；AdsPower 页面自身若另有语言设置，仍以其实际行为为准。
- AdsPower 为专有软件，使用、账号、订阅及其他权利义务仍受 AdsPower 官方许可协议与服务条款约束。

### 直接运行

在 Linux 终端中进入 AppImage 所在目录后执行：

```bash
# 启动 AdsPower Global。
./adspower-global.AppImage
```

## 变更记录

### 2026-09-06：首次接入 AdsPower Global AppImage 构建

- 目标：新增 AdsPower Global Linux x64 AppImage 构建，不改变官方程序功能和授权状态。
- 上游：使用 AdsPower 官方下载页动态解析当前 Linux x64 DEB；AUR `adspower-global` 仅作为依赖和文件布局参考。
- 修改文件：`adspower-global/build_adspower-global.sh`、`adspower-global/README.md`、`.github/workflows/build.yml`。
- 实现：保留官方 `/opt/AdsPower Global/` 应用目录和官方资源，通过 quick-sharun 收集主程序运行依赖，并接入仓库统一 AnyLinux Job / latest Release 流程。
- 已知结果：本条记录的是首次构建接入；GitHub Actions 构建结果和最终 AppImage 的真实 Linux 运行结果以后续实际输出为准，不预先视为稳定基准。

### 2026-09-06：补充 Chromium runtime 挂载保持（未解决 ICU 错误）

- 故障现象：首次生成的 AppImage 在 Linux 实机直接启动时立即退出，并输出 `[ERROR:icu_util.cc(223)] Invalid file descriptor to ICU data received.`。
- 当时判断：初次构建未启用挂载保持模式，因此推测错误与挂载生命周期有关；后续构建已启用该模式但仍出现相同错误，不能将此推测视为已确认根因。
- 修改文件：`adspower-global/build_adspower-global.sh`、`adspower-global/README.md`。
- 修复内容：加入 `URUNTIME_PRELOAD=1`，使 uruntime 持续保留 AppImage 挂载点；没有引入 Chromium 项目的语言、输入法、namespace 或其他与当前故障无关的兼容逻辑。
- 已知结果：commit `73b7922ea0f584e741f5c768749a87ab5ef16766` 对应的构建日志已显示 `Setting runtime to keep mount point...`，但产物仍报告相同 ICU 错误；实际资源路径问题见下一条记录。

### 2026-09-06：修正 sharun 入口与 ICU / Electron 资源错位

- 故障现象：启用 `URUNTIME_PRELOAD=1` 后，AppImage 直接启动仍输出 `Invalid file descriptor to ICU data received.` 并退出。
- 根因：已有产物的入口为 `bin/adspower_global`，但 `icudtl.dat`、PAK、快照、`locales/` 与 `resources/` 只在 `shared/bin/`。sharun 通过用户态加载器运行主程序，Chromium 从 `/proc/self/exe` 取得的是 `bin/` 入口路径，因而无法打开该目录下缺失的 ICU 数据；产物 `.env` 的随包库搜索路径也指向 `bin/`。
- 修改文件：`adspower-global/build_adspower-global.sh`、`adspower-global/README.md`。
- 修复内容：参照仓库 Chromium 与 PkgForge Chrome-AppImage，将完整应用先复制到 `AppDir/bin/`，再以 `AppDir/bin/*` 部署主程序、辅助程序与随包运行库；补充上游 ICU 文件的构建输入检查，并明确主程序动态依赖探测目标。保留 `URUNTIME_PRELOAD=1`，不增加运行时 sandbox 参数或宿主系统修改。
- 已知结果：已核对既有构建日志、AppImage 文件布局及 sharun / Chromium 源码，并完成 Bash、ShellCheck 和完整 diff 静态检查。本次仅提交修复，Actions 由用户手动运行；尚未确认新产物的实机启动结果。

### 2026-09-06：补齐 Fcitx5 中文输入与简体中文运行环境

- 故障现象：最新 AppImage 已能进入 AdsPower 登录页，但界面仍为英文，输入框无法使用 Fcitx5 输入中文。
- 根因：现有构建没有安装 `fcitx5-gtk`，本次成功构建日志中的 GTK3 输入模块列表也没有 `im-fcitx5.so`；同时 AppImage 没有设置简体中文 locale 偏好，因此不会主动使用中文运行环境。
- 修改文件：`adspower-global/build_adspower-global.sh`、`adspower-global/README.md`。
- 修复内容：在既有运行依赖命令之外单独安装 `fcitx5-gtk`，由当前已经工作的 quick-sharun GTK3 部署逻辑自动收集 Fcitx5 输入模块及其依赖；依赖部署后向 `AppDir/.env` 写入 `LANGUAGE=zh-CN`。现有 ICU、`locales/`、`resources/`、`URUNTIME_PRELOAD=1`、sandbox 和启动入口均保持不变。
- 已知结果：本次只补当前已定位的 Fcitx5 与中文 locale 缺项，没有额外加入 IBus、强制 `GTK_IM_MODULE` 或新的 GTK 部署开关；最终中文界面和中文输入效果以后续正式构建与 Linux 实机反馈为准。
