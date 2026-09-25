# JRiver Media Center RunImage

本目录用于维护 JRiver Media Center RunImage。当前 RunImage 线仍处于问题定位阶段，测试代码与回退代码分开维护。

## 当前状态

### 回退版 RunImage

- 构建脚本：`setup_jriver.sh`
- 发布产物：`mediacenter36`
- 基线来源：提交 `d54b5702a820d5c779eb1216b05bdd8a0f779da2` 中、2026-09-10 文件选择器实验开始之前的 `runimage/setup_jriver.sh`。
- 该版本不包含 `gvfs`、GTK 文件选择器 schema override、`GIO_USE_VOLUME_MONITOR=unix`、`dbus-run-session`、`LD_PRELOAD` Patch 或额外 JRiver launcher。

重要：**该版本只能称为“代码回退版”，不能再称为“已验证稳定版”。** 用户实机确认，换回这份旧 RunImage 逻辑后，Rofi 启动 `mediacenter36` 仍然存在无 GUI 的问题。因此代码回退没有恢复此前实际可用的运行状态，根因仍未确认。

GitHub Actions 仍只使用：

```text
runimage/jriver-media-center/setup_jriver.sh
```

正常自动构建和 Latest Release 生成的是回退版 `mediacenter36`，不会把 `_test` 线覆盖到正式资产。**当前日常默认使用该 RunImage。**

### 当前使用方案

当前默认使用 `setup_jriver.sh` 构建的 **JRiver RunImage**。`jriver/` 目录下的两种 AppImage 打包方案暂时不作为日常使用版本，原因是实机启动速度较慢；相关脚本和修复记录继续保留，后续需要时再处理。RunImage 既有问题记录继续保留，不再为了这些历史故障修改原本正常的 Rofi、nwg-drawer 或宿主系统配置。

### 测试版

- 构建脚本：`setup_jriver_test.sh`
- 测试产物：`mediacenter36_test`
- Patch：`filechooser-empty-path_test.c`
- launcher：`jriver-filechooser-launch_test.sh`
- 问题记录：`TEST_ISSUE.md`

测试版保留 2026-09-10 对 GTK/GIO 文件选择器、GVFS、独立 session D-Bus 和 `LD_PRELOAD` Patch 的实验性修复链。它曾修复“打开媒体文件”时的空目录 / `Operation not supported` 弹窗，但同时观察到 Rofi 启动 JRiver 时“有后台进程、GUI 不显示”的严重回归。

后续又确认：即使把正式 `setup_jriver.sh` 回退到文件选择器实验前，Rofi 启动问题仍然存在。因此目前不能把该回归归因到测试版中的某一个具体 Patch。

## 目录文件

```text
jriver-media-center/
├── README.md
├── TEST_ISSUE.md
├── setup_jriver.sh
├── setup_jriver_test.sh
├── filechooser-empty-path_test.c
└── jriver-filechooser-launch_test.sh
```

## 回退版启动链

```text
RunImage
→ mediacenter36
→ /usr/bin/mediacenter36
```

没有额外 `dbus-run-session`、launcher 或 `LD_PRELOAD` 包装。

## 测试版启动链

```text
RunImage
→ dbus-run-session
→ /usr/local/bin/jriver-filechooser-launch_test
→ LD_PRELOAD=filechooser-empty-path_test.so
→ /usr/bin/mediacenter36
```

`setup_jriver_test.sh` 最后先用真实入口 `rim-build mediacenter36` 构建，再将产物改名为 `mediacenter36_test`，避免与回退版混淆。

## 维护规则

- `setup_jriver.sh` 当前只代表文件选择器实验前的代码回退线，不代表已经恢复实机稳定。
- 所有未确认的文件选择器、D-Bus、GVFS、`LD_PRELOAD` 兼容修改统一放在 `_test` 文件中。
- 不因为当前 RunImage 故障去修改已经长期正常的 Rofi、nwg-drawer、宿主 `/usr/local/bin/mediacenter36` 软链接或宿主系统环境。
- 后续定位必须同时比较“实际二进制/构建产物”和源码，不能只依据 Git 回退判断是否恢复。
- 问题现象、验证结果、失败尝试和后续定位范围统一更新到 `TEST_ISSUE.md`。

## 2026-09-23 自根目录原样迁入

以下原文来自当时根目录 `PENDING_AI_TASKS.md` 和 `README.md` 的「当前待处理」，未改写。

- JRiver RunImage 当前仍未解决。Rofi 启动 `mediacenter36` 时存在后台进程但 GUI 不显示；回退到文件选择器实验前的旧构建逻辑后仍然复现，因此不能把根因简单归到 GVFS、`dbus-run-session`、`LD_PRELOAD` 或 launcher 中的单一改动。
- 当前 RunImage 不作为日常使用基线。后续应从此前实际可用产物与当前产物、RunImage 版本、挂载环境、父进程环境、残留进程 / 会话状态等方向做对照。
- 详见 [README.md](./README.md) 与 [TEST_ISSUE.md](./TEST_ISSUE.md)。

- `runimage/jriver-media-center`：JRiver RunImage 当前仍未解决。Rofi 启动 `mediacenter36` 时存在后台进程但 GUI 不显示；回退到文件选择器实验前的旧构建逻辑后仍然复现，因此不能把根因简单归到 GVFS、`dbus-run-session`、`LD_PRELOAD` 或 launcher 中的单一改动。当前 RunImage 不作为日常使用基线。后续应从此前实际可用产物与当前产物、RunImage 版本、挂载环境、父进程环境、残留进程 / 会话状态等方向做对照。
