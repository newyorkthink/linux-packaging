# JRiver AnyLinux + RunImage 修复记录

本文件保留 RunImage + quick-sharun 路线第 1～10 节的完整构建与运行历史。历史段落中的 `build_jriver.sh` 和“当前”表示**当时**的入口及状态。2026-09-23 起脚本改名为 `build_jriver_anylinux_runimage.sh`，不再由 Build JRiver Job 调用；当前入口见 [README.md](./README.md)，旧路线历史见 [REPAIR_HISTORY_ANYLINUX_SHARUN.md](./REPAIR_HISTORY_ANYLINUX_SHARUN.md)。

2026-09-18 该路线曾确认终端 GUI、简体中文和文件选择器；Rofi run 无窗口的完整实机证据和停手边界在第 10 节。切换 CI 入口不等于该问题已解决，也不授权修改 `rofi/` 或重复既有失败的包装实验。

---

## 历史导言（2026-09-18 原文）

以下保留迁移前的状态说明；其中“当前 CI”和旧文件名仅指当时。

# JRiver RunImage + quick-sharun 路线

本文件专门记录 `jriver/build_jriver.sh` 的 RunImage + quick-sharun 新路线、GitHub Actions 失败证据与对应修复。本目录文件清单、当前用法和旧入口对照见 [README.md 目录说明](./REPAIR_HISTORY_ANYLINUX_SHARUN.md)。

> 旧版稳定路线、实机验证历史、CEF、网页音频、Fcitx5、glibc 和路径兼容链记录继续保留在 [README.md](./REPAIR_HISTORY_ANYLINUX_SHARUN.md)，不在本文件重复展开。

> **当前状态：** 2026-09-18 已确认 `mediacenter36.AppImage` 从终端启动时 JRiver Media Center 36 GUI 和简体中文界面正常。通过仓库 `rofi.AppImage` 启动没有 JRiver 窗口。Rofi 本身和其他 AppImage 经同一 Rofi 启动均正常，**不改 `rofi/`**。Rofi 无 GUI 已按第 10 节停止继续改 JRiver 包装。Fcitx5 实际中文输入、网页音频和影院模式鼠标操作仍未验证。详细记录见第 6～10 节。

---

## 1. 2026-09-13：保留旧入口，改用标准 RunImage + quick-sharun

### 用途、来源与技术栈

- 用途：打包 JRiver Media Center 音视频播放器与媒体管理器，发布资产为 `mediacenter36.AppImage`。
- 来源：RunImage 使用上游 continuous 运行时；JRiver 由当前 AUR `jriver-media-center` 配方下载官方 Linux DEB，并按配方校验。
- 技术栈：x86_64 原生 C/C++、GTK3、JRWeb/CEF、WebKitGTK 和音频插件，运行于包内 Arch Linux 根文件系统。
- 版本：从安装后的包信息读取版本，从包文件清单识别主程序，不写死 JRiver 主版本。

### 当前打包流程

1. 在 GitHub Actions 的 Arch 容器中下载 RunImage，在本次专用构建目录工作。
2. 使用公共 Action 已创建的普通用户 `builduser` 运行 RunImage；在内部更新系统、安装 AUR 工具和 JRiver。这样满足 `makepkg` 不以 root 构建的要求，不改变最终应用的启动方式。
3. 以应用级安装命令补齐官方 DEB 声明的运行依赖，并保留 Pulse/ALSA 与 GTK 中文输入支持；不强制设置输入法环境变量。
4. 在包内生成中文 locale；只运行 `rim-shrink --pkgcache`，保留翻译、原始二进制与资源。上游 `rim-shrink --all` 会裁剪中文翻译，因此不用于新入口。
5. 写入标准 `Run.rcfg`，`RIM_AUTORUN` 直接指向已安装的 JRiver 主程序；沿用 RunImage 的字体、图标、主题共享和宿主 `xdg-open` 支持。
6. 使用 `rim-build -s` 生成临时 RunImage，解出完整 `RunDir`，改为 `AppDir`，将原生 `Run` 入口改名为 `AppRun`。
7. 从官方包提取 desktop 和 Logo，只调整外层 desktop 的入口与图标名称；quick-sharun 仅执行最终 `--make-appimage` 封装，不再逐库重组 JRiver。

### 文件与工作流

- 新入口：`jriver/build_jriver.sh`。
- 旧入口：`jriver/build_jriver_legacy_20260913.sh`，与改名前逐字节一致；旧版 CEF、音频和路径补丁原样保留其中。
- `jriver_cef_runtime.sh` 保持原样，新入口不调用它，也不调用旧版构建脚本。
- `.github/workflows/build.yml` 继续使用独立 `Build JRiver` Job、原脚本选择项、`jriver/dist` 和固定 Release 资产名；仅为该 Job 配置与 virt-manager 相同的 privileged 容器和 `/dev/fuse`。
- `runimage/jriver-media-center/`、其独立 workflow 和其他应用保持原样。此次 push 按现有目录选择逻辑只选择 JRiver AppImage 构建。

