# JRiver 测试版问题记录

## 状态

当前测试版：**未解决，不作为正式发布版本。**

正式 `setup_jriver.sh` 已恢复到 2026-09-10 文件选择器实验开始前的旧构建逻辑；本文件只记录 `_test` 线的问题与后续定位依据。

## 现象矩阵

截至 2026-09-10 的实际现象：

| 启动方式 | 结果 |
| --- | --- |
| 终端直接启动 `mediacenter36` | JRiver GUI 可以显示 |
| nwg-drawer 启动 | 重启系统并调整测试版 launcher 后，目前可正常显示 |
| Rofi 启动 `mediacenter36` | 仍然只有后台进程，GUI 不显示 |
| Rofi 启动其他 RunImage | 正常 |

Rofi 在本次 JRiver 修改之前可以正常启动 `mediacenter36`，且 Rofi 自身没有对应改动。因此当前故障范围继续限定在 JRiver 测试版启动链，不修改 Rofi。

## 伴随现象

故障发生时可以看到 JRiver/RunImage 相关后台进程仍存在，包括 `mediacenter36`、RunImage/DwarFS、`dbus-run-session` 和专用 launcher，但桌面没有出现 JRiver 主窗口。

一次故障会话中，后续通过其他 GUI 启动入口也出现异常；系统重启后相关会话状态被清理，nwg-drawer 恢复正常。这说明曾存在运行时进程/会话残留，但目前没有证据证明宿主系统配置被永久修改或损坏。

## 旧正式基线

文件选择器实验开始前的构建脚本来自提交：

```text
d54b5702a820d5c779eb1216b05bdd8a0f779da2
```

该旧版启动链很简单：

```text
RunImage
→ mediacenter36
→ /usr/bin/mediacenter36
```

旧版没有以下测试逻辑：

- `gvfs` 补充；
- GTK3 `startup-mode='cwd'` override；
- `gtk-recent-files-enabled=false`；
- `GIO_USE_VOLUME_MONITOR=unix`；
- `dbus-run-session` 包装；
- `filechooser-empty-path.so`；
- `LD_PRELOAD`；
- `jriver-filechooser-launch`。

因此正式线已经回到该旧逻辑，避免继续影响正常启动入口。

## 2026-09-10 文件选择器实验时间线

### 1. 补充 `gvfs`

提交：`ecca15ffc9d2ff4c58ba15fee684234fb241f01c`

目的：解决 GTK 文件选择器进入 `Recent` 时的 `Operation not supported`。

结果：仅安装 `gvfs` 没有完成修复。

### 2. GTK/GIO fallback

提交：`80edb90e3a7427d4d22bbfcf15830eeac380e18a`

加入：

- `startup-mode='cwd'`；
- `GIO_USE_VOLUME_MONITOR=unix`；
- GTK Recent 设置。

结果：这些设置实际生效，但 `recent:///` 仍不能直接工作。

### 3. 独立 session D-Bus

提交：`c14b186d9d97cb0bfc300d30eafbc5ddd89ca521`

加入：

```text
RIM_AUTORUN=("dbus-run-session" "--" "mediacenter36")
```

已验证 `dbus-run-session -- gio list recent:///` 能激活 GVFS 服务，但正式 JRiver 文件选择器仍有问题。

### 4. 空路径 GTK Patch

提交：`c8b020a08a63cacddd438ac9f2270d841563fba7`

新增 `LD_PRELOAD` 兼容库，拦截 `gtk_file_chooser_set_current_folder()`；仅当 JRiver 传入空字符串时改成 Home。

实际结果：Linux 实机上“打开媒体文件”可以直接进入 Home，原 `The folder contents could not be displayed` / `Operation not supported` 弹窗消失。

但该方案同时引入新的启动结构：

```text
RunImage
→ dbus-run-session
→ jriver-filechooser-launch
→ LD_PRELOAD Patch
→ /usr/bin/mediacenter36
```

### 5. 拆分兼容代码

提交：`840a4757c1dafc458a822d5db329d4257a044a17`

把内嵌 C Patch 与 launcher 拆成独立文件。逻辑上保持上述测试版启动链。

### 6. 尝试隔离外层 `LD_PRELOAD`

提交：`984519bee49eb1d6d8bbaf319ba46480bc8ff730`

发现 Rofi/nwg-drawer 等便携启动器可能带有自己的 `LD_PRELOAD`。测试版 launcher 改为不再拼接外层 `LD_PRELOAD`，只加载 JRiver 自己的 Patch。

结果：nwg-drawer 当前看起来恢复正常，但 **Rofi 启动 JRiver 仍无 GUI**。因此“外层 `LD_PRELOAD` 污染”不是完整根因，不能把该提交称为最终修复。

## 当前能够确认的事实

1. Rofi 在 JRiver 文件选择器实验之前能正常启动 JRiver RunImage。
2. Rofi 目前仍能正常启动其他 RunImage。
3. nwg-drawer 当前能正常启动 JRiver。
4. 终端直接启动 JRiver 正常。
5. 当前异常只在 Rofi → JRiver 测试版这条组合链上稳定出现。
6. 测试版加入了旧版没有的 D-Bus、GVFS、GTK override、launcher 与 `LD_PRELOAD` Patch。
7. 将外层 `LD_PRELOAD` 从 JRiver launcher 中剔除后，Rofi 问题仍存在。
8. 目前没有足够证据把根因定为 Rofi、宿主系统、软链接、`LD_PRELOAD`、D-Bus 中的任意单一项。

## 暂时不能下的结论

- 不能说 Rofi 本身坏了；
- 不能说 nwg-drawer 本身坏了；
- 不能说 `/usr/local/bin/mediacenter36` 软链接坏了；
- 不能说宿主系统被永久修改或损坏；
- 不能再把问题简单归因于外层 `LD_PRELOAD`；
- 不能把当前 `_test` 代码合回正式版。

## 后续定位范围

如果以后继续修 `_test`，只在 JRiver 测试线逐项隔离，不修改宿主系统和正常启动器。推荐按以下顺序做二分：

1. 旧版 + 仅 `gvfs`；
2. 再加入 GTK schema / Recent 设置；
3. 再加入 `GIO_USE_VOLUME_MONITOR=unix`；
4. 再加入 `dbus-run-session`；
5. 最后单独加入 `LD_PRELOAD` Patch 与 launcher。

每一步都同时验证：

```text
终端启动
Rofi 启动
nwg-drawer 启动
打开媒体文件
退出后是否残留后台进程
```

只有明确找到“从哪一步开始 Rofi 无 GUI”，才能继续修复；在此之前不再修改 Rofi、nwg-drawer 或宿主环境。

## 当前测试文件

```text
setup_jriver_test.sh
filechooser-empty-path_test.c
jriver-filechooser-launch_test.sh
```

`setup_jriver_test.sh` 产物为 `mediacenter36_test`，只用于后续定位，不由当前正式 JRiver GitHub Actions 自动发布。
