# Alacritty AppImage

本目录用于构建 Alacritty AppImage。

## 最高优先级维护结论：禁止 quick-sharun

> **本节是 2026-08-13 Kali + i3wm 实机结论，优先级高于后文所有历史记录。README 后文若出现与本节冲突的旧说明，一律以本节为准。**

- **Alacritty 禁止再使用 `quick-sharun` / `quick-sharun --make-appimage` 打包。**
- 原因：quick-sharun 路线在真实 Kali + i3wm + fcitx5 环境中已经出现过“来回切换工作区若干次后 Alacritty 偶发无法输入，只能鼠标重新点击窗口才恢复”的问题。
- 当时正是因为这个实机输入问题，才从 quick-sharun 改到 **LinuxDeploy 路线**。以后不能因为历史 commit、依赖打得更全、包体更大、CI 能构建或 Xvfb/i3/xdotool 自动测试通过，就再次换回 quick-sharun。
- **真实 i3wm/fcitx5 实机长期使用结果高于 CI 模拟结果。** 50 次自动切换只能作为构建阶段辅助回归测试，不能推翻 quick-sharun 已经在真实环境出过输入故障的事实。
- 后续修复必须继续以 **LinuxDeploy / Ubuntu 22.04 路线**为打包基线，只在这个基线上处理 XKB/XCB/X11 依赖和输入问题；**禁止为了修依赖而更换整个打包框架。**
- 如果 `build_alacritty_linuxdeploy.sh` 中再次出现 `quick-sharun`，应直接视为**回归/错误方向**，不能把它当作新的稳定基线。
- 2026-08-13 后续生成的约 76 MiB quick-sharun AppImage，即使 CI 进行了 50 次工作区切换并通过，也**不属于稳定基线**。

维护者或后续 AI 在修改本目录前，必须先读这一节。**不要再根据旧 commit 把 quick-sharun 恢复回来。**

## 2026-08-13 当前输入修复基线：X11 下保持 IME 常开

> **本节记录当前实际修复代码和实机故障特征，优先级高于后文较早的 XKB、打包结构和实验记录。后续 AI 必须先以本节和当前仓库代码为准，不能看到旧记录后重新回退。**

### 实际故障特征

- 真实环境为 **Kali Linux + i3wm + fcitx5**。
- Alacritty 会在**多次来回切换 i3 工作区后偶发无法继续接收键盘输入**；这个问题**不需要截图也会发生**。
- 截图后也曾出现过不能输入，但截图只可能是额外触发条件，**不是必要条件，也不能把根因直接归到截图软件**。
- 典型表现是窗口仍正常存在，但键盘事件不再进入终端；有时重新用鼠标点一下窗口可以恢复，因此重点应放在 **X11 焦点 / XIM / XIC / fcitx5 输入链**，而不是继续无证据地换打包工具或乱补库。

### 当前确认到的代码原因

当前构建的 Alacritty 为 `0.17.0`，实际编译使用 `winit 0.30.13`。

winit 的 X11 IME 实现中，`set_ime_allowed()` 不是简单设置一个布尔值，而是会：

```text
remove_context(window)
create_context(window, allowed)
```

也就是**销毁并重新创建 XIC 输入上下文**。

Alacritty 0.17.0 的运行时 IME 处理会在窗口状态变化时调用 IME enable/disable；i3 工作区切换会产生反复的焦点变化，因此在 X11 + fcitx5 环境中存在反复销毁/重建 XIC 后偶发丢失键盘输入的风险。

Alacritty 上游以前实际上使用过同类保护：**X11 下不进行运行时 IME disable/enable，因为这种操作会破坏部分 IME。** 后来上游重新允许 X11 动态开关 IME；当前实机故障与这条变化高度吻合。

### 当前实际修复

当前仓库新增：

```text
alacritty/patches/0001-x11-keep-ime-enabled.patch
```

该补丁只针对 X11，在 Alacritty 的 `Window::set_ime_inhibitor()` 中增加：

```rust
if self.is_x11 {
    return;
}
```

作用是：

```text
X11：整个窗口生命周期保持 IME enabled，不再随着状态变化反复调用 winit set_ime_allowed()
Wayland：保持 Alacritty 0.17.0 原有行为，不受这个补丁影响
```

`build_alacritty_linuxdeploy.sh` 在编译 Alacritty 前执行：

```text
git apply --check patches/0001-x11-keep-ime-enabled.patch
git apply patches/0001-x11-keep-ime-enabled.patch
```

补丁应用失败时构建直接停止，不能静默生成未修复的 AppImage。

对应提交：

```text
6b74fe3aea21482fe168bc645fddabea54e1744e
fix(alacritty): keep X11 IME enabled across focus changes

4e33735c818b55b314c923b8000bacb791c54cf9
fix(alacritty): correct X11 IME patch hunk
```

其中 `4e33735c...` 只是修正补丁 hunk 格式，没有改变修复逻辑。

### 打包基线不能再改错

- **继续使用 LinuxDeploy；禁止 quick-sharun。**
- 这次输入修复是 **Alacritty 源码层 X11 IME 修复**，不是“再补一批 XKB/X11 库”的修复。
- 不要因为后续仍看到历史 XKB 记录，就再次删除/混搭 XKB 库、恢复 quick-sharun、扩大 X11 依赖集合或重新设计 AppRun。
- 当前实际构建脚本、补丁文件和最新成功提交是事实来源；README 后文包含大量历史方案，**如果后文结构描述与当前仓库代码冲突，以当前代码和本节为准。**