### 变更原因与已知结果

- 原因：按明确要求重新建立标准 RunImage 打包入口，避免继续把旧版路径映射、CEF preload 和音频兼容补丁叠加到新路线。
- 原因边界：历史无 GUI、文件选择器和影院模式问题的根因没有因此确定；不认定为 Rofi 问题，不添加针对启动菜单、独立 D-Bus 会话或文件选择器的特殊处理。
- 核对依据：仓库现有 virt-manager 流程、RunImage 的 `rim-build` / `rim-shrink` / 自动启动实现、当前 quick-sharun 的封装入口、AUR 配方和与其 SHA-256 一致的官方 DEB 文件布局。
- 已完成：Shell 与 YAML 静态核对、入口与资源路径检查、旧脚本字节一致性检查；无新增测试代码或测试 workflow。
- 尚未确认：新 AppImage 的构建、GUI、文件选择器、影院模式、网页音频和中文输入。官方 DEB 本身未包含 `libcef.so`，新入口不注入旧版私有 CEF；JRWeb/CEF 功能需以新产物实际运行结果为准。
- 提交后按仓库规则不监控 Actions，不把提交完成描述为功能修复完成。

### 运行要求

最终仍通过包内 RunImage 运行，需要宿主支持 RunImage 所需的用户命名空间及设备访问；AppImage 封装不会消除内部容器的运行要求。构建期的 privileged 权限仅用于 CI，不要求用户以 root 启动播放器。应用按上游行为使用当前用户的媒体库、配置和缓存。

在 Linux 终端进入下载文件所在目录后执行：

```bash
# 为下载的 JRiver AppImage 添加执行权限
chmod +x ./mediacenter36.AppImage

# 启动 JRiver Media Center
./mediacenter36.AppImage
```

---

## 2. 2026-09-13：修复 CI 中 builduser 无法进入 RunImage

### 已有失败证据

首次正式构建对应：

```text
Run: 34756394307
Job: Build JRiver
Result: failure
```

日志显示上游 RunImage 已下载并完成 SHA-256 输出，但在执行安装脚本前依次出现：

```text
Failed to create user and mount namespaces: Operation not permitted
runimage: failed to utilize FUSE during startup
The kernel does not support user namespaces!
```

因此本次失败发生在 `builduser` 进入 RunImage 的阶段，尚未执行 `rim-update`、JRiver 安装或最终 quick-sharun 封装；与 JRiver 本体、CEF、音频、中文输入及影院模式无关。

### 根因与修复

- 根因：统一 workflow 的 JRiver Job 虽使用 privileged 容器和 `/dev/fuse`，但容器内的普通用户仍不能创建 RunImage 所需的 user namespace；直接以 `builduser` 启动会被上游运行时拒绝。
- 修改文件：`jriver/build_jriver.sh`、`jriver/README.md`、根 `README.md`。
- 修复方式：下载 RunImage 后先用其 `--runtime-extract` 入口取出上游自带的 `static/bwrap`，以 root 所有者和 `4755` 权限安装到临时 CI 容器的 `/usr/bin/bwrap`，再继续执行原有的 `sudo -H -u builduser ... ./runimage`。
- 作用边界：SUID Bubblewrap 只存在于一次性构建容器，不复制进 `AppDir`，不改变最终 AppImage 的运行权限，也不修改用户系统；旧入口、workflow、CEF、音频和路径兼容代码均保持不变。
- 该处理采用上游 RunImage 在 user namespace 不可用时给出的正式恢复路径，同时继续满足 AUR `makepkg` 不以 root 构建的要求。

### 当前验证状态

已根据运行日志、上游 RunImage 的 `RUNDIR/static/bwrap` 布局及现有脚本完成静态核对；未新增测试代码或测试 workflow。修复提交后的 Actions 构建、GUI、文件选择器、影院模式、网页音频和中文输入均尚未验证。

---

## 3. 2026-09-13：补齐非 root FUSE / UnionFS 挂载条件

### 第二次失败证据

SUID Bubblewrap 修复后的正式构建对应：

```text
Run: 34756871436
Job: Build JRiver
Result: failure
```

日志先确认：

```text
The system Bubblewrap is used!
Bubblewrap has SUID sticky bit!
```

随后仍出现：

```text
SUID fusermount not found in PATH, trying to unshare...
fuse: mount failed: Permission denied
Failed to mount RunImage in UnionFS overlay mode!
```

这证明第 2 节的 SUID Bubblewrap 已按预期生效，但只能解决 Bubblewrap 进入容器的问题；RunImage 外层 FUSE 和内部 UnionFS 仍缺少普通用户挂载所需的 SUID `fusermount`。本次仍未进入 `rim-update` 或 JRiver 安装阶段。

### 根因与修复

