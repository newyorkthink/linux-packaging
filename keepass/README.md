# KeePass AppImage 构建说明

最终稳定状态和完整验证记录见本目录的 [`KEEPASS_STABLE.md`](KEEPASS_STABLE.md)。

## 构建入口

在 GitHub Actions 的 `Build AppImages` 中选择：

```text
keepass/build_keepass.sh
```

启动后，Actions 运行名称显示为 `Build keepass.AppImage`。

不要选择 `all`，避免无关构建占用 Actions 时间。

## 当前组件

- `build_keepass.sh`：安装依赖、预编译插件、组装 AppDir 和生成 AppImage。
- `Chinese_Simplified.lngx`：KeePass 简体中文语言文件，由构建脚本打包到 AppImage。
- `KEEPASS_STABLE.md`：最终稳定基线、已验证功能、已知限制和维护规则。
- `GtkStatusIcon.sh`：下载并校验 Keebuntu GTK2 XEmbed 托盘插件。
- `PrecompilePlgx.cs`：在构建阶段预编译 KeePassOTP 和 GlobalSearch 的 PLGX 插件。
- `KeePassWindowLayoutFix.cs`：修复选项、插件管理器和通用 KeePass 对话框的平铺布局，并保留已验证的 Mono 模态处理。
- `MonoMouseWheelFix.cs`：修复选项列表、密码生成器预览滚动及 Mono 密码质量比较器异常。
- `MonoMainTreeFix.cs`：修复主界面左侧分组树鼠标滚轮。
- `MonoMessageBoxFix.cs`：修复 Mono MessageBox 按钮文字为空。
- `MonoListViewFormLayoutFix.cs`：修复“最近修改 / 历史 / 较大记录”等列表窗口布局。
- `MonoI3TabFocusFix.cs`：保留旧文件名以避免改动构建入口；最终只修复“列设置”窗口平铺布局，不再尝试解除 i3 模态焦点。

## KPScript 临时下载失败

KPScript 始终通过 Arch Linux AUR 的 `kpscript` 软件包流程构建和安装。AUR 的 PKGBUILD 会从 KeePass 上游获取源文件；该下载偶尔会临时失败，不表示地址永久失效。

出现 KPScript 下载报错时：

1. 不要手动下载 ZIP 或 `KPScript.exe`。
2. 不要修改下载源，也不要增加镜像、缓存或绕过 AUR。
3. 等待约 30 分钟。
4. 重新运行一次 `keepass/build_keepass.sh`。

## 已知限制

KeePass 的模态对话框打开时，鼠标点击 i3 容器顶部标题可能无法切换到同容器其他标签。这是 Mono WinForms `ShowDialog` 的 X11 模态焦点限制。最终稳定版不再强行解除该限制，避免破坏“确定 / 取消”、关闭窗口或保存数据。

先关闭当前对话框，或使用“确定 / 取消”返回主界面后，再切换 i3 标签。

## 已知非致命输出

运行时可能显示：

```text
WARNING: Glycin running without sandbox.
SendMessage (...)
```

这些输出目前不影响 KeePass、数据库、插件、托盘或界面功能。不要为了隐藏提示而重定向全部标准错误，否则会同时隐藏真正的 Mono 或插件错误。

## 构建隔离

KeePass 必须保持独立 Job / 独立 Arch Linux 容器构建，避免其他项目安装的依赖被 `quick-sharun`、动态依赖扫描或通配符误打包进 KeePass AppImage。

以前曾出现 KDE Suite 安装的 Qt6、KF6、Mesa 和 LXQt 相关库被后续 KeePass 构建误收集，导致 KeePass AppImage 从约 120 MB 增长到约 225 MB。因此 KeePass 不与其他 AppImage 项目共用构建容器。

## 维护原则

- 已经实机确认的命令、参数、执行顺序、打包路径、插件、主题、字体、Fontconfig 和 wrapper 不为格式美化而改写。
- 各 Mono 兼容修复保持独立，只修改明确对应的问题。
- 修改前完整检查相关源码、构建脚本和工作流；提交前完成静态检查及最终 diff 核对。
- 不把 GitHub Actions 当作基础错误的试运行环境。