### 当前构建和实机验证状态

2026-08-13 当前修复版已经完成 GitHub Actions 构建和 Release 上传：

```text
Run: 31679019805 (#447)
build_alacritty: success
Publish to Latest Release: success
```

Latest Release 当前 `alacritty.AppImage`：

```text
Size: 5,073,400 bytes
SHA256: 357f736f6fe7ac90b9b82184bd5e64d517285384e67865a661f9e598b7a91005
```

当前实机状态：

```text
rofi 启动：已确认正常
真实 i3wm 多次切换后的长期输入稳定性：正在实机验证
```

因此当前版本可以称为**修复候选基线**，但在真实 i3wm 长期使用确认前，不要写成“已经百分之百彻底解决”。真实实机结果仍高于 CI。

### 如果以后再次出现无法输入

后续 AI 首先检查这几个点：

1. 当前 AppImage 是否来自 **LinuxDeploy** 路线，而不是 quick-sharun。
2. `0001-x11-keep-ime-enabled.patch` 是否仍存在并成功应用。
3. 当前 Alacritty / winit 是否修改了 X11 IME API 或 `set_ime_inhibitor()` 调用路径，导致现有补丁失效。
4. 故障发生时 X11 当前 active/focused window 是否仍是 Alacritty。
5. fcitx5/XIM/XIC 是否仍在工作，是否是输入上下文丢失而不是程序崩溃。

**不要第一步就继续换打包框架、补库或删库。** 只有拿到新的实机证据以后，才修改当前 LinuxDeploy + X11 IME 补丁基线。

---

当前最终方案不再追求“重新设计一个新的 AppImage 结构”，而是以已经实际正常使用过的旧 Alacritty AppImage 为结构基线，在这个基线上只更新 Alacritty 本体版本。

也就是说：

- Alacritty 本体继续跟随官方最新正式版源码。
- 构建环境固定为 Ubuntu 22.04。
- AppImage 内的启动方式、目录结构、运行库集合、补全文件、man 页面、AppStream 元数据、文档目录和空目录都按旧正常包复现。
- 打包路线保持 LinuxDeploy / Ubuntu 22.04 基线；最终 AppDir/封装阶段仍应保持依赖集合受控，不能改用 quick-sharun。
- 最终 `AppRun` 是软链，直接指向 `usr/bin/alacritty`。
- 不再使用自定义 shell AppRun 注入 `LD_LIBRARY_PATH`、`XKB_CONFIG_ROOT`、`XLOCALEDIR` 等环境变量。
- 不再往包里额外塞旧正常包中不存在的 X11 库、XKB 数据目录或 terminfo 数据目录。
- 对最终 AppDir 和最终 AppImage 都做结构校验，防止以后“看起来能构建”，但文件布局又悄悄变掉。

2026-08-12 的结构修复构建已经通过 GitHub Actions：

```text
Run: 31612807566
Job: build_alacritty
Result: success
Publish to Latest Release: success
```

这里的“成功”指构建、脚本内结构校验和 Release 上传成功。最终运行基线仍然来自已经实际正常使用过的旧 AppImage，因此后续如果修改本目录，必须继续以该旧正常包的结构作为回归参考。

---

## 最终原则

当前 Alacritty AppImage 维护规则只有两部分：

### 可以变化

- Alacritty 官方最新正式版版本号。
- 最新源码对应的 Alacritty 可执行文件内容。
- 最新源码对应的 desktop、SVG 图标、补全文件、man 页面、AppStream 元数据、CHANGELOG 和许可证正文。
- Ubuntu 22.04 同一软件包名称下因安全更新产生的库文件内部内容。

### 不允许随意变化

- **LinuxDeploy / Ubuntu 22.04 打包基线；禁止切换到 quick-sharun。**
- Ubuntu 22.04 构建基线。
- `AppRun -> usr/bin/alacritty` 的软链结构。
- 13 个固定运行库的文件名集合。
- 39 个普通文件的路径集合。
- 旧正常包中存在的空图标目录和 `pixmaps` 目录。
- 顶层 `Alacritty.desktop`、`Alacritty.svg`、`.DirIcon` 软链。
- Alacritty 二进制和包内运行库的 RUNPATH 规则。
- 不额外加入旧正常包中没有的 X11 运行库。
- 不额外加入 `usr/share/X11/xkb`。
- 不额外加入 `usr/share/terminfo`。
- 不恢复自定义 AppRun wrapper。
- 不恢复大批环境变量清理或环境变量重写逻辑。

如果以后更新 Alacritty 后发现运行异常，优先检查“新版本是否真的需要新增依赖”，不要先修改已经验证过的整体打包结构，更不要因此切换到 quick-sharun。

---

## 关键文件

### `build_alacritty_linuxdeploy.sh`

这是当前实际使用的构建脚本。

**文件名和后续维护方向都应保持 LinuxDeploy 路线。** 如果当前脚本内容因为临时试验再次出现 `quick-sharun`，这属于回归/错误方向，不代表 README 应跟着把 quick-sharun 改成新基线。