- 根因：JRiver Job 的 Arch 临时容器已透传 `/dev/fuse`，但没有安装提供 `/usr/bin/fusermount` 的 `fuse2`；上游 uruntime 在找不到 SUID `fusermount` 后尝试 user namespace，而该容器又禁止非特权 user namespace，最终导致两层 FUSE 挂载均失败。
- 修改文件：`jriver/build_jriver.sh`、`jriver/README.md`、根 `README.md`。
- 修复方式：在启动 RunImage 前通过 Arch 官方仓库安装 `fuse2`，检查 `/usr/bin/fusermount` 存在并确保其 SUID 位；随后继续沿用第 2 节已生效的 SUID Bubblewrap 和原有 `builduser` 构建命令。
- 作用边界：`fuse2`、SUID `fusermount` 与 SUID Bubblewrap 只存在于一次性 CI 容器，均不会复制进最终 `AppDir`，不会改变用户系统或最终 AppImage 的权限。
- 不改 workflow、不使用 root 运行 AUR `makepkg`，旧入口以及 CEF、音频、Fcitx5、glibc 和路径兼容链保持不变。

### 当前验证状态

已根据 Run 34756871436 完整日志、上游 uruntime 的 SUID `fusermount` 检查逻辑和 RunImage 的 UnionFS 挂载实现完成静态核对；Shell 语法检查通过，未新增测试代码或测试 workflow。修复提交后的 Actions 构建与全部实机功能仍待验证。

---

## 4. 2026-09-13：解除 CI runner 的 AppArmor userns 限制

### 第三次失败证据

补齐 SUID Bubblewrap 与 `fusermount` 后的正式构建对应：

```text
Run: 34757282264
Job: Build JRiver
Result: failure
```

日志已完成 `fuse2` 安装和 RunImage 运行时提取，随后在执行 `rim-update` 前出现：

```text
apparmor_restrict_unprivileged_userns is enabled!
You need to disable apparmor_restrict_unprivileged_userns
```

这证明第 2～3 节的 Bubblewrap 与 FUSE 准备已经越过此前失败点；本次仍未进入 JRiver 安装或 quick-sharun 封装阶段。

### 根因与修复

- 根因：GitHub-hosted runner 启用了 AppArmor 对非特权 user namespace 的限制；上游 RunImage 在非 root 启动时会直接读取 `/proc/sys/kernel/apparmor_restrict_unprivileged_userns`，值为 `1` 时主动退出。即使已安装 SUID Bubblewrap，该检查仍发生在选择 Bubblewrap 之前。
- 修改文件：`jriver/build_jriver.sh`、本文件、`jriver/README.md` 与根 `README.md`。
- 修复方式：启动 RunImage 前，仅在该 proc sysctl 存在且值为 `1` 时写入 `0`。这与上游 RunImage 自身 CI 的处理一致。
- 作用边界：只调整一次性 privileged CI runner 的当前内核参数，不创建 `/etc/sysctl.d` 持久化配置，不写入 `AppDir`，也不改变最终 AppImage 或用户系统。
- 继续由普通用户 `builduser` 运行 RunImage 和 AUR `makepkg`；旧入口、workflow、CEF、音频、Fcitx5、glibc 与路径兼容链保持不变。

### 当前验证状态

已按 Run 34757282264 完整日志和上游 RunImage 的启动检查顺序完成静态核对；Shell 语法检查通过，未新增测试代码或测试 workflow。修复提交后的 Actions 构建与全部实机功能仍待验证。

---

## 5. 2026-09-13：禁用成品 NVIDIA 驱动处理并补齐中文环境

### 最新运行证据

最新 `jriver.AppImage` 已能够进入 RunImage 自动启动流程并识别 `mediacenter36`，但在启动 JRiver 前扫描到宿主 NVIDIA 550.163.01 缺少 32 位库，随后尝试从多个源下载同版本驱动镜像：

```text
Nvidia 32-bit libraries are not found in your system!
Downloading Nvidia 550.163.01 driver, please wait...
550.163.01.nv.drv not found
```

这不是 JRiver 自身的驱动下载要求。新入口此前在成品 `Run.rcfg` 中启用了 `RIM_SYS_NVLIBS=1`；构建命令使用的 `RIM_NO_NVIDIA_CHECK=1` 只作用于构建阶段，没有写入最终运行配置。

### 根因与修改

- 删除成品配置中的 `RIM_SYS_NVLIBS=1`，改为持久化 `RIM_NO_NVIDIA_CHECK=1`，与仓库 `runimage/setup_general_env.sh` 的既有通用策略一致。
- 该设置禁用 RunImage 的 NVIDIA 版本检测、匹配、驱动镜像生成和下载流程；不添加 32 位 NVIDIA 依赖，也不修改宿主驱动。
- 保留现有 `fcitx5-gtk`、`zh_CN.UTF-8` locale 生成及宿主字体、图标和主题共享，并按通用基线写入包内 `/etc/locale.conf`。
- 包内 `/etc/locale.conf` 设置 `LANG`、`LC_ALL` 与 `LANGUAGE`；成品 `Run.rcfg` 导出 `LANG`、`LANGUAGE`、`GTK_IM_MODULE`、`QT_IM_MODULE`、`XMODIFIERS` 与 `SDL_IM_MODULE`，使默认中文环境和 Fcitx5 输入法设置随 JRiver 启动。
- 上游 RunImage 使用 `set -a` 加载内部 `Run.rcfg`，这些变量会导出给自动启动的 JRiver。
- 旧版构建入口、workflow、CEF、音频、glibc 与路径兼容链均不修改。

