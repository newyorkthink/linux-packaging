# JRiver 测试版问题记录

## 状态

当前 RunImage 问题：**未解决。**

2026-09-10 已将正式 `setup_jriver.sh` 回退到文件选择器实验开始之前的旧构建逻辑，但用户随后实机确认：**换回旧版 RunImage 后，Rofi 启动 `mediacenter36` 仍然会出现无 GUI 的问题。**

因此，不能再把问题简单归因于后来新增的 `gvfs`、`dbus-run-session`、`LD_PRELOAD` Patch 或 `jriver-filechooser-launch` 中的任意单一修改，也不能把回退后的 RunImage 称为“已验证稳定版”。目前尚未确认究竟是哪一项运行时、构建产物或会话状态变化导致该严重回归。

当前实际使用方案：**暂时停用 JRiver RunImage，换回可正常使用的 AppImage 版本。**

## 现象矩阵

截至 2026-09-10 的实际现象：

| 启动方式 | 结果 |
| --- | --- |
| 终端直接启动实验版 `mediacenter36` | 曾可显示 JRiver GUI |
| nwg-drawer 启动 | 重启系统并调整测试版 launcher 后曾恢复正常 |
| Rofi 启动实验版 `mediacenter36` | 只有后台进程，GUI 不显示 |
| Rofi 启动回退后的旧版 RunImage | **仍然无 GUI** |
| Rofi 启动其他 RunImage | 正常 |
| JRiver AppImage | 当前已换回使用 |

Rofi 在本轮 JRiver 修改之前可以正常启动 `mediacenter36`，且其他 RunImage 目前仍可由 Rofi 正常启动。因此在没有直接证据前，不修改 Rofi、nwg-drawer 或其他正常组件。

## 重要更正：回退旧版仍复现

最初曾把以下提交中的旧构建脚本作为回退基线：

```text
d54b5702a820d5c779eb1216b05bdd8a0f779da2
```

该旧版不包含：

- `gvfs` 补充；
- GTK3 `startup-mode='cwd'` override；
- `gtk-recent-files-enabled=false`；
- `GIO_USE_VOLUME_MONITOR=unix`；
- `dbus-run-session` 包装；
- `filechooser-empty-path.so`；
- `LD_PRELOAD`；
- `jriver-filechooser-launch`。

旧版启动链为：

```text
RunImage
→ mediacenter36
→ /usr/bin/mediacenter36
```

但回退并重新使用这条旧启动逻辑后，用户确认 **Rofi → mediacenter36 仍然无法显示 GUI**。

这一结果非常关键：代码回退并没有恢复此前的实际行为。因此，当前问题不能再表述为“测试 launcher 导致，回退即可解决”。需要同时考虑 RunImage 构建产物、运行时状态、挂载环境、进程/会话残留，以及本轮操作期间发生但尚未被定位的其他变化。

## 伴随现象

故障发生时可以看到 JRiver/RunImage 相关后台进程仍存在，包括 `mediacenter36`、RunImage/DwarFS、`dbus-run-session` 和专用 launcher，但桌面没有出现 JRiver 主窗口。

一次故障会话中，后续通过其他 GUI 启动入口也出现异常；系统重启后部分现象恢复。该情况说明曾存在运行时进程/会话残留，但目前没有足够证据确认是否还有其他持久状态变化，也不能据此断言宿主系统配置已经损坏。

## 2026-09-10 文件选择器实验时间线

### 1. 补充 `gvfs`

提交：`ecca15ffc9d2ff4c58ba15fee684234fb241f01c`

目的：解决 GTK 文件选择器进入 `Recent` 时的 `Operation not supported`。

结果：仅安装 `gvfs` 没有完成修复。

### 2. GTK/GIO fallback

提交：`80edb90e3a7427d4d22bbfcf15830eeac380e18a`

加入 `startup-mode='cwd'`、`GIO_USE_VOLUME_MONITOR=unix` 和 GTK Recent 设置。

结果：这些设置生效，但 `recent:///` 仍不能直接工作。

