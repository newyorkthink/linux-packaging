# Modern CSV AppImage

## 用途

本目录将 Modern CSV Linux 稳定版重新封装为 AppImage，产物名固定为：

```text
moderncsv.AppImage
```

上游与打包参考：

- Modern CSV：`https://www.moderncsv.com/`
- 官方 Linux tar 包：`https://www.moderncsv.com/release/ModernCSV-Linux-v2.4.3.tar.gz`
- pkgforge-dev `quick-sharun`：`https://github.com/pkgforge-dev/Anylinux-AppImages`
- 官方说明：`https://github.com/pkgforge-dev/Anylinux-AppImages/blob/main/HOW-TO-MAKE-THESE.md`
- 仓库基线：`copyq/build_copyq.sh`

## 打包环境

Modern CSV 使用仓库统一的 Arch Linux / AnyLinux quick-sharun 构建环境。

`.github/workflows/build.yml` 中的 Modern CSV Job 与 CopyQ 等标准项目一样，直接复用：

```text
ghcr.io/pkgforge-dev/archlinux:latest
pkgforge-dev/anylinux-setup-action
.github/actions/build-anylinux
```

应用脚本本身不再启动额外 Docker / chroot，也不重复下载 quick-sharun。

## 打包流程

`build_moderncsv.sh` 保持普通 quick-sharun 项目的简单结构：

1. 设置 `STARTUPWMCLASS`、`ICON`、`DESKTOP`、`OUTPATH`、`OUTNAME`、`DEPLOY_OPENGL`。
2. 使用 `yay` 安装 quick-sharun 通用基础依赖，以及 Modern CSV 官方 Qt6 运行时需要的 OpenSSL、OpenGL、XKB / XCB 等非 Qt 系统依赖；不再安装 Arch 当前版本的 `qt6-base`、`qt6-5compat`、`fcitx5-qt`。
3. 下载官方 `ModernCSV-Linux-v2.4.3.tar.gz`，解压到 `AppDir` 外部的 `moderncsv-source/`，完整保留官方的 `moderncsv`、`moderncsv.desktop`、`moderncsv.png`、`lib/`、`plugins/`、`qt.conf` 等文件。
4. `ICON` 和 `DESKTOP` 直接指向官方包自带的 `moderncsv.png` 与 `moderncsv.desktop`；`QT_LOCATION` 指向官方源目录，使 quick-sharun 从同一套官方 Qt6 运行时和 plugin 树完成部署：

```bash
quick-sharun "$SOURCE_DIR/moderncsv"
```

5. 只在 `AppDir/.env` 补充当前需要的中文 locale 与 XCB 环境：

```text
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
QT_QPA_PLATFORM=xcb
```

6. 使用 `xvfb-run` 对生成的 `AppDir/AppRun` 做最小启动级 smoke test；程序正常退出或持续运行到 timeout 均视为启动通过，动态链接器 / Qt 初始化错误会直接使构建失败。
7. 最后执行：

```bash
quick-sharun --make-appimage
```

`quick-sharun` 负责常规 ELF、Qt plugin、动态依赖和 AppRun 生成，不在普通构建脚本里重复实现这些通用逻辑。

## Qt 与中文输入

Modern CSV 官方 Linux tar 包自带一整套 Qt 6 运行库和 plugin。当前打包必须优先保持这套运行时内部一致，不能再把 Arch 当前 Qt6 运行库或由当前 Qt6 构建的输入上下文 plugin 混入官方旧版 Qt6 运行时。

Qt5 与 Qt6 都有各自主版本对应的 Compose、Fcitx5、IBus 输入上下文；除了 Qt 主版本必须一致外，实际 plugin 还必须与最终 Qt runtime ABI 兼容。官方 tar 缺少某个输入上下文 plugin 时，应取得与该官方 Qt runtime 匹配的版本后再补入，不能仅为了凑齐文件名直接复制 Arch 当前 Qt6 plugin。

本脚本不设置 `LD_LIBRARY_PATH`、`QT_PLUGIN_PATH` 或 `QT_QPA_PLATFORM_PLUGIN_PATH`，避免人为覆盖 quick-sharun 和官方 Qt runtime 的正常搜索关系。

这里的中文环境只负责 UTF-8 locale 和 Linux 输入环境，不向 Modern CSV 注入非官方中文界面翻译。

## 特殊处理原则

CopyQ 中 `lib/copyq/plugins` 的符号链接修复属于 CopyQ 自身插件搜索行为，不复制到 Modern CSV。

普通程序默认保持“准备上游程序与依赖 -> 设置 quick-sharun 变量 -> quick-sharun 主程序 -> 必要 `.env` -> `--make-appimage`”这一条主线。只有程序出现能够明确定位的特有运行问题时，才增加对应的最小特殊处理，不预先加入重复 plugin 遍历、`ldd`、最终 AppImage 再提取或额外 wrapper。

## 修复记录

### 2026-09-02：改为直接复用官方 tar 包内 desktop / icon

- 故障现象：先前适配官方 tar 包时错误假设解压后的文件直接位于目标目录，并额外生成了新的 `moderncsv.desktop`，导致 quick-sharun 找不到预期的 `moderncsv.png`。
- 根因：官方 tar 包本身已经包含 `moderncsvv2.4.3/` 顶层目录以及完整的 `moderncsv.desktop`、`moderncsv.png`、主程序、`lib/`、`plugins/` 和 `qt.conf`，不应重复创建 desktop / icon，也不应丢失顶层目录层级信息。
- 修改文件：`moderncsv/build_moderncsv.sh`、`moderncsv/README.md`。
- 修复内容：直接复用官方 `moderncsv.desktop`、`moderncsv.png` 与真实主程序，不再生成替代 desktop / icon。
- 验证：构建流程已能够生成并发布 AppImage；后续真实运行验证发现 Qt runtime 混用问题，见下一条记录。

### 2026-09-02：隔离官方 Qt6 runtime，修复 GNU_PROPERTY 启动错误

- 故障现象：已发布的 `moderncsv.AppImage` 启动时在 `libQt6Widgets.so.6` 报 `direct reference to protected function ... may break pointer equality`，随后因 `GNU_PROPERTY_1_NEEDED_INDIRECT_EXTERN_ACCESS` 直接退出。
- 根因：官方 tar 已自带一套较旧 Qt6 runtime，而构建环境同时安装了 Arch Qt 6.11.2。quick-sharun 将 Arch Qt 6.11.2 部署到最终 `AppDir/lib`，同时又处理官方 tar 内的旧 Qt 库，形成两套 Qt runtime 混用；构建日志中官方运行库依赖 ICU 56，而 Arch Qt 6.11.2 使用 ICU 78。另一个放大问题是此前把整份官方 tar 直接放进 `AppDir/bin`，导致 quick-sharun 再次收集 `AppDir` 内源文件并产生重复的嵌套库路径。
- 修改文件：`moderncsv/build_moderncsv.sh`、`moderncsv/README.md`。
- 修复内容：官方 tar 改为解压到 `AppDir` 外部的独立 `moderncsv-source/`；设置 `QT_LOCATION` 指向该官方源目录；删除 Arch `qt6-base`、`qt6-5compat`、`fcitx5-qt` 依赖，只保留官方 Qt6 runtime 需要的非 Qt 系统库；增加一个最小 `xvfb-run` 启动 smoke test，动态链接器或 Qt 初始化失败时禁止发布。
- 验证：`build_moderncsv.sh` 已通过 `bash -n` 静态语法检查；完整 GitHub Actions 与新产物实际运行结果以本次提交后的构建为准。