### 当前验证状态

用户提供的最新 Kali Linux 实机结果确认：

- 成品已停止检测、生成和下载 NVIDIA 驱动镜像；
- JRiver Media Center 36 GUI 可以正常启动；
- 简体中文界面正常显示；
- 文件选择器可以打开，并能浏览宿主主目录及常用目录。

截图没有展示 Fcitx5 实际中文输入、网页音频和影院模式鼠标操作，因此这三项不写成已验证。

---

## 6. 2026-09-13：启用安静模式并确定本轮最终版本

### 修改内容

- 在成品 `Run.rcfg` 中加入 `RIM_QUIET_MODE=1`，与仓库 `runimage/setup_general_env.sh` 的通用配置一致。
- 上游 RunImage 明确将该变量定义为“禁用全部非错误消息”；启动时的内部配置、自动入口、宿主共享、HOSTEXEC 和 NVIDIA 已禁用等 `INFO/WARNING` 不再输出。
- RunImage 的 `ERROR` 不受影响，发生真实启动错误时仍会显示。
- 不修改 JRiver、workflow、旧版构建入口、CEF、音频、Fcitx5、glibc 或路径兼容链。

### 本轮最终状态

```text
构建与发布：正常
NVIDIA 自动处理：已禁用
RunImage 普通启动信息：已隐藏
JRiver GUI：正常
简体中文界面：正常
文件选择器：正常打开
Fcitx5 实际中文输入：尚未取得截图验证
网页音频：尚未验证
影院模式鼠标操作：尚未验证
```

本节作为 2026-09-13 RunImage + quick-sharun 路线的本轮最终记录；后续只有出现新的实机证据或用户可见问题时再继续修改。

---

## 7. 2026-09-14：Rofi 启动无 GUI（未解决）

### 实机现象与定位证据

- 同一个 `jriver.AppImage` 从正常终端启动时可以显示 GUI；通过仓库当前 `rofi.AppImage` 启动时没有显示 JRiver GUI，窗口切换列表中也没有 JRiver 窗口。其他 AppImage 通过同一 Rofi 启动正常。
- 最新实机进程证据显示，Rofi 启动后并非只有一个孤立进程：外层 `mediacenter36`、DwarFS 挂载、`static/ssrv` 和包内 `/bin/mediacenter36` 均存在，完整 RunImage 运行链已经建立。因此不能再把问题描述成“RunImage 没有启动”或“父进程退出导致完整进程链消失”。
- 现有截图只能确认进程存在而窗口没有出现，不能确认窗口创建、映射、焦点、显示连接、JRiver 单实例状态或内部 GUI 初始化具体在哪一步失败；当前根因不确定。

### 已失败的修改

- 首次尝试在外层增加 `AppRun` 包装脚本并清理 Rofi / Sharun 继承的运行库、插件和缓存环境。实际 Release 产物中，quick-sharun 将该包装脚本保留为最终 `Run` 并建立 `AppRun -> Run`，包装脚本再执行自身形成递归，导致终端直接启动也无法进入 GUI。该入口改动已经从当前构建脚本移除。
- 第二次恢复原生入口，并改为在 `Run.rcfg` 中清理 `SHARUN_DIR`、`CROSS_LIBC_DLOPEN_ROOT`、GIO / GTK、图形驱动、数据目录和缓存变量。新实机结果仍是完整进程链存在但没有 GUI，说明该环境清理没有解决问题；该清理也已经从当前构建脚本移除。
- 上述结果否定了此前把父级 Sharun 环境写成已定位根因的判断。没有新的直接证据前，不应再次尝试同一环境清理方向，也不应把 GVFS、独立 D-Bus 会话、`LD_PRELOAD`、TTY / 后台等待或某个单一 launcher 变量写成确定根因。

### 当前处理状态

- 第 7 节当时的结论仍然成立：外层 AppRun 包装和外层 Sharun 环境清理都失败并已撤回。
- 2026-09-18 又取得了显示连接、Pango 线程、stdio 和 PATH 的直接证据，但仍没有窗口。完整结论与停手原因见第 10 节。
- **不要改 `rofi/`。** Rofi AppImage 正常，其他应用经同一 Rofi 启动也正常。


---

## 8. 2026-09-17：Release 资产改名为 mediacenter36.AppImage

### 现象

`latest` Release 没有 `jriver.AppImage`。同日可见的是 RunImage 路线发布的无后缀资产 `mediacenter36`；AppImage 路线此前固定资产名 `jriver.AppImage`，且 2026-09-14 之后未再因目录变更单独构建，因此 latest 上找不到该 AppImage。

### 修改