### 3. 独立 session D-Bus

提交：`c14b186d9d97cb0bfc300d30eafbc5ddd89ca521`

加入：

```text
RIM_AUTORUN=("dbus-run-session" "--" "mediacenter36")
```

`dbus-run-session -- gio list recent:///` 可以激活 GVFS 服务，但正式 JRiver 文件选择器仍有问题。

### 4. 空路径 GTK Patch

提交：`c8b020a08a63cacddd438ac9f2270d841563fba7`

新增 `LD_PRELOAD` 兼容库，拦截 `gtk_file_chooser_set_current_folder()`；仅当 JRiver 传入空字符串时改成 Home。

实际结果：Linux 实机上“打开媒体文件”可以直接进入 Home，原 `The folder contents could not be displayed` / `Operation not supported` 弹窗消失。

但启动结构同时变为：

```text
RunImage
→ dbus-run-session
→ jriver-filechooser-launch
→ LD_PRELOAD Patch
→ /usr/bin/mediacenter36
```

### 5. 拆分兼容代码

提交：`840a4757c1dafc458a822d5db329d4257a044a17`

把内嵌 C Patch 与 launcher 拆成独立文件。

### 6. 尝试隔离外层 `LD_PRELOAD`

提交：`984519bee49eb1d6d8bbaf319ba46480bc8ff730`

测试版 launcher 改为不再拼接外层 `LD_PRELOAD`，只加载 JRiver 自己的 Patch。

结果：nwg-drawer 曾恢复，但 Rofi 启动 JRiver 仍无 GUI，因此外层 `LD_PRELOAD` 不是完整根因。

### 7. 回退旧 RunImage 逻辑

提交：`bcfb7a35973e8ca92898ad33c42f35a7c4b370f0`

正式 `setup_jriver.sh` 回到文件选择器实验前的旧构建逻辑，实验代码改为 `_test` 保留。

结果：**用户实机确认回退版仍存在 Rofi 启动无 GUI 的问题。** 因此该回退版只代表“代码已回退”，不代表“运行问题已恢复”。

## 当前能够确认的事实

1. 本轮 JRiver 修改之前，Rofi 可以正常启动 `mediacenter36` RunImage。
2. Rofi 当前仍能正常启动其他 RunImage。
3. 实验版 JRiver 从 Rofi 启动时出现“后台进程存在、GUI 不显示”。
4. 回退到文件选择器实验前的旧 RunImage 代码后，Rofi 启动问题仍然存在。
5. 因此新增 launcher、`LD_PRELOAD`、D-Bus、GVFS 等不能被单独认定为最终根因。
6. 当前无法确认是哪一项修改、构建产物变化或运行时状态造成了该严重回归。
7. 当前已换回 JRiver AppImage 版本使用，RunImage 暂不作为日常使用基线。

## 暂时不能下的结论

- 不能说 Rofi 本身坏了；
- 不能说 nwg-drawer 本身坏了；
- 不能说 `/usr/local/bin/mediacenter36` 软链接坏了；
- 不能说问题只由 `LD_PRELOAD` 或 `dbus-run-session` 引起；
- 不能说回退旧代码已经恢复稳定；
- 不能在没有证据的情况下断言宿主系统被永久修改或损坏；
- 不能把当前 `_test` 代码合回正式版。

## 后续处理原则

当前先以 AppImage 作为可用方案，不再继续修改 Rofi、nwg-drawer 或宿主系统。

若以后重新定位 RunImage，应从“此前确实能由 Rofi 正常启动的实际二进制/构建产物”开始做对照，而不只比较 Git 源码。需要同时记录：构建所用 RunImage 版本、最终产物哈希、启动入口、父进程环境、挂载路径、残留进程以及重启前后差异。

实验代码继续保留：

```text
setup_jriver_test.sh
filechooser-empty-path_test.c
jriver-filechooser-launch_test.sh
```

`setup_jriver_test.sh` 仅用于后续定位，不应覆盖当前日常使用的 AppImage 方案。