LinuxDeploy 路线中的 AppDir、依赖集合和最终封装仍然需要按旧正常包结构受控；这里强调“继续使用 LinuxDeploy 路线”，并不等于允许打包工具无条件把全部 X11/XKB 库自动塞进去。

生成最终：

```text
alacritty/dist/alacritty.AppImage
```

GitHub Actions 工作流直接引用：

```text
alacritty/build_alacritty_linuxdeploy.sh
```

以后如果要重命名，必须同时修改 workflow，不能只改文件名。

### `AppRun`

仓库中仍然存在历史 `alacritty/AppRun` 文件，但**当前最终构建脚本不会把它复制进 AppImage，也不会把它作为最终启动入口使用**。

当前 AppDir 中真正创建的是：

```text
AppRun -> usr/bin/alacritty
```

因此维护时不要根据仓库里的历史 `AppRun` 内容判断最终 AppImage 的运行方式，最终结果以构建脚本和解包后的 AppImage 为准。

---

## 为什么重新回到旧正常包结构

本轮最重要的问题不是“少一个库”这么简单，而是之前重新设计打包方式以后，最终产物已经和旧正常 AppImage 差得太多。

实际目录对比可以看到：

- 新包只有很少的 `usr/share` 内容。
- 旧正常包包含 Bash/Fish/Zsh 补全。
- 旧正常包包含 man 页面。
- 旧正常包包含 AppStream 元数据。
- 旧正常包包含多个 `usr/share/doc/*/copyright`。
- 旧正常包保留多个 hicolor 图标尺寸目录。
- 旧正常包保留 `pixmaps` 目录。
- 新包的 Alacritty 二进制没有 strip，体积明显异常。

对比时可以直接看到：

```text
新包 usr/bin/alacritty: 62,188,360 bytes
旧包 usr/bin/alacritty:  8,554,464 bytes
```

这已经说明当时的“结构差不多”判断不成立。

因此当前方案改为：

> 不再凭印象补几个库，而是明确固定旧正常包的完整文件布局。

---

## 当前完整构建流程

### 1. 切换到 Alacritty 打包目录

脚本首先执行：

```bash
cd "$(dirname "$0")"
```

保证后续所有路径都以 `alacritty/` 目录为基准。

### 2. 检查 Docker

当前构建需要 Docker，并检查：

```text
docker 命令存在
docker daemon 可用
```

Docker 不可用时直接停止，不在宿主环境里临时换一种构建方式。

### 3. 固定 Ubuntu 22.04

稳定维护基线的实际编译和 AppDir 准备应保持在：

```text
ubuntu:22.04
```

容器中完成。

目的不是固定 Alacritty 版本，而是固定构建环境和运行库来源。

Alacritty 本体仍然获取最新正式版。

**不要因为 quick-sharun 历史构建使用 Arch，就把稳定构建环境从 Ubuntu 22.04 改成 Arch。**

### 4. 获取最新正式版

脚本通过 Alacritty 官方 GitHub Release 的 latest 地址获取当前正式版标签：

```text
TAG
VERSION
```

然后：

```bash
git clone --depth 1 --branch "$TAG" https://github.com/alacritty/alacritty.git /tmp/alacritty
```

因此不会把某一个 Alacritty 版本号永久写死在脚本里。

### 5. 源码编译

使用：

```bash
cargo build --release --locked
```

直接编译官方源码。

这里不再使用 Ubuntu 软件源里的旧版 Alacritty 二进制。

### 6. 复制 Alacritty 二进制并执行 strip

源码构建完成后：

```text
/tmp/alacritty/target/release/alacritty
```

被安装到：

```text
AppDir/usr/bin/alacritty
```

随后明确执行：

```bash
strip --strip-unneeded "$APPDIR/usr/bin/alacritty"
```

这一项不能删。

之前对比中出现 60MB 级 Alacritty 二进制，就是因为 release 二进制仍然带有大量可去除的符号信息。

当前最终包必须先 strip，再进入 AppImage。

---

## AppRun 最终结构

当前最终 AppImage 不使用 shell wrapper。

结构固定为：

```text
AppRun -> usr/bin/alacritty
```

这样做的重点是复现旧正常包实际已经验证过的启动方式，而不是继续通过 AppRun 注入一套新的运行环境。

当前脚本还会主动校验：

```bash
readlink "$APPDIR/AppRun"
```

结果必须严格等于：

```text
usr/bin/alacritty
```

最终 AppImage 解包后还会再次检查一次，避免打包阶段改变结构。

---

## Alacritty 二进制 RUNPATH

当前 Alacritty 二进制固定使用：

```text
$ORIGIN/../lib
```

对应：

```bash
patchelf --set-rpath '$ORIGIN/../lib' "$APPDIR/usr/bin/alacritty"
```

因此位于：

```text
usr/bin/alacritty
```

的主程序可以直接解析：

```text
usr/lib/
```

中的固定运行库。

不需要再依赖 AppRun 去拼接 `LD_LIBRARY_PATH`。

---

## 包内运行库 RUNPATH

包内 13 个固定运行库全部设置：

```text
$ORIGIN
```

也就是同一个 `usr/lib` 目录内部互相解析。

脚本使用：

