# JRiver Media Center AppImage

本目录用于构建 **JRiver Media Center Linux AppImage**。

> **当前打包方式（2026-09-13）：** `build_jriver.sh` 已改为标准 **RunImage + quick-sharun** 流程，最终产物仍为 `jriver.AppImage`。旧入口原样改名为 `build_jriver_legacy_20260913.sh`，不由正式 workflow 调用。前两次 Actions 已依次确认 CI 缺少非特权 user namespace 与 SUID `fusermount`；构建入口现同时准备 `fuse2` 的 SUID `fusermount` 和上游 SUID Bubblewrap。修复后的构建及 Linux 实机功能仍待验证，不能沿用旧版的功能验证结论；详见第 14～16 节。

以下第 1～13 节及 2026-09-12 状态均为**旧版打包路线的历史记录**，其中的补丁、已知问题和稳定基线继续保留，不代表新入口已经验证。

> **当前维护状态（2026-09-12）：** Kali Linux 实机已确认最新 `jriver.AppImage` 可以正常启动并显示 JRiver Media Center GUI，2026-09-11 的“进程启动但无可见 GUI”状态已被新的实机结果覆盖。当前新增已知问题：进入 **影院模式** 后，使用鼠标点击界面会卡住。构建兼容层、现有 CEF、网页音频、Fcitx5 和 glibc 隔离链本轮不再改动；详见第 13 节。下方历史记录继续保留。

> **2026-08-14：当前版本正式冻结为“最终可用稳定基线”。**
>
> 核心功能已经可用，但 **“文件 → 打开媒体文件 / 打开文件夹”仍会导致 JRiver/JRWeb 相关进程异常退出或当前实例闪退**。经过多轮最小补丁和 Kali Linux 实机验证后，没有拿到足以安全定位根因的 crash stack；因此停止继续根据 warning 猜测式修改。

---

## 1. 最终稳定基线

功能稳定基线提交：

```text
2eb58f38ae1c3ba568cbcd224a821c02b790b0f7
```

对应说明：

```text
fix(jriver): guard JRWeb CEF shutdown assertion
```

该基线保留此前已经确认正常的 JRiver 主链、JRWeb、CEF、网页音频、蓝牙音频、Fcitx5 和 glibc 隔离设计。

### 已确认可用

- JRiver Media Center 主界面可以正常启动；
- 本地媒体正常播放；
- JRWeb / YouTube 可以正常打开；
- JRWeb 网页视频有声音；
- 蓝牙音频输出正常；
- 不需要宿主额外安装 `libasound2-plugins`、PulseAudio 兼容包等依赖；
- Fcitx5 中文输入链保持；
- CEF runtime 与 JRWeb API/ABI 匹配；
- 不恢复危险的全局 `LD_LIBRARY_PATH`；
- AppImage 内 glibc 不暴露给宿主 `/bin/sh`、Chromium、`sed`、`id` 等外部程序。

### 最终保留的 Known Issue

```text
文件 → 打开媒体文件…
文件 → 打开文件夹…
```

在当前 AppImage 中仍可能触发闪退/子进程退出。

**这项问题没有解决。**

除该问题外，不再为了消除终端 warning 改动已经稳定的 JRiver/CEF/音频链。

---

## 2. 2026-08-14 最后一次实机结果

最后一轮实机仍能看到：

```text
WARNING: Glycin running without sandbox.
```

```text
Gtk-WARNING: Could not load a pixbuf from icon theme.
This may indicate that pixbuf loaders or the mime database could not be found.
```

```text
Automatic fallback to software WebGL has been deprecated.
Please use the --enable-unsafe-swiftshader flag ...
```

部分退出过程还出现：

```text
JRWebWnd::GetProcessRunning: waitpid error
```

以及：

```text
ipc: receiving failed 104
```

因此，之前 README 中“最新版本已经不再出现 `waitpid error`”的结论作废，以本节最新实机结果为准。

这些日志中目前仍没有得到能够直接指出文件选择器崩溃函数的 backtrace。

---

## 3. 为什么不再继续强修 Pixbuf / MIME / WebGL

### Pixbuf / MIME

曾经尝试为 AppImage 补充：

- `shared-mime-info` 数据库；
- `hicolor` / `Adwaita` / `AdwaitaLegacy` 图标主题；
- `icon-theme.cache`；
- `/usr/share/pixmaps`。

最后一次尝试：