- 按当前官方主程序名，将 AppImage 发布资产改为 `mediacenter36.AppImage`。
- 修改文件：`jriver/build_jriver.sh`、`.github/workflows/build.yml`、本文件、`jriver/README.md`。
- 只改外层产物文件名与 zsync 更新信息；不改包内 `RIM_AUTORUN`、CEF、音频、Fcitx5、glibc 隔离或启动链。
- 与 RunImage 无后缀资产 `mediacenter36` 并存，文件名不同。
- 未处理 Rofi 无 GUI；该问题仍按第 7 节搁置。

在 Linux 终端进入下载文件所在目录后执行：

```bash
chmod +x ./mediacenter36.AppImage
./mediacenter36.AppImage
```

---

## 9. 2026-09-18：mediacenter36.AppImage 终端 GUI 已确认；Fontconfig 警告不影响界面

### 检查对象与证据

- 产物：`latest` Release 的 `mediacenter36.AppImage`。
- 证据：终端直接启动截图，以及 JRiver Media Center 36 主窗口截图。
- 未做代码修改。

### 已确认

- `./mediacenter36.AppImage` 从终端启动后出现主窗口。
- 菜单、侧栏和搜索框为简体中文。
- 播放列表页部分帮助正文仍为英文，属于上游界面字符串，不是启动失败。

### Fontconfig 警告

终端大量输出：

```text
Fontconfig warning: ".../48-guessfamily.conf", invalid attribute 'xsi:nil'
Fontconfig warning: ".../48-guessfamily.conf", invalid constant used
Fontconfig warning: ".../49-sansserif.conf", invalid constant used
Fontconfig warning: ".../48-spacing.conf", invalid constant used : monospace
```

路径同时出现包内 `/etc/fonts/conf.d` 与宿主 `/usr/share/fontconfig/conf.avail`。成品 `Run.rcfg` 启用了 `RIM_SHARE_FONTS=1`，容器内较旧的 Fontconfig 会读到宿主较新的配置（含 `xsi:nil` 和新增 generic family）。警告出现在 GUI 之前，界面仍正常画出。

当前不关闭宿主字体共享，也不改 Fontconfig 路径：中文界面可能仍依赖宿主字体；没有证据表明这些警告造成缺字或崩溃。没有新的缺字/崩溃证据前，不把该警告当成启动故障处理。

### 仍未验证

- Rofi 启动无 GUI（第 7、10 节；已停止改包装）
- Fcitx5 实际中文输入
- 网页音频
- 影院模式鼠标操作

---

## 10. 2026-09-18：Rofi 启动无 GUI —— 为什么改不了、改什么都没用

这一节把「Rofi 这条路为什么不再改包装」写死。后面不要再根据感觉动 `jriver/build_jriver.sh`，也不要去动 `rofi/`。

### 10.1 一句话结论

| 问题 | 答案 |
|---|---|
| `mediacenter36.AppImage` 能不能用？ | **能。** 终端直接启动有 GUI、简体中文界面、文件选择器。这是当前正式用法。 |
| 通过仓库 `rofi.AppImage` 的 run 启动同一个包，有没有窗口？ | **没有。** 进程链在，窗口不在。 |
| 是不是 Rofi 坏了？ | **不是。** 同一套 Rofi 启动其他 AppImage 正常。**禁止改 `rofi/`。** |
| 继续改 JRiver 包装能不能把 Rofi 这条路修好？ | **不能。** 已经用实机把包装层能碰到的原因全部排除；剩下的是 GTK/Pango 在无 TTY、经 ssrv 拉起时卡在 `futex_wait`，包装脚本碰不到这把锁。 |
| 改不了的到底是什么？ | **改不了的是：让这个 AppImage 在 Rofi run 下稳定弹出主窗口。** 不是改不了终端启动，也不是 Rofi 启动器本身坏了。 |

Fcitx5 实际中文输入、网页音频、影院模式鼠标操作仍未验证，与 Rofi 无窗是不同事项，不要混在一起当同一个 bug 修。

### 10.2 两条启动路径实际差在哪

终端路径（已确认有 GUI）：

```text
shell (有 TTY)
  → 外层 AppImage / AppRun
  → DwarFS 挂载
  → ssrv / bwrap 进 RunImage 根
  → RIM_AUTORUN = 包内 jriver-launch
  → exec mediacenter36
  → GTK 主循环创建并映射窗口
```

Rofi 路径（进程起来，窗口没有）：

```text
rofi.AppImage (自己也是 AppImage，PATH 里带着 /tmp/.mount_rofi…/bin)
  → exec 指向 mediacenter36.AppImage 的符号链接
  → 外层 AppImage / AppRun     ← 这一层已经起来
  → DwarFS                     ← 已经起来
  → static/ssrv                ← 已经起来
  → 包内 /usr/bin/mediacenter36 或 jriver-launch → mediacenter36  ← 已经起来
  → 主线程 + 两个 [pango] fontcon 停在 futex_wait
  → 没有 X11 窗口，xwininfo / xlsclients 找不到 JRiver
```