```bash
patchelf --set-rpath '$ORIGIN' "$library"
```

这里没有 `|| true`。

如果某个固定库不能正确写入 RUNPATH，构建应该直接失败，而不是静默继续生成一个未知状态的 AppImage。

---

## 固定的 13 个运行库

当前 `usr/lib` **只允许**存在以下 13 个普通库文件：

```text
libXau.so.6
libXdmcp.so.6
libbrotlicommon.so.1
libbrotlidec.so.1
libbsd.so.0
libffi.so.8
libmd.so.0
libpng16.so.16
libwayland-client.so.0
libwayland-egl.so.1
libxcb-xkb.so.1
libxkbcommon-x11.so.0
libxkbcommon.so.0
```

这些库应继续按稳定 LinuxDeploy / Ubuntu 22.04 基线准备；其中如果某些 XKB 库因已记录的兼容性修复需要同源构建，应以 README 后面的 2026-08-13 XKB 修复记录为准。

脚本不是“能找到什么就复制什么”，而是先固定文件名，再逐个确认来源并复制。

任意一个库找不到都会直接失败。

---

## 明确禁止自动加入的额外 X11 库

当前脚本会检查并禁止下列库进入 AppDir：

```text
libX11.so*
libX11-xcb.so*
libXcursor.so*
libXi.so*
libXinerama.so*
libXrandr.so*
libXss.so*
libXxf86vm.so*
```

这不是说这些库在所有 Linux 程序里都“没用”，而是因为**当前已验证正常 Alacritty AppImage 的固定基线里没有它们**。

没有新的、可重复复现的运行问题之前，不要因为“可能有用”就重新加入。

---

## 固定的 39 个普通文件

当前脚本对 AppDir 的普通文件做完整路径集合校验。

必须且只能包含下面 39 个普通文件：

```text
usr/bin/alacritty
usr/lib/libXau.so.6
usr/lib/libXdmcp.so.6
usr/lib/libbrotlicommon.so.1
usr/lib/libbrotlidec.so.1
usr/lib/libbsd.so.0
usr/lib/libffi.so.8
usr/lib/libmd.so.0
usr/lib/libpng16.so.16
usr/lib/libwayland-client.so.0
usr/lib/libwayland-egl.so.1
usr/lib/libxcb-xkb.so.1
usr/lib/libxkbcommon-x11.so.0
usr/lib/libxkbcommon.so.0
usr/share/applications/Alacritty.desktop
usr/share/bash-completion/completions/alacritty.bash
usr/share/doc/alacritty/changelog.Debian.gz
usr/share/doc/alacritty/changelog.gz
usr/share/doc/alacritty/copyright
usr/share/doc/libbrotli1/copyright
usr/share/doc/libbsd0/copyright
usr/share/doc/libffi8/copyright
usr/share/doc/libmd0/copyright
usr/share/doc/libpng16-16/copyright
usr/share/doc/libwayland-client0/copyright
usr/share/doc/libwayland-egl1/copyright
usr/share/doc/libxau6/copyright
usr/share/doc/libxcb-xkb1/copyright
usr/share/doc/libxdmcp6/copyright
usr/share/doc/libxkbcommon-x11-0/copyright
usr/share/doc/libxkbcommon0/copyright
usr/share/fish/vendor_completions.d/alacritty.fish
usr/share/icons/hicolor/scalable/apps/Alacritty.svg
usr/share/man/man1/alacritty-msg.1.gz
usr/share/man/man1/alacritty.1.gz
usr/share/man/man5/alacritty-bindings.5.gz
usr/share/man/man5/alacritty.5.gz
usr/share/metainfo/org.alacritty.Alacritty.appdata.xml
usr/share/zsh/vendor-completions/_alacritty
```

脚本通过：

```text
EXPECTED_FILES
ACTUAL_FILE_LIST
```

排序后做完整字符串比较。

因此以后如果：

- 少一个文件；
- 多一个普通文件；
- 文件放到不同路径；

构建都会直接失败并输出 diff。

这比只检查 `alacritty.AppImage` 文件是否存在可靠得多。

---

## Bash / Fish / Zsh 自动补全

旧正常包里存在三套 shell 补全，因此当前全部恢复：

```text
usr/share/bash-completion/completions/alacritty.bash
usr/share/fish/vendor_completions.d/alacritty.fish
usr/share/zsh/vendor-completions/_alacritty
```

内容使用当前最新 Alacritty 源码中的：

```text
extra/completions/
```

这样保持目录布局不变，同时补全内容跟随当前 Alacritty 版本更新。

---

## man 页面

旧正常包中存在四个 man 页面：

```text
usr/share/man/man1/alacritty.1.gz
usr/share/man/man1/alacritty-msg.1.gz
usr/share/man/man5/alacritty.5.gz
usr/share/man/man5/alacritty-bindings.5.gz
```

当前使用 `scdoc` 从当前版本源码生成，再使用：

```text
gzip -9n
```

压缩。

不会额外加入旧正常包中不存在的 man7 文件。

---

## AppStream 元数据

当前恢复：

```text
usr/share/metainfo/org.alacritty.Alacritty.appdata.xml
```

文件直接来自当前最新 Alacritty 源码：

```text
extra/linux/org.alacritty.Alacritty.appdata.xml
```

