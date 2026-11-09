# Android Tools 模板差异

本文记录 [当前构建脚本](../build_android-tools.sh) 相对 [quick-sharun 标准模板](../../templates/README.md#quick-sharun) 的真实差异。上游原文与取舍见 [pkgforge-differences.md](./pkgforge-differences.md)，固定参数的依据见 [hardcoded.md](./hardcoded.md)。本文件不参与构建，不将专用流程扩展为新的公共模板。

## 来源与模板适用边界

当前程序来自 Google 官方预编译 `platform-tools-latest-linux.zip`。现有 `arch-native.sh` 适用于安装 Arch 官方软件包后直接收集 `/usr/bin/<主程序>`；该路线无法原样表示本项目保留独立 ZIP、图标和 PATH hook 的流程。其他登记模板面向 DEB、Electron、Qt 等不同来源，同样不覆盖此完整流程。

本项目已在 [官方预编译 ZIP 命令行工具](../../docs/packaging-classification.md#用-quick-sharun-打包的官方预编译-zip-命令行工具) 分类登记。继续维护已有入口，不新增模板、不批量改动其他程序；今后修改构建脚本仍须遵守仓库生成器规则。

## 实际保留的专属处理

| 阶段 | 当前专属处理 | 原因与影响 |
| --- | --- | --- |
| 工作目录 | 先定位 `SCRIPT_DIR` 并切换到应用目录，清理 `dist`、`platform-tools`、`bin.zip` 和 `AppDir/etc` | 清理范围限于该应用构建目录；保留既有图标、许可证和 `AppDir/bin` 中的 PATH hook。不会删除整个 `AppDir`。 |
| 保留 hook | 从 `AppDir/bin` 删除旧内容，但排除 `make-symlinks-in-path.hook` | 该文件是打包前已有的独立脚本，由上游原样复制；不保留旧的 `adb`、`fastboot` 二进制。 |
| 精简环境 | 使用 Actions 容器内的 `get-debloated-pkgs --add-common --prefer-nano ! mesa ! vulkan` | 沿用上游及本仓库此前成功构建的命令，排除 Mesa、Vulkan；不是要在用户系统中额外安装软件包。 |
| 依赖恢复 | 精简后执行原有 `yay -S --noconfirm` 最小基础包命令 | 早期 Actions 已出现 `unzip`、`patchelf` 缺失；顺序必须是先精简、再恢复。 |
| 官方资源 | 公共下载入口取得最新 Google Linux ZIP，公共归档入口解压，之后移动 `platform-tools/*` 到 `AppDir/bin` | 保留完整命令行工具，区别于直接收集系统 `/usr/bin/adb`；不通过系统安装的 `android-tools` 包替换官方 ZIP。 |
| 图标与入口 | 保留 `AppDir/.DirIcon`、`AppDir/android-tools.png`；使用 `APPNAME=android-tools`、`MAIN_BIN=adb`、`DESKTOP=DUMMY` | 命令行 AppImage 仍有图标；由 quick-sharun 生成隐藏的 dummy desktop，主程序选择 `adb`。 |
| 更新信息 | 保留当前 `UPINFO`，指向本仓库 `latest` 的固定 zsync 文件名 | 仅保留既有更新元数据；没有启用自动更新 hook。 |
| 版本 | 由现有 `awk` 从 `AppDir/bin/source.properties` 解析 `Pkg.Revision` | 当前公共版本读取入口不支持 `properties` 模式，不能替换为未实现的接口；版本为空时退出。 |
| 依赖收集 | `quick-sharun ./AppDir/bin/*`，随后 `quick-sharun --make-appimage` | 一次收集 `adb`、`fastboot` 等已解压的工具及其运行库，保留已有 PATH hook。 |
| 版本产物 | `common/build/save_appimage_version.sh` 检查 AppImage 非空并写 `dist/version.txt` | 复用已有公共保存入口，不新增独立测试或产物检查段。 |

## 文件保留范围

| 文件 | 当前用途 |
| --- | --- |
| `AppDir/.DirIcon` | AppImage 根图标；quick-sharun 会优先使用现有文件。 |
| `AppDir/android-tools.png` | 与 `.DirIcon` 内容相同的 PNG 图标，作为包内图标资源保留。 |
| `AppDir/bin/make-symlinks-in-path.hook` | 用户显式以 `--make-symlinks` 调用时，为多种平台工具命令建立指向 AppImage 的符号链接；其内容保留上游版本。 |
| `LICENSE` | 上游打包仓库的 GPL-3.0 许可证文本，作为来源合规记录保留；不代替 Google 平台工具自身的授权条件。 |

## 已知边界与验证

当前不设置 `ADD_HOOKS=udev-installer.hook`，不随包下载或安装 udev 规则，不新增 GTK、Qt、输入法或 GUI locale，也不加入 `quick-sharun --simple-test`。这些未启用处理的原文及依据见 [上游取舍](./pkgforge-differences.md)。

历史 Actions 曾报告精简后缺少 `unzip`、`patchelf`；恢复依赖后通过构建。后来移除自动 udev 安装，已有 [成功构建和实机记录](../README.md#修复记录)。本次文档仅描述现有脚本，未执行新的构建或运行验证。