```text
f8e49fccc29a2aa4ac29bc55ff8aa5382a226cce
fix(jriver): bundle GTK MIME and icon runtime data
```

对应 Action：

```text
Run: 31772764860
Job: build_jriver
Result: success
```

构建本身成功，但 Kali 实机验证结果是：

- `Gtk-WARNING: Could not load a pixbuf from icon theme` 仍然存在；
- 打开文件夹仍会闪退；
- 因此该补丁 **没有解决用户可见问题**。

该实验不作为最终稳定构建逻辑保留。

### WebGL

终端会看到：

```text
Automatic fallback to software WebGL has been deprecated.
```

当前网页/YouTube 本身可以正常显示和播放，因此没有证据证明该 warning 是文件选择器闪退的根因。

**不要为了消除日志而加入：**

```text
--enable-unsafe-swiftshader
```

Chromium 自己已经明确提示该选项会降低安全保证；当前稳定版不使用它。

### Glycin

```text
WARNING: Glycin running without sandbox.
```

当前属于 AppImage 运行环境中的已知 warning。没有 crash stack 证明它就是文件选择器闪退根因，因此不再根据这一行继续大范围改 GTK/Glycin。

---

## 4. 网页音频：已经修好，禁止回退

JRWebChromium 网页无声问题曾经实际经历：

```text
JRWebChromium
  -> ALSA default
  -> libasound_module_pcm_pulse.so
  -> libpulse.so.0
  -> libpulsecommon
  -> libsndfile.so.1
  -> FLAC / MP3 / Ogg / Opus / Vorbis
```

最终采用兼容的私有 Pulse 音频闭包，只给 JRWebChromium 暴露必要运行库。

关键原则：

- 保留 AppImage 的 `ALSA_PLUGIN_DIR`；
- 不用 AppImage 的 ALSA 配置覆盖宿主音频配置；
- 保留宿主 `PULSE_SERVER`；
- 不把整套 `shared/lib` / `AppDir/lib` 暴露给外部 Chromium；
- 私有音频 runtime 不包含 AppImage 自己的 `libc.so` / `ld-linux`；
- 不要求用户另外安装 Pulse/ALSA 插件包。

已确认网页和蓝牙声音恢复后，后续不得为了文件选择器问题破坏这一链。

---

## 5. glibc / Sharun 隔离：绝对不要回退

旧版曾使用很宽的：

```text
LD_LIBRARY_PATH=$APPDIR/shared/lib/pulseaudio:$APPDIR/shared/lib/gvfs:$APPDIR/shared/lib:$APPDIR/usr/lib:$APPDIR/lib
```

这种做法容易让宿主程序错误加载 AppImage 内 glibc，并出现例如：

```text
libc.so.6: undefined symbol: __pointer_chk_guard, version GLIBC_PRIVATE
```

最终稳定设计：

- AppRun shell 阶段清理危险的 `LD_PRELOAD` / `LD_LIBRARY_PATH`；
- JRiver 主程序由 Sharun 自己的加载链运行；
- JRWeb/JRWebChromium 只获得必要的私有 CEF/音频路径；
- 外部程序不能看到整套 AppImage glibc。

**后续禁止恢复全局 `LD_LIBRARY_PATH`。**

---

## 6. CEF 规则

JRWeb 对 CEF API/ABI 有严格要求。

CEF 不能简单“获取 latest 然后替换”。正确顺序：

```text
JRiver/JRWeb 更新
        ↓
确认 JRWeb 所需 CEF API/ABI
        ↓
找到匹配的 CEF runtime
        ↓
构建
        ↓
Kali 实机验证网页、声音、中文输入
        ↓
才能更新稳定基线
```

没有匹配证据时，不要升级 CEF。

---

## 7. 文件选择器问题：后续只有拿到新证据才继续

如果以后还要继续修“打开媒体文件/文件夹”闪退，必须先获取新的可定位证据。

优先顺序：

1. 获取 core dump / backtrace；
2. 如果没有 core，使用 `strace -f` 对点击文件选择器前后做完整跟踪；
3. 确认最先退出的是 JRiver 主进程、JRWeb、JRWebChromium、GTK file chooser、GIO、GdkPixbuf 还是其它子进程；
4. 对比同版本原生安装 JRiver 是否存在同样问题；
5. 对比旧的已知可用 AppImage 内 GTK/GIO/Pixbuf/MIME 文件和加载路径；
6. 只有找到明确缺失文件、ABI 错误或崩溃函数后，再做最小补丁。