差别不在「包没启动」。差别在 **拉起方式**：Rofi 这条路没有 TTY，stdin/out/err 最初是 pipe（ssrv `--env all`），父进程环境来自另一个 AppImage（Rofi，有时还有当时挂着的 i3 AppImage）。JRiver 主程序进到 GTK/Pango 初始化之后不再往前走，窗口创建/映射这一步没有发生。

### 10.3 卡住时进程实际在干什么（实机）

多次 `jriver-rofi3.txt`～`jriver-rofi10.txt` 看到的同一张快照：

- 外层 `mediacenter36`、DwarFS、`ssrv`、内层 `mediacenter36` 都在。
- 内层 `DISPLAY=:0`，对应 fd 是已经 `ESTAB` 的 Unix 套接字 `@/tmp/.X11-unix/X0`。
- `xwininfo` / `xlsclients` 仍然找不到 JRiver 窗口。所以不是「没连上显示」，是 **连上了但不创建/不映射窗口**。
- 内层线程反复是：

```text
mediacenter36     futex_wait
[pango] fontcon   futex_wait
[pango] fontcon   futex_wait
```

Pango 的 fontconfig 工作线程在等一把用户态锁，主线程也在等。没有人拿到这把锁往下走，GUI 主循环到不了「创建 toplevel / map window」。这不是包装入口没执行，是 **已经 exec 进去的 GTK/Pango 初始化卡住**。

### 10.4 已经用实机直接排除的原因（不要再当根因去改）

下面每一条都有进程、环境或日志证据。再改同一方向就是重复已经失败的实验。

**1. RunImage 没启动 / 父进程退出导致进程链消失。**

Rofi 点下去之后外层 `mediacenter36`、DwarFS、`ssrv`、包内 `mediacenter36` 都在。第 7 节已经写过。问题不是「没起来」，是「起来了没有窗」。

**2. 没有连上 X11 / DISPLAY 丢了。**

内层 `DISPLAY=:0`，fd 连的是 `@/tmp/.X11-unix/X0`，状态 ESTAB。显示连接在。缺的是窗口，不是 socket。

**3. Rofi 传入了控制台会话（`TERM=linux` / `XDG_SESSION_TYPE=tty`），GTK 因此不画窗口。**

曾经是合理怀疑：Rofi 从 tty 风格环境拉起子进程，GTK 可能认为没有图形会话。已经在 `Run.rcfg` 和包内 `jriver-launch` 里覆盖为：

```text
TERM=xterm-256color
XDG_SESSION_TYPE=x11
```

卡住进程的环境转储证明这两项已经生效，仍然无窗。所以「会话类型写错」不是根因。

**4. ssrv 把 stdin/out/err 接到 pipe，Fontconfig 警告把 pipe 写满，进程卡在 write。**

曾经是合理怀疑：ssrv 默认把子进程标准流接到管道；Fontconfig 对 `48-guessfamily.conf` 的 `xsi:nil` 狂打 warning，管道缓冲区写满后整个进程阻塞，看起来像挂死。已经在包内 `jriver-launch` 把：

```text
fd 0 → /dev/null
fd 1 → $XDG_CACHE_HOME/jriver-launch.log（实际落到 ~/.cache/AppImage-Cache/jriver-launch.log）
fd 2 → 同上
```

`/proc/<pid>/fd/0-2` 核对过，重定向生效。线程快照仍是主线程 + 两个 `[pango] fontcon` 停在 `futex_wait`，不是停在 `write`/`pipe_wait`。stdio/pipe 不是卡死原因。

**5. 宿主字体共享或 Fontconfig 缓存损坏，Pango 在扫字体时死锁。**

曾经是合理怀疑：`RIM_SHARE_FONTS=1` 让容器内较旧的 Fontconfig 读到宿主较新的 `48-guessfamily.conf`（含 `xsi:nil`），再叠加 `~/.cache` 里的 Fontconfig 缓存，可能让 Pango 工作线程互相等。已经做过两轮：

- 关掉 `RIM_SHARE_FONTS`，打进 `noto-fonts-cjk`。仍然卡在同样的 Pango 线程。包体积约 450MB → 641MB。字体共享已回退。
- 清掉 Fontconfig 缓存后再从 Rofi 启动，仍然同样卡住。

终端同款 Fontconfig 警告并不阻止 GUI。所以「宿主字体 / 缓存」不是 Rofi 无窗的根因。

**6. Rofi / Sharun 把 `LD_LIBRARY_PATH`、GIO、GTK 模块路径、插件缓存传进 JRiver，库加载错乱。**

曾经是合理怀疑，也是第 7 节两次包装实验的出发点。卡住进程的环境转储里 **没有** 这些变量。两次包装层修改都已经失败并撤回：

- 外层再包一层 `AppRun` 清理环境：quick-sharun 把包装脚本留成最终 `Run` 并建 `AppRun -> Run`，脚本再 exec 自己，自递归。连终端 GUI 都没了。已从构建脚本删除。
- 恢复原生入口，改在 `Run.rcfg` 里清 `SHARUN_DIR`、`CROSS_LIBC_DLOPEN_ROOT`、GIO/GTK、图形驱动、数据目录和缓存。新包仍然是完整进程链、没有窗口。清理已从构建脚本删除。