这也是之前精简包漏掉的内容之一。

---

## desktop 文件

当前直接使用最新正式版源码中的：

```text
extra/linux/Alacritty.desktop
```

安装到：

```text
usr/share/applications/Alacritty.desktop
```

顶层再建立：

```text
Alacritty.desktop -> usr/share/applications/Alacritty.desktop
```

不再手工重新拼一份 desktop 内容，避免以后上游字段变化而仓库里继续保留旧模板。

---

## 图标

当前使用上游：

```text
extra/logo/alacritty-term.svg
```

安装为：

```text
usr/share/icons/hicolor/scalable/apps/Alacritty.svg
```

顶层保留：

```text
Alacritty.svg -> usr/share/icons/hicolor/scalable/apps/Alacritty.svg
.DirIcon -> Alacritty.svg
```

这三层关系必须保持。

---

## 旧正常包中的空目录

目录对比时可以看到，旧正常包不只是有 `scalable/apps`，还保留多个空的 hicolor 尺寸目录。

当前脚本明确创建并检查：

```text
usr/share/icons/hicolor/16x16/apps
usr/share/icons/hicolor/32x32/apps
usr/share/icons/hicolor/64x64/apps
usr/share/icons/hicolor/128x128/apps
usr/share/icons/hicolor/256x256/apps
usr/share/pixmaps
```

这些目录即使当前没有普通文件，也属于旧正常包布局的一部分。

因此不要再因为“空目录没用”就顺手删掉。

---

## Alacritty 自身文档

当前恢复：

```text
usr/share/doc/alacritty/changelog.gz
usr/share/doc/alacritty/changelog.Debian.gz
usr/share/doc/alacritty/copyright
```

CHANGELOG 使用当前最新源码生成。

`copyright` 由当前源码中的：

```text
LICENSE-MIT
LICENSE-APACHE
```

组合生成。

这里的目标仍然是：路径保持旧正常包结构，正文跟随当前正式版源码。

---

## 运行库 copyright 文件

旧正常包还包含对应运行库的软件包版权文件。

当前恢复以下目录：

```text
usr/share/doc/libbrotli1/
usr/share/doc/libbsd0/
usr/share/doc/libffi8/
usr/share/doc/libmd0/
usr/share/doc/libpng16-16/
usr/share/doc/libwayland-client0/
usr/share/doc/libwayland-egl1/
usr/share/doc/libxau6/
usr/share/doc/libxcb-xkb1/
usr/share/doc/libxdmcp6/
usr/share/doc/libxkbcommon-x11-0/
usr/share/doc/libxkbcommon0/
```

每个目录只复制对应：

```text
copyright
```

如果 Ubuntu 22.04 容器里对应 copyright 文件不存在，构建直接失败。

---

## 当前不内置 XKB 数据目录

以前为了处理键盘问题，曾尝试把：

```text
/usr/share/X11/xkb
/usr/share/X11/locale
```

直接复制进 AppImage，再通过自定义 AppRun 指定：

```text
XKB_CONFIG_ROOT
XLOCALEDIR
```

这属于之前的实验方案，不是当前最终基线。

当前最终结构恢复为旧正常包方式：

```text
不内置 usr/share/X11/xkb
不使用自定义 AppRun 指向包内 XKB 数据
```

如果以后没有新的明确回归，不要重新加入。

---

## 当前不内置 terminfo 数据库

当前旧正常包结构同样没有额外：

```text
usr/share/terminfo
```

因此当前构建不复制 terminfo 数据库。

不要因为“终端程序可能需要”就把完整数据库重新塞进去；需要先有实际缺失证据。

---

## LinuxDeploy 路线中的依赖控制

这里禁止的是“让打包工具无条件、无限制地扩展依赖集合”，**不是禁止 LinuxDeploy 打包路线本身**。

LinuxDeploy / Ubuntu 22.04 仍然是 Alacritty 的稳定维护方向；依赖集合必须继续按照已验证结构受控，不能因为某个动态库问题就改用 quick-sharun。

任何自动依赖收集结果都可能随：

- 构建环境；
- 上游二进制链接关系；
- 打包工具自身逻辑；
- 黑名单；
- 某些动态加载库；

发生变化。

当前方案已经明确知道旧正常包中 `usr/lib` 应该是什么，因此固定依赖集合更加可控。

最终封装阶段只应处理已经准备好的 AppDir，不应再次无条件改变 AppDir 内容。

---

## 最终封装

使用稳定 LinuxDeploy 路线准备并校验 AppDir 后，生成：

```text
dist/alacritty.AppImage
```

打包前的 AppDir 必须已经完成全部文件和结构检查。

打包完成后还应重新解包最终 AppImage，再检查关键结构，避免“AppDir 正确、最终文件却变了”。

**不要用 `quick-sharun --make-appimage` 替换这一维护路线。**

---

## 最终版本校验

Alacritty 的：

```text
alacritty --version
```

有时会在版本号后面带 Git 提交信息。

因此脚本不会拿整行文本和：

```text
alacritty X.Y.Z
```

做死比较。

当前只提取第二个字段作为实际版本号，再与本次取得的最新正式版标签比较。

这样既能确认构建的是最新正式版，又不会因为额外 Git 后缀误判失败。

---

## GitHub Actions