不要再仅凭这些字符串直接改代码：

```text
Gtk-WARNING
Glycin
WebGL
waitpid error
ipc: receiving failed 104
Unhandled User Message
```

它们目前不足以单独证明根因。

---

## 8. 已失败/禁止重复的方案

### 不恢复 `gtk-class-fix.so`

历史全局 GTK/GLib hook 会扩大影响范围，不再使用。

### 不恢复 file chooser preload shim

尝试通过 `gtk_file_chooser_set_local_only()` preload 强制 local-only，没有解决实际问题，不保留。

### 不继续堆 Pixbuf/MIME 数据赌根因

`f8e49f...` 已经实机证明：补完整 MIME / 图标数据后 warning 和闪退仍然存在。

### 不恢复宽范围 ALSA/Pulse 注入

历史宽范围注入曾导致启动卡住，不再使用。

### 不直接复制 Arch rolling 的整套 Pulse 依赖

Arch runner 的 ABI 可能高于目标 Kali；网页音频使用当前已经验证的兼容闭包。

### 不加 `--enable-unsafe-swiftshader`

网页当前可用，且该选项明确降低安全保证，不为了日志干净而加入。

### 不激进修改 `/tmp` / pathmap

历史上 pathmap 临时目录改动曾影响主程序启动，没有明确证据不要再动。

---

## 9. 后续维护原则

1. **当前版本按最终稳定基线维护。**
2. 已验证正常的音频、CEF、glibc 隔离、Fcitx5、启动链禁止顺手重构。
3. 修一个问题只改一个最小作用域，不做整份脚本格式化。
4. 没有新的 crash/backtrace 证据，不再为文件选择器 warning 触发新一轮构建。
5. GitHub Actions 尽量一次完成，避免反复消耗 Actions 时间。
6. 新版本 JRiver/CEF 更新前必须先确认 ABI，再更新稳定基线。

---

## 10. 2026-08-14 历史结论

2026-08-14 时该版本曾按“最终可用稳定基线”收尾。

该结论只描述当时经过实机验证的产物；后续 quick-sharun 滚动更新已经改变打包链。2026-09-11 的实机结果曾是“当前新产物能够构建，但启动后没有可见 GUI”；该状态已被 2026-09-12 的新实机结果覆盖，最新状态见第 13 节。

---

## 11. 2026-09-09：补回启动前的硬编码路径映射

### 用途、技术栈与当前打包入口

- 上游来源：AUR `jriver-media-center` 配方获取的 JRiver 官方 Linux 包；应用版本继续随当前配方更新，不固定到旧版。
- 技术栈：x86_64 原生 C/C++ 主程序、GTK3 运行依赖、JRWeb/CEF 和音频插件；沿用已有私有 CEF、Pulse/ALSA、Fcitx5 与 glibc 隔离处理。
- 打包方式：Arch Linux 容器内由 quick-sharun 收集依赖，保留 JRiver 原始资源目录；自定义 `AppRun` 经 pathmap、`run-mc.sh` 和 Sharun 启动主程序。2026-09-11 起 quick-sharun 与 appimagetool 均继续使用 AnyLinux setup action 当前提供的版本，不在 JRiver 中单独固定。
- 正式入口：`.github/workflows/build.yml` 的独立 `Build JRiver` Job；目录变更仅选择 JRiver 构建，发布资产名为 `jriver.AppImage`。
- `jriver_cef_runtime.sh` 是历史辅助脚本，当前构建入口没有调用它；当前 CEF 运行时由固定核心基线处理。

### 故障与定位依据

新版构建成功并发布，但实际启动无法正常显示主界面。2026-09-07 对比旧版正常包与当天 Release 后，发现以下启动链缺口；2026-09-09 复核时相关脚本仍未改变：

- 旧包内 Sharun 为 2.2.4，对照 Release 为 2.3.0；setup action 从上游 main 获取 quick-sharun，固定最终封装工具并不等于固定整个依赖部署链。
- 对照 Release 的主程序、`mc36`、`libJRTools.so` 和 `Plugins/libout_Main.so` 已使用 `/tmp/<构建时生成的目录>/jriver/Media Center N` 路径。
- 创建该路径的代码位于 `bin/01-path-mapping-hardcoded.hook`，通常由上游 `AppRun.sh` 执行。自定义入口直接进入 pathmap 和 `bin/mediacenterN`，没有调用这个 hook；Sharun 的普通二进制启动模式也不会代为执行它。
- 因此在没有遗留映射的环境中，程序引用的路径没有被建立。旧包仍保留不同的原始路径和加载方式，不能直接恢复全局库路径，也不能把全部启动问题归因于 Sharun 版本号。