父级 Sharun 环境不是已定位根因。没有新证据不许再做同一类大清扫。

### 10.5 看到过、但还不能当根因去改的现象

这些出现在日志或环境里，**只能当线索，不能当补丁理由**：

- 卡住进程的 `PATH` 里出现过其他 AppImage 的挂载目录：`/tmp/.mount_rofi…/bin`、`/tmp/.mount_i3…/bin`。这只说明 Rofi（以及当时挂着的 i3 AppImage）会把自身 `bin` 泄漏进子进程 PATH。不能单独证明这就是 Pango 死锁原因。后来在包内 `jriver-launch` 里丢掉 `/tmp/.mount_*`，**没有拿到「Rofi 已出窗」的实机确认**。不要再为 PATH 泄漏加新的包装逻辑。
- 日志里出现过 Chromium `observer_list.h` 断言和 `JRWebWnd::GetProcessRunning: waitpid error`。时间戳对应更早一次启动，不能证明当前这次 Pango 卡住就是 JRWeb 崩了。旧路线的 CEF 补丁 **没有因此重新打进新入口**，也不许为了 Rofi 无窗去打。

### 10.6 为什么包装层改不了这件事

包装能改的是：入口脚本、环境变量、stdio 接到哪、PATH、字体是否共享、locale、NVIDIA 检查、安静模式。这些已经逐项试过或排除。

包装改不了的是：

1. **已经 exec 进去的 `mediacenter36` 主进程内部的 Pango/fontconfig 线程同步。** `futex_wait` 发生在进程内部。外层 AppRun、`Run.rcfg`、`jriver-launch` 在 `exec` 之后不再有控制权。再套一层脚本，只是把同一个二进制用另一种环境再拉一次，锁还是那把锁。
2. **GTK 是否创建并 map 窗口。** 显示 socket 已经连上。窗口没出现，是 GTK 主循环没走到那一步，或走到了但被 Pango 初始化堵住。这不是「少 export 一个变量」能推过去的，除非有 strace/锁栈证明它在等某一个具体的环境或文件。
3. **ssrv / bwrap / DwarFS 这条 RunImage 运行时。** 进程链证明它已经工作。终端同包能出窗，说明运行时本身不是「永远无 GUI」。Rofi 路径上它也能把内层进程拉起来。继续改 RunImage 运行时等于改仓库里所有 RunImage 应用，没有证据支持这么做。
4. **JRiver 单实例、CEF/JRWeb、GVFS、独立 D-Bus、`LD_PRELOAD`。** 用户原先禁止在没有新证据时猜测这些。后来的证据覆盖了显示连接、stdio、字体、会话类型、父级 Sharun 环境，**没有覆盖上述猜测**。所以这些方向仍然不许拿来改包装。
5. **Rofi 启动器。** 见下一小节。问题不在 Rofi 包。

所以「改不了」不是情绪，是范围：在现有证据下，JRiver 包装层已经没有一个还没试过、并且能解释「终端有窗 / Rofi 无窗、双方都连着同一个 X11、双方都卡在同一组 Pango futex」的旋钮。继续拧这些旋钮，只会重复第 7 节和第 10.4 节已经失败的构建。

### 10.7 为什么绝对不能改 `rofi/`

仓库 `rofi/` 是独立应用。用户明确说过：<https://github.com/newyorkthink/linux-packaging/tree/main/rofi> 很正常，为什么要改？

- 同一套 `rofi.AppImage` 启动其他 AppImage 有窗口。
- 只有 JRiver 这个包在 Rofi run 下无窗。
- 为 JRiver 去改 Rofi，会把其他已经正常的 AppImage 启动路径拖下水。
- Rofi 的文档、构建、入口保持原样。**本目录的停手结论不包括、也不允许修改 `rofi/`。**

PATH 里出现 `/tmp/.mount_rofi…/bin` 只能说明「Rofi 作为 AppImage 会把自己的 bin 留给子进程」，这是 AppImage 启动器的常见行为，不是 Rofi 包坏了。JRiver 侧已经试过丢掉这些 PATH 前缀，没有出窗证据。不要回到 Rofi 仓库去「修 PATH」。

### 10.8 做过、已经撤回、禁止再做的包装改动