当前 workflow 中 Alacritty 使用独立 job：

```text
build_alacritty
```

核心步骤：

```bash
chmod +x alacritty/build_alacritty_linuxdeploy.sh
env -u GITHUB_ACTIONS ./alacritty/build_alacritty_linuxdeploy.sh
test -s alacritty/dist/alacritty.AppImage
```

随后上传：

```text
alacritty/dist/alacritty.AppImage
```

到：

```text
Release: latest
```

并使用 `--clobber` 覆盖同名旧产物。

2026-08-12 当前结构版本对应构建：

```text
Run ID: 31612807566
build_alacritty: success
Publish to Latest Release: success
```

---

## 本轮实际踩过的坑

### 1. Ubuntu 软件源 Alacritty 太旧

曾经尝试直接使用 Ubuntu 软件源版本，出现过：

```text
Unused config key: general
```

因此当前继续从官方最新 Release 源码构建，不回到 APT Alacritty。

### 2. 只看“能启动”不代表打包结构正确

之前某些版本从终端能够启动，但通过 rofi、输入法、工作区切换等真实使用路径时仍会暴露问题。

因此不能只拿：

```text
./alacritty.AppImage --version
```

成功就判断整个包已经正确。

### 3. 只补几个 XKB/X11 库仍然不等于旧正常包

之前把注意力集中在键盘相关库上，容易忽略：

- completion；
- man；
- metainfo；
- doc；
- 空目录；
- 顶层软链；
- 二进制是否 strip；

最终目录对比证明这种判断不完整。

### 4. 自定义 AppRun 不是越复杂越稳定

以前尝试过通过 AppRun 修改：

```text
PATH
LD_LIBRARY_PATH
XDG_DATA_DIRS
XKB_CONFIG_ROOT
XLOCALEDIR
TERMINFO
```

也尝试过隔离父 AppImage 环境。

这些都是针对具体故障的实验过程，不应继续被当成当前稳定架构。

当前最终基线已经重新回到旧正常包的：

```text
AppRun -> usr/bin/alacritty
```

### 5. 过度打包 X11 库会让基线越来越模糊

如果每遇到一个怀疑点就增加一批 X11 库，最后会很难判断：

- 哪个库真正必要；
- 哪个库只是碰巧存在；
- 哪个库来自错误构建环境；
- 哪个库反而覆盖宿主正常组件。

当前直接固定旧正常包中的 13 个库，后续新增必须有明确证据。

### 6. release 编译不等于已经足够小

Rust `cargo build --release` 生成的二进制仍然可能保留大量符号信息。

本轮对比中 62MB 级二进制就是最直观的证据。

因此：

```text
cargo build --release
```

之后仍然必须执行：

```text
strip --strip-unneeded
```

### 7. quick-sharun 的 CI 通过不能覆盖真实 i3 输入故障

这是后续必须长期保留的结论：

```text
quick-sharun 构建成功 != 真实 i3wm 输入稳定
Xvfb/i3/xdotool 测试通过 != 真实 fcitx5 焦点链完全一致
50 次工作区切换通过 != 可以重新采用 quick-sharun
```

真实 Kali + i3wm 使用中已经出现过 quick-sharun 路线切换工作区后无法输入，因此以后不要再用自动测试结果把打包框架切回 quick-sharun。

---

## 修改本目录前必须检查

以后修改 Alacritty 打包时，至少确认以下项目：

1. `main` 是否仍然是最新基线。
2. **是否仍保持 LinuxDeploy / Ubuntu 22.04 打包路线，且没有误切到 quick-sharun。**
3. 是否仍从 Alacritty 官方 latest Release 获取版本。
4. 是否仍执行 `cargo build --release --locked`。
5. 是否仍对最终 Alacritty 二进制执行 strip。
6. `AppRun` 是否仍是 `usr/bin/alacritty` 软链。
7. `usr/lib` 是否仍然只有固定 13 个库。
8. 39 个普通文件路径集合是否保持。
9. 六个旧正常包空目录是否仍在。
10. 顶层三个软链是否保持。
11. 是否误加了额外 X11 库。
12. 是否误加了 XKB 数据目录。
13. 是否误加了 terminfo 数据目录。
14. 是否误恢复了自定义 AppRun wrapper。
15. **是否误恢复了 `quick-sharun` / `quick-sharun --make-appimage`。**
16. 最终 AppImage 解包后的结构是否仍然通过脚本校验。
17. `--version` 是否确实对应本次 latest 正式版。
18. GitHub Actions 是否完成 build 和 Release 上传。
19. **真实 Kali + i3wm + fcitx5 多次切换工作区后是否仍能输入。**

---

## 实际运行回归检查

脚本结构校验通过以后，真实环境建议继续检查：

```text
1. 直接执行 AppImage 是否正常启动。
2. 从 rofi 启动是否正常。
3. 键盘输入是否正常。
4. Fcitx5 中文输入是否正常。
5. 在 i3 中多次切换工作区以后是否仍可输入。
6. 新开多个 Alacritty 窗口是否正常。
7. Alacritty 配置文件是否没有旧版本语法警告。
8. 终端内 shell、PATH 和常用命令是否正常。
9. 关闭 Alacritty 是否正常退出。
```

