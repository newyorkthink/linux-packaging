# Chromium AppImage

用于构建 Chromium 官方程序的 Linux x86_64 AppImage。

## 用途与产物

- 打包对象：Chromium（开源项目本体，非 Google Chrome）。
- 最终产物：`chromium.AppImage`，由 `build.yml` 的通用 AppImage 构建矩阵执行并发布到仓库 `latest` Release。
- 上游来源：Chromium 项目本身不提供官方通用 Linux 二进制发行版；使用 Arch `[extra]` 官方仓库的 `chromium` 包（该包直接基于 Google `chromium-browser-official` 官方源码构建）作为上游二进制来源。

## 技术栈

Chromium / Blink，GTK3 原生界面组件。依赖由 `pacman`/`yay` 按 `chromium` 包的真实依赖关系自动解析安装，未手工列运行库清单。

## 打包方式

- 路线：Arch Linux 环境内使用 quick-sharun，按[专用打包流程](../docs/packaging-classification.md#专用打包流程)维护。`/usr/bin/chromium` 是启动器，浏览器需要保留 `/usr/lib/chromium` 的程序与相邻资源。
- 公共步骤：复用 Arch 安装、x86_64 工作目录以及版本读写入口。版本由 `chromium --version` 动态取得，保留 `~/version`、desktop 的 `X-AppImage-Version` 和发布用的 `dist/version.txt`。
- desktop / 图标：复制 Arch 官方 desktop 用于写入版本元数据。图标直接使用 Arch 官方包的 hicolor 256×256 PNG。
- 主程序与资源：Arch 的 `/usr/bin/chromium` 是启动器，真正的 Chromium 主程序及 `resources.pak`、`icudtl.dat`、`locales/`、`chrome-sandbox`、ANGLE / SwiftShader 运行文件都位于 `/usr/lib/chromium/`。构建时把该目录完整复制到 `AppDir/bin/`，再交给 quick-sharun 部署，避免只打包启动器而遗漏真正的浏览器程序和资源。
- Qt6 shim：Arch Chromium 包自带 `libqt6_shim.so`，同时把 `qt6-base` 声明为可选的 Qt 支持依赖。由于构建会把 `AppDir/bin/*` 整体交给 quick-sharun，脚本显式安装官方 Arch `qt6-base`，让该上游 shim 的 `libQt6Core.so.6`、`libQt6Gui.so.6`、`libQt6Widgets.so.6` 依赖可解析；quick-sharun 检测到 `libQt6Core` 后会自动启用 Qt6 部署。
- 动态依赖探测：显式设置 `STRACE_BINARY=chromium` 与 `STRACE_FLAGS='about:blank --no-sandbox'`，让 quick-sharun 在构建阶段针对真正的 Chromium 主二进制收集动态加载依赖。
- AppImage runtime：设置 `URUNTIME_PRELOAD=1`，沿用 PkgForge Chrome-AppImage 对 Chromium/Chrome 多进程程序的处理，让 uruntime 保持 AppImage 挂载点，避免运行期间挂载点被提前回收。
- 中文界面：quick-sharun 部署完成后向 `AppDir/.env` 写入 `LANGUAGE=zh-CN`。Chromium Linux 使用 `LANGUAGE` / `LC_*` / `LANG` 环境变量选择 UI locale，因此直接执行 AppImage 和 desktop 启动都会默认使用简体中文，同时不修改宿主机 locale。
- 中文输入法：额外装 `ibus`、`fcitx5-gtk`，把两者的 GTK3 immodule 一并打包，同时兼顾 IBus 与 Fcitx5。

## 运行与兼容说明

- 仅支持 x86_64。
- 未自定义 AppRun，未强制指定 Ozone 平台；X11/Wayland 行为保持 Chromium 上游默认逻辑。
- AppImage 默认把 Chromium 主界面设为简体中文；仅设置 AppImage 内的 `LANGUAGE=zh-CN`，不覆盖宿主机 `LANG`、`LC_ALL` 或其他程序的语言环境。
- sandbox 保持 Chromium 自身行为；不集成会通过 `pkexec` 持久修改宿主 `sysctl` 的 `fix-namespaces.hook`。目标系统若限制非特权 user namespace，应由宿主系统按其自身安全策略处理；`--no-sandbox` 仅作为明确的故障诊断参数，不作为默认运行方式。
- Fcitx5 中文输入已经在实际 AppImage 中确认可用。构建同时收集 IBus GTK3 模块。

### Ubuntu 上的沙箱兼容性

启用 AppArmor 非特权用户命名空间限制的 Ubuntu 环境可能无法使用 Chromium 的命名空间沙箱。此时 Chromium 会尝试 SUID helper。本 AppImage 中 `bin/chrome-sandbox` 的模式为 `0755`，无法满足 SUID 回退要求，启动会因 `The SUID sandbox helper binary was found, but is not configured correctly` 中止。

Ubuntu 环境可使用 [Canonical 的 Chromium Snap](https://snapcraft.io/chromium)。继续使用 AppImage 时，由宿主管理员按照 [Ubuntu AppArmor 指南](https://documentation.ubuntu.com/release-notes/24.04/#unprivileged-user-namespace-restrictions) 为受信任的固定安装路径配置所需的 `userns` 权限。正式产物保留 Chromium 默认沙箱，构建时的 `STRACE_FLAGS` 仅用于依赖探测。

#### 英文启动错误

以下是现场启动日志，临时挂载目录的随机后缀用 `<id>` 代替。

```text
[9213:9213:1118/114316.909048:FATAL:sandbox/linux/suid/client/setuid_sandbox_host.cc:172] The SUID sandbox helper binary was found, but is not configured correctly. Rather than run without sandboxing I'm aborting now. You need to make sure that /tmp/.mount_chrom<id>/bin/chrome-sandbox is owned by root and has mode 4755.
[1118/114316.911712:ERROR:third_party/crashpad/crashpad/snapshot/elf/elf_image_reader.cc:678] no dynamic segment
[1118/114316.911951:ERROR:third_party/crashpad/crashpad/util/file/file_io_posix.cc:145] open /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq: No such file or directory (2)
[1118/114316.911966:ERROR:third_party/crashpad/crashpad/util/file/file_io_posix.cc:145] open /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq: No such file or directory (2)
[9233:9233:0100/000000.117802:ERROR:content/zygote/zygote_linux.cc:662] write: Broken pipe (32)
```

#### 用户在宿主执行的排查命令

用户先读到限制值为 `1`，修改为 `0` 后，同一个 AppImage 恢复启动。第一条可用来检查是否遇到了相同的宿主限制。

```bash
# 检查 AppArmor 用户命名空间限制，返回 1 表示限制已启用。
sysctl kernel.apparmor_restrict_unprivileged_userns
# 本次对照时临时放宽该限制，立即生效。
sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=0
# 本次实测写入的持久配置，重启后仍然生效。
printf '%s\n' 'kernel.apparmor_restrict_unprivileged_userns=0' | sudo tee /etc/sysctl.d/99-apparmor-userns.conf
```

后两条会放宽整台机器的限制，第三条还会把调整保留到重启后。这里保留用户的实测过程供比对。日常使用优先选择上面的 Chromium Snap 或仅对受信任安装路径授权的 AppArmor 方案。

恢复启动时还出现以下 VA-API 提示，浏览器随后正常打开。

```text
libva error: /tmp/.mount_chrom<id>/lib/dri/virtio_gpu_drv_video.so init failed
[9646:9646:1118/115157.930784:ERROR:media/gpu/vaapi/vaapi_wrapper.cc:1793] vaInitialize failed: resource allocation failed
```

### 直接运行

```bash
./chromium.AppImage
```

正常运行不需要默认追加 `--no-sandbox`。

## 稳定基准版

2026-09-06 的 Linux 实机验证确认当前方案可作为后续修改基准，功能实现对应 commit `97f0c45cda7054644a4322115ddcb7eabb8a52ef`。

已确认行为：

- `./chromium.AppImage` 可直接启动 Chromium，不需要 `--no-sandbox` 才能打开。
- Chromium 主界面、新标签页及恢复提示均能正常显示简体中文。
- Fcitx5 中文输入候选框与中文输入正常工作。
- Chromium 主窗口、地址栏和新标签页可正常使用。
- `AppDir/bin/*`、`/usr/lib/chromium/` 完整程序目录、`qt6-base`、`URUNTIME_PRELOAD=1`、`LANGUAGE=zh-CN`、IBus / Fcitx5 GTK3 immodule 均属于当前稳定基线；后续修改不得无依据删除或替换这些已确认逻辑。

当前已知但未造成启动或主要功能故障的日志：

- `WARNING: Glycin running without sandbox.`：Glycin 图像处理组件警告，不等同于 Chromium 主进程要求 `--no-sandbox`。
- `Registration response error message: DEPRECATED_ENDPOINT`：GCM / 推送注册相关错误；当前实机验证中未影响浏览器启动、中文界面或中文输入。
- `Requested load of chrome://newtab/ for incorrect profile type.`：新标签页 WebUI profile 类型日志；当前实机验证中新标签页仍能正常显示和使用。
- `Chromium 未正确关闭` / 恢复页面提示：属于上一次会话未正常结束后的恢复提示，不作为 AppImage 打包故障判断依据。

除非后续出现可复现的实际功能故障，不应仅为了消除上述非致命日志而改动当前稳定基线。

## 修复记录

### 2026-09-06：修复 AppImage 启动立即退出

- 故障现象：已构建的 `chromium.AppImage` 在真实 Linux 环境中执行 `./chromium.AppImage --no-sandbox` 后立即退出，无法正常打开浏览器。
- 根因：原脚本对 `/usr/bin/chromium` 使用 `readlink -f` 并据此推导程序目录；但 Arch 的 `/usr/bin/chromium` 是启动器而非 Chromium 主 ELF，真正程序与资源位于 `/usr/lib/chromium/`。因此构建输入只包含启动器，没有完整带入真正的 Chromium 主程序、资源和 locales。
- 修改文件：`chromium/build_chromium.sh`、`chromium/README.md`。
- 修复内容：改为显式使用 `/usr/lib/chromium/`，完整复制到 `AppDir/bin/` 后交给 quick-sharun；同时指定 `STRACE_BINARY=chromium` 与 `STRACE_FLAGS='about:blank --no-sandbox'`，确保动态依赖探测针对真实主程序执行；保留原有 IBus / Fcitx5 GTK3 输入法模块打包逻辑。

### 2026-09-06：补充 Chromium 多进程 AppImage 挂载保持

- 修改原因：横向核对 PkgForge `Chrome-AppImage` 后确认，其 quick-sharun 构建明确设置 `URUNTIME_PRELOAD=1`，用于要求 uruntime 持续保持 AppImage 挂载点；Chromium 与 Chrome 使用相同的多进程浏览器运行模型，应保留这一 runtime 处理。
- 修改文件：`chromium/build_chromium.sh`、`chromium/README.md`。
- 修改内容：仅新增 `URUNTIME_PRELOAD=1`；保留已经确认正确的 `./AppDir/bin/*` quick-sharun 输入和 `/usr/lib/chromium/` AppDir 布局，不复制 Chrome 专用的运行时下载逻辑、`ar` / `tar` / `xz` 依赖或测试步骤。
- 安全边界：未加入 PkgForge 的 `fix-namespaces.hook`。该 hook 会通过提权写入 `/etc/sysctl.d/20-fix-namespaces.conf` 并全局关闭 `kernel.apparmor_restrict_unprivileged_userns`，不符合本仓库最小宿主修改原则。

### 2026-09-06：修复 libqt6_shim.so 缺少 Qt6 依赖导致构建中止

- 故障现象：GitHub Actions `Build Chromium` 在 quick-sharun 开始部署时报告 `libQt6Core.so.6`、`libQt6Gui.so.6`、`libQt6Widgets.so.6` 均为 `not found`，随后以 `./AppDir/bin/libqt6_shim.so is missing libraries! Aborting...` 退出。
- 根因：Arch Chromium 包包含 `libqt6_shim.so`，但把 `qt6-base` 作为可选依赖，因此单独安装 `chromium` 不会拉入 Qt6；当前脚本又按既定布局把 `AppDir/bin/*` 整体交给 quick-sharun，导致 quick-sharun 在检查该上游 shim 时发现其直接 ELF 依赖缺失并主动终止。
- 修改文件：`chromium/build_chromium.sh`、`chromium/README.md`。
- 修复内容：在原有 Chromium / 输入法安装命令中加入官方 Arch `qt6-base`，保留 `libqt6_shim.so` 和 `./AppDir/bin/*` 既有打包方式，不删除上游库，也不额外硬编码 `DEPLOY_QT=1`；quick-sharun 会在检测到 `libQt6Core` 后自动选择 Qt6 部署。
- 参考依据：PkgForge `Chrome-AppImage` 使用的 `get-debloated-pkgs --add-common` 明确包含 `qt6-base-mini`，说明其 Chrome 打包同样为 Qt6 shim 准备 Qt6 运行库；本仓库按来源优先级使用 Arch 官方 `qt6-base`。

### 2026-09-06：修复中文输入正常但 Chromium UI 仍为英文

- 故障现象：实际 AppImage 已能正常启动，Fcitx5 中文输入候选框工作正常，但 Chromium 菜单、新标签页等主界面仍显示英文。
- 根因：`locales/zh-CN.pak` 已随 `/usr/lib/chromium/` 正确打包，但 Chromium Linux 不以 `--lang` 作为主界面语言选择依据，而是读取 `LANGUAGE`、`LC_ALL`、`LC_MESSAGES`、`LANG`。AppImage 之前继承宿主机英文 locale，因此最终选择英文 UI。
- 修改文件：`chromium/build_chromium.sh`、`chromium/README.md`。
- 修复内容：在 quick-sharun 完成 AppDir 部署后向 `AppDir/.env` 写入 `LANGUAGE=zh-CN`，由 sharun 在 AppImage 运行时注入该环境变量；不修改 desktop `Exec`，不添加 Linux 上不可靠的 `--lang=zh-CN`，也不覆盖宿主机 `LANG` / `LC_ALL`。

### 2026-09-06：确认稳定基准版

- 实机结果：最新 AppImage 已确认可直接启动，简体中文 UI 生效，Fcitx5 中文输入正常，主窗口与新标签页可正常使用。
- 基准实现：commit `97f0c45cda7054644a4322115ddcb7eabb8a52ef`。
- 修改文件：本次仅整理 `chromium/README.md`，不改动已经实机验证正常的 `chromium/build_chromium.sh`。
- 基准原则：以后处理 Chromium 打包问题时，应以本节记录的程序目录、Qt6、runtime、中文界面和输入法逻辑为稳定基线，不因单纯非致命日志而擅自改写已验证内容。

## 版本元数据接入（2026-09-16）

- 构建脚本复用现有 `chromium --version` 取得的动态版本，在 AppImage 成功生成后写入 `dist/version.txt`。
- workflow 使用 `SOFTWARE_KEY=chromium` 接入统一 `software_versions.json`。
- 本次不改动已确认稳定的 Chromium 程序目录、Qt6、中文界面、输入法和 runtime 基线。

## 实机验证

### 2026-11-18：用户实机验证通过

用户已确认 Chromium AppImage `157.0.8103.78` 实机验证通过。

| 实测项目 | 通过结果 |
| --- | --- |
| Linux 启动 | 同一 AppImage 在宿主允许非特权用户命名空间后正常启动。 |

#### 运行观察

- 启用限制时出现 SUID helper 配置错误，允许用户命名空间后的对照启动恢复。
- 恢复启动时出现 `vaInitialize failed: resource allocation failed` 提示，程序继续启动。