| 方向 | 结果 | 现在 |
|---|---|---|
| 外层再包 `AppRun` 清理 Sharun/GIO/GTK/缓存 | `AppRun → Run` 自递归，终端 GUI 也没了 | **已删除。禁止再加外层 AppRun 包装。** |
| `Run.rcfg` 大清扫父级 Sharun / GIO / GTK / 驱动 / 缓存变量 | 进程链在，仍然无窗 | **已删除。禁止再做父级 Sharun 环境大清扫。** |
| `RIM_SHARE_FONTS=0` + 打进 `noto-fonts-cjk` | 仍卡同样 Pango 线程，体积 450→641MB | **已回退。禁止再关宿主字体或打整包 CJK 赌一把。** |
| 清 Fontconfig 缓存再从 Rofi 启动 | 仍卡 | 不是构建改动；不要再当修复手段。 |
| `TERM` / `XDG_SESSION_TYPE` 覆盖为 x11 | 覆盖生效，仍无窗 | 覆盖还留在脚本里，但 **不是 Rofi 修复**。 |
| `jriver-launch` 重定向 stdio、丢掉 `/tmp/.mount_*` PATH | 重定向生效，仍无窗 | 定位残留，**没有实机证明能让 Rofi 出窗**。不要再往上叠同类改动。 |
| 把问题写成 GVFS / 独立 D-Bus / `LD_PRELOAD` / TTY 后台等待 | 无新证据 | **禁止当成根因去改。** |
| 改 `rofi/` | 未改，也不允许 | **禁止。** |
| 把旧路线 CEF 补丁打进新入口来赌 Rofi 出窗 | 未做 | **禁止。** 日志里的 JRWeb/CEF 行对不上当前这次 Pango 卡住。 |

NVIDIA 禁用（`RIM_NO_NVIDIA_CHECK`）和安静模式（`RIM_QUIET_MODE`）继续保留：那两项目有终端实机确认，跟 Rofi 无窗无关。

### 10.9 还缺什么才允许再动

没有下面这类 **新的、能区分失败点** 的直接证据，**不再改 `jriver/build_jriver.sh` 去碰 Rofi 启动**：

1. core dump，或 Pango/fontconfig 双方持锁栈（哪两个线程在等哪把 futex，锁的拥有者是谁）。
2. 能对比「终端成功 / Rofi 失败」且能指向 **单一缺失文件或单一 ABI 错误** 的 `strace -f`（例如某个 fontconfig 文件、某个 GTK 模块、某次 `futex` 超时）。
3. 能区分这四件事之一：窗口从未创建、窗口已创建但未映射、Pango 死锁双方身份、JRWeb 子进程在窗口出现前退出。
4. 原生 DEB / 官方 Linux 包经同一 Rofi 启动是否同样无窗。如果官方包也无窗，那就不是本仓库的包装问题。

在那之前，任何「再清一次环境 / 再改一次入口 / 再换一套字体」都是猜测。第 1～13 节旧路线已经为文件选择器 warning 付过同样的代价：没有 crash stack 就不要根据日志字符串改代码。这里适用同一条规则。

### 10.10 当前正式用法

在 Linux 终端进入下载文件所在目录后执行：

```bash
chmod +x ./mediacenter36.AppImage
./mediacenter36.AppImage
```

`latest` 上的 AppImage 资产名跟随包内主程序：现在是 `mediacenter36.AppImage`，主版本升到 37 时变为 `mediacenter37.AppImage`。旧名 `jriver.AppImage` 已从 latest 删除。无后缀的 `mediacenter36` 是另一条 RunImage 路线，不是这个 AppImage。

不要指望从 Rofi run 弹出这个包的主窗口。那条路按本节停止。

### 10.11 构建脚本里还留着什么（避免误读成「已经修了 Rofi」）

当前 `build_jriver.sh` 里仍有包内 `jriver-launch`：重定向 stdio、丢掉 `/tmp/.mount_*` PATH、覆盖 `TERM` / `XDG_SESSION_TYPE`。这些是定位过程留下的，**没有实机证明它们能让 Rofi 出窗**。不是 Rofi 修复，也不要再往上叠同类改动。

还保留的、有实机确认的配置：

- `RIM_NO_NVIDIA_CHECK=1`：成品不再下载 NVIDIA 驱动镜像。
- `RIM_QUIET_MODE=1`：隐藏 RunImage 非错误信息。
- 中文 locale / Fcitx5 环境变量：终端 GUI 简体中文已确认；Fcitx5 实际输入仍未验证。
- `RIM_SHARE_FONTS=1`（以及图标、主题、宿主 `xdg-open`）：关字体那次失败后回退到共享。

旧版稳定路线（CEF preload、网页音频闭包、glibc 隔离、pathmap）仍只在 [README.md](./REPAIR_HISTORY_ANYLINUX_SHARUN.md) 第 1～13 节，不并进本路线，也不为 Rofi 无窗重新启用。

---

## 11. 2026-09-23：保留 RunImage 脚本，停止作为正式 CI 入口

- 原 `build_jriver.sh` 逐字节保留为 `build_jriver_anylinux_runimage.sh`；该路线的第 1～10 节故障、修复与实机结果全部保留。
- 正式 Build JRiver Job 和手动下拉现选择 AnyLinux + quick-sharun 旧入口，两个入口不会在同一次 JRiver Job 中重复构建。独立 `runimage/jriver-media-center/` 的 workflow 未修改。
- 该入口 2026-09-18 的终端 GUI、中文、文件选择器结果只适用于当时产物；Rofi run 无窗仍未解决。此次没有新构建或新实机验证，不恢复已经失败的环境清理、字体或外层 AppRun 包装。
