# KeePass AppImage 最终稳定基线

当前稳定基线日期：2026-07-28  
构建脚本：`keepass/build_keepass.sh`

## 已确认正常

- KeePass AppImage 可以正常启动、打开和保存数据库。
- 简体中文语言文件已打包，中文界面正常。
- Materia Light GTK2 浅色主题、Adwaita/Murrine GTK2 主题引擎正常。
- 思源黑体简体中文常规和粗体已打包；独立 Fontconfig 会把 Mono WinForms 的 `Microsoft Sans Serif` 和 `Tahoma` 映射到思源黑体。
- 查找框、备注区域和常用窗口中的中英文显示正常。
- Keebuntu GTK2 XEmbed 托盘插件正常，i3bar 托盘图标和右键菜单正常；不启动全局 `snixembed`。
- KPScript 继续通过 Arch Linux AUR 的 `kpscript` 软件包流程安装，`KPScript.exe` 和 wrapper 已打包。
- `libargon2.so.1`、`libgcrypt.so.20`、`libgpg-error.so.0` 等关键运行库已显式打包并在构建阶段检查。
- KeePassOTP 和 GlobalSearch 使用官方 PLGX，在构建阶段预编译为 DLL；目标电脑不需要在首次启动时编译 PLGX。
- 插件管理器可正常打开，插件列表不会再触发 Mono `ListView.UpdateMultiSelection` 越界异常。
- KeePassOTP、GlobalSearch 的选项页可以正常打开。
- Mono MessageBox 的“确定 / 取消 / 是 / 否”等按钮文字能够正常显示。
- 主界面左侧分组树鼠标滚轮正常。
- 选项列表、密码生成器预览和相关 Mono 滚动问题已修复。
- “最近修改 / 历史 / 较大记录”等记录列表窗口的横幅、工具栏和列表布局正常。
- “列设置”窗口在 i3 平铺状态下不会再发生列表与中间设置区域重叠。
- “选项 → 安全”在内容已全部显示时不会被错误滚动到无法恢复的位置。
- 已修复 Mono 下密码质量检查可能触发的比较器异常。
- KeePass 和 KPScript wrapper 已避免宿主命令误加载 AppImage 内 glibc 导致的 `GLIBC_PRIVATE` 报错。

## 已知限制

### i3 平铺标签焦点

打开 KeePass 的模态对话框后，通过鼠标点击 i3 容器顶部标题切换到同容器其他标签时，窗口可能只闪一下并立即回到 KeePass 对话框。

这是 Mono WinForms `ShowDialog` 在 X11 下的模态焦点限制。此前尝试解除 X11 modal/transient-owner 状态没有稳定解决，并可能影响“确定 / 取消”、窗口关闭和数据保存行为，因此最终稳定版不再强行修改该焦点机制。

处理方式：先关闭当前 KeePass 对话框，或使用“确定 / 取消”返回主界面后，再切换 i3 标签。

### KPScript 偶发下载失败

AUR 的 `kpscript` PKGBUILD 会从 KeePass 上游下载源文件。上游偶尔会临时拒绝 GitHub Actions 的请求，但链接并非永久失效。

出现下载失败时：

1. 不要手动下载 ZIP 或 `KPScript.exe`。
2. 不要修改下载源、增加镜像或绕过 AUR。
3. 等待约 30 分钟。
4. 重新运行一次 `keepass/build_keepass.sh`。

### 非致命运行输出

终端可能显示：

```text
WARNING: Glycin running without sandbox.
SendMessage (...)
```

当前确认这些输出不影响 KeePass、数据库、插件、托盘或界面功能。不要为了隐藏提示而重定向全部标准错误，否则会同时隐藏真正的 Mono 或插件错误。

## 2026-07-28 AppImage 沙盒检查

对用户提供的最新 `keepass.AppImage` 在隔离沙盒中完成了以下检查，未读取或修改用户真实数据库：

- AppImage 可成功提取，内部没有损坏的符号链接。
- KeePass、KPScript、中文语言文件、主题、字体和所有预期插件均存在。
- KeePass wrapper、KPScript wrapper 和 `AppRun.sh` 通过 Shell 语法检查。
- Fontconfig 对 `Microsoft Sans Serif` 和 `Tahoma` 的映射结果均为思源黑体。
- 在 Xvfb 独立显示环境和临时 HOME 下启动 12 秒无崩溃、无插件加载错误。
- 插件管理器实际显示 GtkStatusIcon、KeePassOTP、GlobalSearch、KPScript 和全部 Mono 兼容插件已经加载。
- “选项”、GlobalSearch 和 KeePassOTP 配置页可以打开并正常渲染。
- 新建数据库提示框的按钮文字能够正常显示。
- KPScript wrapper 可以启动并返回正常的“未指定命令”提示。

## 构建方式

在 GitHub Actions 的 `Build AppImages` 中选择：

```text
keepass/build_keepass.sh
```

不要选择 `all`，避免无关构建占用 Actions 时间。

## 稳定维护规则

- `keepass/build_keepass.sh` 中已验证的命令、参数、路径和执行顺序不得仅为格式美化而重排、拆分、合并或替换。
- 已确认正常的托盘、字体、主题、Fontconfig、wrapper、插件预编译和 Mono 兼容修复保持原样。
- `keepass/MonoI3TabFocusFix.cs` 保留旧文件名和构建入口，但最终代码只负责“列设置”窗口布局，不再尝试修复 i3 模态标签焦点。
- 修改前完整检查 `keepass/`、`keepass/build_keepass.sh`、`keepass/PrecompilePlgx.cs` 和 `.github/workflows/build.yml`。
- 提交前完成 Bash/C# 静态检查、最终 diff 核对，并确保只触发一次 KeePass 构建。
- 不使用 GitHub Actions 反复试错。