如果这些真实使用检查通过，就把当前结构继续当作稳定基线，不因为“看起来可以优化”再改一次。

其中第 5 项是当前最高优先级实机验证项。**CI 自动切换测试只能辅助，不能替代这一项。**

---

## 禁止回退的错误方向

后续维护不要无证据回到以下方案：

```text
APT 旧版 Alacritty
quick-sharun / quick-sharun --make-appimage
把历史 quick-sharun 成功 commit 当成当前稳定证据
用 CI 50 次切换结果覆盖真实 i3/fcitx5 故障记录
自定义 AppRun 大量 export
继承或重写复杂 LD_LIBRARY_PATH
内置整套 XKB 数据
内置完整 terminfo
随意增加 X11 运行库
删除旧正常包中的 completion/man/metainfo/doc
删除空图标目录
省略 strip
只检查 AppImage 文件存在、不检查内部布局
```

同时要区分：**保持 LinuxDeploy 路线**不等于允许 LinuxDeploy 无限制自动塞入全部依赖。稳定打包框架不换，依赖集合仍然必须受控。

如果未来 Alacritty 上游发生真正的 ABI 或运行依赖变化，可以更新依赖基线，但必须先确认新版本实际需要什么，再明确修改 README 和结构校验，不能静默漂移，更不能把“依赖变化”直接解释成“换 quick-sharun”。

---

## 当前最终结论

当前 Alacritty AppImage 的核心不是“尽可能把东西全打进去”，也不是“尽可能精简”，而是：

```text
最新 Alacritty 本体
+
LinuxDeploy / Ubuntu 22.04 稳定打包路线
+
旧正常 AppImage 的启动结构
+
固定 13 个运行库
+
固定 39 个普通文件路径
+
固定空目录和顶层软链
+
strip 后的 Alacritty 二进制
+
固定 RUNPATH
+
依赖集合受控
+
构建前后双重结构校验
+
真实 Kali + i3wm + fcitx5 输入验证优先
```

后续除非出现新的、可以稳定复现的运行问题，否则应保持该结构，不再进行无依据的重构、删文件、补库或替换启动逻辑。

**尤其禁止再次切换到 quick-sharun。**

---

## 2026-08-13 X11 / XKB / i3 输入问题修复记录（后续维护优先阅读）

> **本节是 2026-08-13 故障记录。若本节中较早的判断与 README 顶部“禁止 quick-sharun”结论冲突，以 README 顶部最新实机结论为准。**

### 实际故障链

本轮不是单一故障，而是同一套 X11 / XKB 输入链在几次错误调整后连续暴露出不同问题：

1. 曾把 Ubuntu 22.04 的旧 XKB 运行库与宿主机输入环境混用，i3 多次切换工作区后出现 Alacritty 无法继续输入、需要鼠标重新点击窗口才能恢复的问题。
2. 后来直接把 `libxkbcommon.so.0`、`libxkbcommon-x11.so.0`、`libxcb-xkb.so.1` 全部从 AppImage 删除，导致部分 Kali 环境启动时直接出现：

```text
Library libxkbcommon-x11.so could not be loaded
```

3. 随后尝试通过自定义 AppRun 检查宿主 XKB 运行库并建立 `.so` shim，又导致宿主缺少完整 XKB X11 运行库时被 wrapper 提前拦截，AppImage 无法启动。
4. 再之后尝试“包内只放 `libxkbcommon-x11.so.0 + libxcb-xkb.so.1`、核心 `libxkbcommon.so.0` 使用宿主机”的半混合方案，实际 Kali 环境运行时出现：

```text
zsh: segmentation fault (core dumped) ./Downloads/alacritty.AppImage
```

因此后续维护必须记住：**不能再把 XKB core 与 XKB X11 库拆成不同版本、不同来源后混用。**

### 历史 quick-sharun 修复为什么不能再作为当前依据

2026-07-10 仓库曾有：

```text
Commit: 2fef65b0f58023c9a7a2d7f944e009afe3a4723f
Message: Fix Alacritty input freeze after workspace switch
```

该次处理重点是：

```text
使用宿主机 libX11 / libX11-xcb
不要在 AppImage 中内置 libX11.so* / libX11-xcb.so*
```

这个 X11 分层思路本身可以继续作为依赖排查参考，**但不能据此恢复 quick-sharun 打包框架**。

后续真实 Kali + i3wm 使用已经确认：quick-sharun 路线本身曾出现多次切换工作区后无法输入，所以这个历史 commit 只能证明“当时构建成功并解决过一个具体问题”，不能证明 quick-sharun 是长期稳定基线。

### 2026-08-13 LinuxDeploy 路线的 XKB 修复记录

曾有以下修复记录：

```text
Commit: d7971233b618b07bd7f914878b4bc583a312bdfb
Message: fix(alacritty): restore coherent XKB runtime and i3 input test
```

当时方案保持旧正常 AppImage 的结构基线：

```text
AppRun -> usr/bin/alacritty
固定 13 个运行库文件名
固定 39 个普通文件路径
不内置 usr/share/X11/xkb
不内置 usr/share/terminfo
不内置 libX11.so*
不内置 libX11-xcb.so*
```

XKB 运行库处理为：