### 修改内容与已知结果

- 修改文件：`jriver/build_jriver.sh`、`jriver/README.md`。
- 在自定义 `AppRun` 启动 pathmap 前，显式加载随包生成的硬编码路径映射 hook；兼容原构建逻辑已接受的 `bin` 和 `shared/bin` 两种 hook 位置。
- 保留原有 pathmap、主程序、CEF、网页音频和输入法链；不恢复全局 `LD_LIBRARY_PATH`，不改变 JRiver 应用版本或其它应用的构建。
- 从展开后的历史脚本中移除独立 CEF 自测、非阻断诊断列表和专用语法检查命令；保留下载、必要输入、CEF ABI 和隔离相关的构建守卫，不新增测试代码或 workflow。
- 已通过旧包、对照 Release、上游 Sharun 源码及构建脚本静态检查确认这个缺口。补丁只解决该缺口；GUI、播放和文件选择器仍需真实运行反馈，不能仅因 Actions 成功就宣称全部恢复正常。

在 Linux 终端进入下载文件所在目录后执行：

```bash
# 为下载的 JRiver AppImage 添加执行权限
chmod +x ./jriver.AppImage

# 启动 JRiver Media Center
./jriver.AppImage
```

---

## 12. 2026-09-11：适配 quick-sharun 新 preload 布局；构建成功但 GUI 仍未出现

### 本次构建故障根因

2026-09-11 上游 quick-sharun 更新后，helper preload 的部署方式发生变化：

```text
旧布局：
AppDir/lib/anylinux.so
AppDir/.preload

新布局：
AppDir/lib/sharun-preload/anylinux.so
```

JRiver 固定核心基线仍按旧布局检查 `AppDir/.preload`，因此即使日志已经显示：

```text
* anylinux.so successfully added!
```

构建仍会误报：

```text
错误：quick-sharun 未启用 anylinux.so，无法保证 JRWebChromium 环境清理顺序。
```

### 已完成修改

最终保留的修复提交：

```text
390a7a376e2b8f4870e161dcdb01ca8dafb69c4d
Fix JRiver for current quick-sharun preload layout
```

该提交没有固定 quick-sharun 版本，而是让 `jriver/build_jriver.sh` 同时兼容：

```text
AppDir/.preload
AppDir/lib/sharun-preload
```

并继续检查实际 Sharun preload 顺序：

```text
anylinux.so
    ↓
jriver-cef-env.so
    ↓
jriver-cef-shutdown-guard.so
```

新版目录模式下，JRiver 自己的两个 preload 库也放入 `AppDir/lib/sharun-preload`，由 Sharun 按其当前规则加载；旧布局仍保留兼容分支。

随后构建又暴露出第二个独立问题：JRiver 脚本仍覆盖到旧的：

```text
appimagetool 0.3.3
```

而当前 quick-sharun 已带有新版 appimagetool 的固定 SHA256，因此出现：

```text
ERROR: sha256 check failed for /tmp/appimagetool!
```

对应修复提交：

```text
dc24c2c718d29415f9fa5ce2007056c33a14a3ba
Use current appimagetool with quick-sharun
```

最终处理为：

- quick-sharun 不固定版本；
- appimagetool 不固定版本；
- 两者均使用 AnyLinux setup action 当前提供的版本及对应校验值；
- 不设置 `SKIP_INTEGRITY_CHECKS=1` 绕过完整性校验；
- 不修改其它 AppImage 的打包逻辑。

中间提交：

```text
801544e9437ef2018883c828225439c1145da974
```

曾临时固定旧版 quick-sharun，该方向已经废弃，**后续不要恢复这种写法**。

### 当前 Actions 结果

```text
Run: 34573228817
Job: Build JRiver
Result: success
```

这证明当前代码已经能够完成依赖收集、AppImage 封装和发布流程，但只证明“构建成功”。

### 2026-09-11 Kali Linux 最新实机结果

下载最新 `jriver.AppImage` 后执行：

```bash
./jriver.AppImage
```

当前现象：

- 命令能够启动；
- 截图中没有立即打印新的报错；
- 终端保持在该进程上；
- **没有出现 JRiver GUI 主界面**。

因此当前状态应明确区分为：

