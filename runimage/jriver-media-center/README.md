# JRiver Media Center RunImage

本目录用于维护 JRiver Media Center RunImage。当前明确分为“正式稳定版”和“测试版”，两条线不得混用。

## 当前状态

### 正式稳定版

- 构建脚本：`setup_jriver.sh`
- 发布产物：`mediacenter36`
- 基线来源：提交 `d54b5702a820d5c779eb1216b05bdd8a0f779da2` 中、2026-09-10 文件选择器修复开始之前的 `runimage/setup_jriver.sh`。
- 该版本不包含 `gvfs`、GTK 文件选择器 schema override、`GIO_USE_VOLUME_MONITOR=unix`、`dbus-run-session`、`LD_PRELOAD` Patch 或额外 JRiver launcher。
- 目的：恢复此前可从终端、Rofi 等入口正常拉起 JRiver GUI 的简单启动链。

GitHub Actions 仍只使用：

```text
runimage/jriver-media-center/setup_jriver.sh
```

因此正常自动构建和 Latest Release 只会生成正式 `mediacenter36`，不会把测试版覆盖到正式资产。

### 测试版

- 构建脚本：`setup_jriver_test.sh`
- 测试产物：`mediacenter36_test`
- Patch：`filechooser-empty-path_test.c`
- launcher：`jriver-filechooser-launch_test.sh`
- 问题记录：`TEST_ISSUE.md`

测试版保留 2026-09-10 对 GTK/GIO 文件选择器、GVFS、独立 session D-Bus 和 `LD_PRELOAD` Patch 的实验性修复链。它已经能修复“打开媒体文件”时的空目录/`Operation not supported` 弹窗，但仍存在 Rofi 启动 JRiver 时“有后台进程、GUI 不显示”的未解决问题，因此不得作为正式发布基线。

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

## 正式版构建

正式版保持旧启动方式：

```text
RunImage
→ mediacenter36
→ /usr/bin/mediacenter36
```

没有额外 `dbus-run-session` 或 launcher 包装。

## 测试版构建

测试版当前启动方式：

```text
RunImage
→ dbus-run-session
→ /usr/local/bin/jriver-filechooser-launch_test
→ LD_PRELOAD=filechooser-empty-path_test.so
→ /usr/bin/mediacenter36
```

`setup_jriver_test.sh` 最后先用真实入口 `rim-build mediacenter36` 构建，再将产物改名为 `mediacenter36_test`，避免与正式版混淆。

## 维护规则

- `setup_jriver.sh` 作为正式稳定线，除非新的修改经过 Linux 实机完整验证，否则不得把测试逻辑合回正式版。
- 所有未确认的文件选择器、D-Bus、GVFS、`LD_PRELOAD` 兼容修改统一放在 `_test` 文件中。
- 不因为当前测试版故障去修改已经长期正常的 Rofi、nwg-drawer、宿主 `/usr/local/bin/mediacenter36` 软链接或宿主系统环境。
- 测试版只有在终端、Rofi、nwg-drawer 等实际启动入口均验证通过后，才允许考虑替换正式版。
- 问题现象、验证结果、失败尝试和后续定位范围统一更新到 `TEST_ISSUE.md`。
