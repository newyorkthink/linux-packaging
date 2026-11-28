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

- `build_keepass.sh`：通过公共入口安装依赖、下载插件、读取版本并封装 AppImage。
- `Chinese_Simplified.lngx`：KeePass 简体中文语言文件，由构建脚本打包到 AppImage。
- `KEEPASS_STABLE.md`：最终稳定基线、已验证功能、已知限制和维护规则。
- `GtkStatusIcon.sh`：安装已解包的 Keebuntu GTK2 XEmbed 托盘插件，并设置优先加载位置。
- `patches/prepare_plugins.sh`：预编译 PLGX 和六份 Mono 兼容补丁。
- `patches/prepare_appdir.sh`：部署中文语言、字体和 Fontconfig，检查 AppDir 内容并写入两个启动脚本。
- `PrecompilePlgx.cs`：在构建阶段预编译 KeePassOTP 和 GlobalSearch 的 PLGX 插件。
- `KeePassWindowLayoutFix.cs`：修复选项、插件管理器和通用 KeePass 对话框的平铺布局，并保留已验证的 Mono 模态处理。
- `MonoMouseWheelFix.cs`：修复选项列表、密码生成器预览滚动及 Mono 密码质量比较器异常。
- `MonoMainTreeFix.cs`：修复主界面左侧分组树鼠标滚轮。
- `MonoMessageBoxFix.cs`：修复 Mono MessageBox 按钮文字为空。
- `MonoListViewFormLayoutFix.cs`：修复“最近修改 / 历史 / 较大记录”等列表窗口布局。
- `MonoI3TabFocusFix.cs`：保留旧文件名以避免改动构建入口；最终只修复“列设置”窗口平铺布局，不再尝试解除 i3 模态焦点。

## 专用打包流程

KeePass 使用 Arch 官方发行的 Mono 程序。GTK2 依赖按顺序分层安装，扫描前预编译插件，扫描后部署运行配置。公共安装、版本和封装步骤按现有标准衔接。六份 C# 补丁沿用原路径和编译方式，详细执行阶段见[模板差异](./docs/template-deviations.md)。

## 实机验证

### 2026-11-28：用户实机验证通过

用户已确认 KeePass AppImage 实机验证通过。

| 实测项目 | 通过结果 |
| --- | --- |
| AppImage 启动 | 正常打开 KeePass 主界面。 |
| 简体中文界面 | 主界面菜单正常显示简体中文。 |
| 中文输入法 | 在工具栏输入框输入时，正常显示中文候选词。 |

## KPScript 临时下载失败

KPScript 由 Arch Linux AUR 的 `kpscript` 软件包安装。公共入口从本次实际 `PKGBUILD` 取得 ZIP 地址和 SHA-256，通过 KeePass 官网的同域同路径 HTTPS 下载，摘要通过后交给同一份配方复核和安装。网络错误沿用公共下载器的有限重试。首次发生摘要不符时，等待 30 分钟后在新的临时下载目录重新获取一次。地址前缀、间隔和原有记录见[固定配置](./docs/hardcoded.md#kpscript-重试间隔)。

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

## 版本元数据接入（2026-09-16）

- 构建时从本次实际安装的 Arch `keepass` 包读取版本，去掉 Arch epoch 与 pkgrel 后写入根构建目录的 `dist/version.txt`。
- workflow 使用 `SOFTWARE_KEY=keepass` 接入统一 `software_versions.json`。
- 现有 KeePass 稳定依赖、插件、主题、字体、Fontconfig、Mono 兼容修复和 wrapper 均保持不变。

## GTK2 依赖分层安装修复（2026-10-18）

- 对应提交：[`8afc120`](https://github.com/newyorkthink/linux-packaging/commit/8afc120d3f5cd7ec95168b012df8c67d35e40be0)。
- 故障现象：`gtk-sharp-2`、`gtk-engine-murrine` 和 `gtk-engines` 因缺少 `gtk2` 构建失败，报 `Could not resolve all dependencies`（退出码 8）；`gnome-themes-extra-gtk2` 又因缺少 `gtk-engines` 构建失败。
- 原因：同一条 `yay` 命令中，前一层依赖编译完成后仍在安装队列中，后一层的 `makepkg` 只检查已经安装的包，无法使用尚未安装的依赖。
- 修复内容：`keepass/build_keepass.sh` 先安装 `gtk2`，再安装 `gtk-sharp-2`、`gtk-engine-murrine` 和 `gtk-engines`，最后安装 KeePass、`gnome-themes-extra-gtk2` 及其余依赖；三步均保留 `--noconfirm --needed`。
- 验证结果：用户已确认该提交的修复有效，分层安装的命令、参数和执行顺序作为已验证基线保留。
