# JRiver Media Center AppImage

本目录用于构建 **JRiver Media Center Linux AppImage**。

> **2026-09-01：已从 `qq895311511/appimage-packaging` 迁移到本仓库。**
>
> 为避免依赖另一仓库的 Git 历史，原稳定构建链已本地化为 `build_jriver.sh` → `build_jriver_audio.sh` → `build_jriver_base.sh`。`build_jriver_base.sh` 保持源仓库已验证 blob `a589c8f8e11480b1805226d8d8c247bc7d689d4e` 原样不变；外层仍只追加已经实机验证过的 Bookworm Pulse 音频闭包和 JRWeb CEF shutdown guard。

> **2026-08-14：当前版本正式冻结为“最终可用稳定基线”。**
>
> 核心功能已经可用，但 **“文件 → 打开媒体文件 / 打开文件夹”仍会导致 JRiver/JRWeb 相关进程异常退出或当前实例闪退**。经过多轮最小补丁和 Kali Linux 实机验证后，没有拿到足以安全定位根因的 crash stack；因此停止继续根据 warning 猜测式修改。

---

## 1. 最终稳定基线

源仓库功能稳定基线提交：

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

## 10. 当前结论

**JRiver AppImage 当前作为最终可用版本收尾。**

可正常使用的主功能保留；“打开媒体文件/文件夹”闪退作为已知问题记录，不再继续盲修。