```text
构建：已修复
AppImage 生成：成功
GUI 启动：未修复
```

### 后续继续修复时的边界

下一轮应直接针对“进程启动但无 GUI”定位，不要再次回退已经解决的构建兼容层。

保持以下内容不动，除非出现新的直接证据：

- 不固定旧版 quick-sharun；
- 不固定旧版 appimagetool；
- 不使用 `SKIP_INTEGRITY_CHECKS=1`；
- 不恢复全局 `LD_LIBRARY_PATH`；
- 不破坏已经保留的 CEF、网页音频、蓝牙音频、Fcitx5 和 glibc 隔离链；
- 不再把 `anylinux.so` 仅从 `AppDir/.preload` 判断是否存在。

后续重点应检查实际运行时启动链：

```text
AppRun
  ↓
01-path-mapping-hardcoded.hook
  ↓
pathmap / run-mc.sh
  ↓
Sharun
  ↓
mediacenter36
```

优先采集完整启动日志或 `strace -f`，确认 `mediacenter36` 是否真正进入 GUI 主循环、是否有子进程立即退出，以及 X11/GTK/显示环境是否在自定义 AppRun → Sharun 链中丢失。没有运行时证据前，不应再通过反复修改 Actions 猜测 GUI 根因。

---

## 13. 2026-09-12：GUI 已恢复；影院模式鼠标点击会卡住

### 最新 Kali Linux 实机结果

最新 `jriver.AppImage` 已重新进行实机启动验证，当前结果为：

- `./jriver.AppImage` 可以正常启动；
- JRiver Media Center 36 GUI 主界面可以正常显示；
- 常规主界面可以进入并使用；
- 进入 **影院模式** 后，使用鼠标点击界面会出现卡住/无响应现象。

因此当前状态更新为：

```text
构建：正常
AppImage 生成：正常
GUI 启动：正常
影院模式：鼠标点击会卡住
```

2026-09-11 第 12 节中“GUI 未出现”的内容只保留为当时的历史记录，不再代表当前状态。

本次仅更新实机状态说明，不修改构建脚本、workflow、quick-sharun / appimagetool 兼容层，也不改动现有 CEF、网页音频、Fcitx5 和 glibc 隔离链。影院模式卡住问题先作为新的 Known Issue 记录；没有新的运行时证据前，不根据现有 GTK/Glycin warning 猜测根因。

---

## 14. 2026-09-13：保留旧入口，改用标准 RunImage + quick-sharun

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

## 15. 2026-09-13：修复 CI 中 builduser 无法进入 RunImage

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

## 16. 2026-09-13：补齐非 root FUSE / UnionFS 挂载条件

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

这证明第 15 节的 SUID Bubblewrap 已按预期生效，但只能解决 Bubblewrap 进入容器的问题；RunImage 外层 FUSE 和内部 UnionFS 仍缺少普通用户挂载所需的 SUID `fusermount`。本次仍未进入 `rim-update` 或 JRiver 安装阶段。

### 根因与修复

- 根因：JRiver Job 的 Arch 临时容器已透传 `/dev/fuse`，但没有安装提供 `/usr/bin/fusermount` 的 `fuse2`；上游 uruntime 在找不到 SUID `fusermount` 后尝试 user namespace，而该容器又禁止非特权 user namespace，最终导致两层 FUSE 挂载均失败。
- 修改文件：`jriver/build_jriver.sh`、`jriver/README.md`、根 `README.md`。
- 修复方式：在启动 RunImage 前通过 Arch 官方仓库安装 `fuse2`，检查 `/usr/bin/fusermount` 存在并确保其 SUID 位；随后继续沿用第 15 节已生效的 SUID Bubblewrap 和原有 `builduser` 构建命令。
- 作用边界：`fuse2`、SUID `fusermount` 与 SUID Bubblewrap 只存在于一次性 CI 容器，均不会复制进最终 `AppDir`，不会改变用户系统或最终 AppImage 的权限。
- 不改 workflow、不使用 root 运行 AUR `makepkg`，旧入口以及 CEF、音频、Fcitx5、glibc 和路径兼容链保持不变。

### 当前验证状态

已根据 Run 34756871436 完整日志、上游 uruntime 的 SUID `fusermount` 检查逻辑和 RunImage 的 UnionFS 挂载实现完成静态核对；Shell 语法检查通过，未新增测试代码或测试 workflow。修复提交后的 Actions 构建与全部实机功能仍待验证。

