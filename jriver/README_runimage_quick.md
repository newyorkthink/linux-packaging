# JRiver RunImage + quick-sharun 路线

本文件专门记录 `jriver/build_jriver.sh` 的 RunImage + quick-sharun 新路线、GitHub Actions 失败证据与对应修复。

> 旧版稳定路线、实机验证历史、CEF、网页音频、Fcitx5、glibc 和路径兼容链记录继续保留在 [README.md](./README.md)，不在本文件重复展开。

---

## 1. 2026-09-13：保留旧入口，改用标准 RunImage + quick-sharun

### 用途、来源与技术栈

- 用途：打包 JRiver Media Center 音视频播放器与媒体管理器，发布资产仍为 `jriver.AppImage`。
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
chmod +x ./jriver.AppImage

# 启动 JRiver Media Center
./jriver.AppImage
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

已核对 `setup_general_env.sh`、当前 JRiver 构建脚本和上游 RunImage 配置加载顺序；Shell 语法检查通过，未新增测试代码或测试 workflow。新配置生成后的 AppImage 启动、GUI、中文输入、网页音频、文件选择器和影院模式仍需实机验证。