- `libxkbcommon.so.0` 和 `libxkbcommon-x11.so.0` 必须由**同一次官方 libxkbcommon 1.13.2 源码构建**产生，不能再一半来自 AppImage、一半来自 Kali 宿主机。
- `libxcb-xkb.so.1` 继续作为固定运行库随 AppImage 提供。
- `libX11` / `libX11-xcb` 继续使用宿主机版本，保持历史上已经验证过的 i3/X11/fcitx5 修复方向。
- XKB 布局与 Compose 数据继续读取宿主机标准路径，不把 Ubuntu 22.04 的整套 XKB 数据目录复制进 AppImage。

README 前面“13 个运行库全部从 Ubuntu 22.04 系统包获取”的旧描述不应再机械理解。实际 XKB 兼容修复中：**`libxkbcommon.so.0` 与 `libxkbcommon-x11.so.0` 需要保持同版本、同来源，其余固定库继续按稳定 Ubuntu 22.04 构建环境准备。**

### 自动 i3 输入回归测试的正确定位

以后不能再只用：

```text
alacritty --version
```

或者“窗口能打开几秒”判断输入问题已经修好。

构建脚本可以使用 `Xvfb + i3 + xdotool` 做实际输入辅助测试，例如：

```text
启动 i3
启动 Alacritty
输入 before
切换到 i3 工作区 2
切回 i3 工作区 1
不点击鼠标、不再次 windowactivate
直接输入 after
检查 Alacritty PTY 最终必须收到 before|after
```

以下情况应让构建失败：

- Alacritty 创建窗口前退出。
- 工作区切回后没有恢复键盘焦点。
- 第二次输入没有真正进入 PTY。
- 出现 `libxkbcommon` 动态库加载错误。
- 出现 XKB panic。
- 出现 segmentation fault。
- 测试超时。

但是必须明确：**这只是 CI 辅助测试，不是决定打包框架的依据。** 即使扩展为 50 次循环全部通过，也不能据此重新采用 quick-sharun。

### 2026-08-13 quick-sharun 回退错误记录

2026-08-13 后续曾再次根据历史 commit 把构建切回 Arch + quick-sharun，并生成约 76 MiB 的 AppImage；对应最终一次构建提交为：

```text
Commit: d750711207797defca01cddbd3aca63b1b6aa0d5
Message: fix(alacritty): add quick-sharun compiler dependency
```

该路线还加入了连续 50 次 i3 工作区切换与键盘输入 CI 测试，CI 可以通过。

**这个结果现在明确判定为错误维护方向，不能作为稳定基线。** 原因不是这次 CI 失败，而是此前真实 i3wm 使用已经证明 quick-sharun 路线会出现切换工作区后偶发无法输入；重新用 CI 模拟测试替代真实宿主经验，本身就是维护判断错误。

因此以后看到上述 commit、约 76 MiB 包体、50 次切换通过等信息时，必须理解为：

```text
这是一次已否定的 quick-sharun 回退实验
不是新的稳定基线
不能再次照着恢复
```

### Kali + i3 实机验证优先级

真实环境检查仍然是：

```text
[必须] 直接执行 alacritty.AppImage 可以正常启动
[必须] rofi 可以正常调用 Alacritty
[必须] Fcitx5 输入正常
[必须] 在真实 i3 环境连续、多次来回切换工作区以后，始终可以继续输入
```

其中最后一项优先级最高。

> 连续多次切换 i3 工作区，切回 Alacritty 后不点击鼠标，直接打字，确认每次都能继续输入。

只有真实长期使用通过，才能正式记为稳定输入基线。

### 如果以后问题再次出现

下次 AI 或维护者看到“切工作区以后不能输入”“必须点一下鼠标才恢复”“启动出现 XKB panic”或“直接 segmentation fault”时，不要再立即做下面这些操作：

```text
不要切回 quick-sharun
不要因为历史 quick-sharun commit 构建成功就恢复它
不要因为 50 次 CI 工作区切换通过就恢复 quick-sharun
不要把三套 XKB 库全部删除改成宿主机依赖
不要重新加入宿主 XKB 检查 wrapper
不要人为建立 libxkbcommon-x11.so shim
不要只打包 libxkbcommon-x11 而让 libxkbcommon core 走宿主
不要把 libX11/libX11-xcb 塞回 AppImage
不要随意扩大 X11 运行库集合
不要因为 --version 成功就认定输入问题解决
```

应优先检查：

1. 当前测试的 AppImage 是否确实来自 LinuxDeploy / Ubuntu 22.04 稳定打包路线。
2. 包内 `libxkbcommon.so.0` 与 `libxkbcommon-x11.so.0` 是否仍来自同一次同版本构建。
3. 包内是否意外重新出现 `libX11.so*` 或 `libX11-xcb.so*`。
4. `AppRun` 是否仍为直接软链，而不是又换成自定义 wrapper。
5. CI 的实际输入辅助测试是否仍存在并通过。
6. **如果上述全部正常但 Kali 实机仍复现，再转向 Alacritty / winit / i3 / fcitx5 的焦点事件链调查，而不是继续无证据地来回换库或换打包框架。**

这段记录必须保留，目的就是避免以后再次重复 2026-08-13 已经踩过的同一组错误，尤其是**不要再把 Alacritty 从 LinuxDeploy 路线换回 quick-sharun**。