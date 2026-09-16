# QEMU AppImage

## 用途与产物

本目录构建用于 x86_64 桌面虚拟机的 QEMU AppImage，固定发布资产为 `qemu.AppImage`。程序来自 Arch Linux 官方仓库中的当前稳定版 `qemu-desktop`、`qemu-tools`、`qemu-ui-gtk` 和 `virt-viewer`，不再跟随 QEMU 上游 `master` 现场编译。

## 技术栈

- QEMU：C / C++ 原生虚拟机与硬件模拟器。
- 图形与显示：GTK、OpenGL、SPICE。
- 辅助工具：`qemu-img`、`qemu-io`、`qemu-nbd`、`remote-viewer`。
- 构建架构：x86_64。
- 打包环境：Arch Linux container。

## 打包方式

`build_qemu.sh` 使用 quick-sharun：

1. 安装仓库规定的最小打包工具。
2. 从 Arch Linux 官方仓库动态安装当前稳定版 QEMU 桌面组件，并显式安装 `qemu-ui-gtk`。
3. 按 pkgforge-dev/QEMU-AppImage 的官方形式，把 `/usr/bin/qemu-*`、`/usr/lib/qemu/*.so` 和 `/usr/share/qemu` 直接交给 quick-sharun；另收集本目录需要的 `remote-viewer`。
4. 完全使用 quick-sharun 自动生成的 sharun 入口，在执行路径映射 Hook 后按 AppImage 链接名或第一个参数分派 `qemu-system-x86_64`、`qemu-img` 等工具。
5. 在 quick-sharun 的翻译裁剪完成后补回 `zh_CN/LC_MESSAGES/virt-viewer.mo`，并在 `AppDir/.env` 设置 `LANGUAGE=zh_CN`，随后生成 `dist/qemu.AppImage`。

`qemu.desktop` 与 `qemu.svg` 是 AppImage 元数据输入，分别由 `DESKTOP` 和 `ICON` 引用。两者需要保留在本目录，但不参与 QEMU 运行依赖收集，也不需要单独构建或额外补一份。

正式入口为 `.github/workflows/build.yml` 中独立的 `Build QEMU` Job，只更新 `latest` Release 的 `qemu.AppImage`。

## 使用

在包含 AppImage 的当前目录执行：

```bash
# 添加执行权限。
chmod +x qemu.AppImage

# 查看 QEMU 版本。
./qemu.AppImage qemu-system-x86_64 --version

# 创建 x86_64 虚拟机主程序入口。
ln -sf ./qemu.AppImage qemu-system-x86_64

# 创建磁盘镜像管理工具入口。
ln -sf ./qemu.AppImage qemu-img

# 创建磁盘镜像 I/O 工具入口。
ln -sf ./qemu.AppImage qemu-io

# 创建 NBD 磁盘导出工具入口。
ln -sf ./qemu.AppImage qemu-nbd

# 创建 SPICE 图形客户端入口。
ln -sf ./qemu.AppImage remote-viewer

# 通过软链接查看 QEMU 版本。
./qemu-system-x86_64 --version

# 创建 QCOW2 磁盘。
./qemu.AppImage qemu-img create -f qcow2 disk.qcow2 30G

# 启动 x86_64 虚拟机。
./qemu.AppImage qemu-system-x86_64 -enable-kvm -cpu host -m 4G -drive file=disk.qcow2,format=qcow2
```

以上软链接必须与 `qemu.AppImage` 位于同一目录。quick-sharun 会根据软链接名称分派对应程序，不需要复制 AppImage：`qemu-system-x86_64` 用于启动虚拟机，`qemu-img`、`qemu-io`、`qemu-nbd` 用于磁盘镜像处理，`remote-viewer` 用于 SPICE 连接。`qemu-ga` 是安装并运行在客户机中的代理，不作为宿主日常入口创建软链接。

### GTK 主客机剪贴板

旧仓库发布的 AppImage 带有 `AppRun.wrapper`，会在用户没有显式设置 `clipboard=` 时自动给 GTK display 补充 `clipboard=on`，所以原命令即使只写 `-display gtk,...` 也能共享剪贴板。

当前构建按 pkgforge-dev/QEMU-AppImage 的官方 quick-sharun 方式生成入口，不保留旧包装器，也不在 AppImage 内改写用户参数。这不是 QEMU、GTK 或 SPICE 依赖缺失；使用当前 AppImage 时，应在原启动命令中把 display 参数明确写为：

```bash
-display gtk,clipboard=on,show-menubar=off,full-screen=off
```

原命令中已经存在的 `-chardev qemu-vdagent,...,clipboard=on`、`com.redhat.spice.0` virtserialport 和其他参数保持不变。相同客户机使用旧 AppImage 已能共享剪贴板时，无需另外修改客户机。

### remote-viewer 简体中文界面

使用 Arch 官方 `virt-viewer` 包自带的简体中文翻译；quick-sharun 仍负责原有翻译路径映射和 GTK 公共翻译部署。只补回程序名与翻译域不一致而被裁剪的 `virt-viewer.mo`，不增加软件包、不安装输入法、不改变客户机配置，也不修改宿主的 `LANG` 或 `LC_ALL`。上游尚未翻译的文字仍可能显示英文。

## 运行与兼容说明

- KVM 加速依赖宿主提供 `/dev/kvm`，并允许当前用户访问。
- TAP、桥接网络和系统级 SPICE / libvirt 配置仍由宿主负责；AppImage 不修改 `/etc`、不加载内核模块、不调整用户组。
- 默认启动 `qemu-system-x86_64`；把受支持的 `qemu-*` 工具名作为第一个参数即可调用对应工具。
- `ln -sf` 只用于按链接名选择 QEMU 子程序，与 GTK 模块加载和剪贴板开关无关。
- `WARNING: Glycin running without sandbox.` 是图像加载组件警告，不表示 GTK backend 或剪贴板通道缺失。
- 2026-09-13 第四次实机反馈确认：回归 quick-sharun 官方入口后的 AppImage 已能通过软链接启动 GTK 虚拟机；旧包使用相同命令能共享剪贴板，是因为旧 `AppRun.wrapper` 自动补充了 GTK `clipboard=on`，并非当前包缺少 SPICE。

## 变更记录

### 2026-09-13：改用 Arch 官方包与 quick-sharun

- 原问题：旧仓库直接编译 QEMU 上游 `master`，2026-09-13 因上游代码在 `-Werror` 下出现未使用函数而再次失败；此前也曾因 Python 版本与模块要求变化失败。
- 根因：构建持续跟随开发分支源码和构建依赖变化，故障发生在 QEMU 编译阶段，并非 AppImage 最终封装阶段。
- 修改文件：`qemu/build_qemu.sh`、`qemu/AppRun`、`qemu/qemu.desktop`、`qemu/qemu.svg`、`qemu/README.md`、`.github/workflows/build.yml`。
- 修复：停止现场编译上游 `master`，改用 Arch 官方当前稳定包并由 quick-sharun 收集依赖；保留多工具入口和 GTK 剪贴板处理。
- 已知结果：旧方案 2026-09-07 构建曾成功，2026-09-13 定时构建失败；新链路随后完成 Actions 构建，后续 GTK、入口和剪贴板问题按下列记录逐项修复，最终实机结果见文末。

### 2026-09-13：补齐 GTK 显示模块

- 故障现象：使用 `-display gtk,show-menubar=off,full-screen=off` 启动时，QEMU 报错 `Display 'gtk' is not available`。
- 根因：Arch 将 GTK backend 放在 `qemu-ui-gtk` 的 `/usr/lib/qemu/ui-gtk.so` 中；原脚本只把 `/usr/lib/qemu` 目录作为 quick-sharun 输入，没有逐个部署动态模块，成品未获得可加载的 GTK backend。
- 修改文件：`qemu/build_qemu.sh`、`qemu/README.md`。
- 修复：显式安装 `qemu-ui-gtk`，要求 `ui-gtk.so` 必须存在，并将 `/usr/lib/qemu/*.so` 全部作为 quick-sharun 输入；原有 AppRun 和 GTK 剪贴板参数处理保持不变。
- 已知结果：Arch 官方包清单确认 `qemu-ui-gtk` 提供 `ui-gtk.so`，pkgforge-dev 的 QEMU quick-sharun 构建同样逐个传入 `/usr/lib/qemu/*.so`；随后 Actions 产物确认模块已进入 AppImage，但入口路径映射仍需按下一条记录修复。

### 2026-09-13：恢复 sharun 入口与 QEMU 模块路径映射

- 故障现象：显式加入 `qemu-ui-gtk` 和 `/usr/lib/qemu/*.so` 后，Actions 构建成功并发布了新产物，但实机仍报 `Display 'gtk' is not available`。
- 根因：构建日志确认 `ui-gtk.so` 已部署到 `AppDir/lib/qemu/ui-gtk.so`，同时检测到 QEMU 二进制硬编码 `/usr/lib/qemu`。原脚本随后用自定义脚本覆盖了 quick-sharun 生成的 `AppDir/AppRun`，导致 sharun 及 `01-path-mapping-hardcoded.hook` 未执行，模块存在但 QEMU 无法按映射路径加载。
- 修改文件：`qemu/build_qemu.sh`、`qemu/README.md`。
- 修复：保留 quick-sharun 生成的 sharun `AppDir/AppRun`，仅把现有 QEMU 多工具入口安装为 `AppDir/AppRun.sh`；原启动参数、GTK 剪贴板逻辑和已部署模块保持不变，不要求在宿主系统创建 `/usr/lib/qemu` 链接。
- 已知结果：路径映射方向与 quick-sharun 入口规范一致；随后实机发现自定义 `AppRun.sh` 的 POSIX shell 兼容问题，并按下一条记录移除。

### 2026-09-13：移除自定义入口并回归 quick-sharun 官方分派

- 故障现象：通过指向 AppImage 的 `qemu-system-x86_64` 软链接启动时，`AppRun.sh` 第 6 行报 `Syntax error: "(" unexpected`。
- 根因：quick-sharun 由可用的 POSIX shell 执行 `AppRun.sh`，原自定义入口却使用 Bash 数组，二者不兼容；该自定义入口同时重复实现了 quick-sharun 已原生提供的链接名和首参数分派。
- 修改文件：`qemu/build_qemu.sh`、`qemu/README.md`，删除 `qemu/AppRun`。
- 修复：不再覆盖或提供 `AppRun.sh`，完全保留 quick-sharun 自动生成的 sharun 入口、路径映射 Hook 和多工具分派；继续部署 `/usr/lib/qemu/*.so`，用户可以继续用 `ln -sf ./qemu.AppImage qemu-system-x86_64`。
- 已知结果：当前实现已对齐 pkgforge-dev/QEMU-AppImage 的 quick-sharun 入口方式；随后实机反馈确认 GTK 虚拟机已能正常启动。

### 2026-09-13：校正 GTK 剪贴板用法并统一构建风格

- 故障现象：GTK 虚拟机已能启动，但宿主与客户机不能共享剪贴板。
- 根因：启动命令启用了 `qemu-vdagent` chardev，却仍使用 `-display gtk,show-menubar=off,full-screen=off`；QEMU 官方文档明确 GTK `clipboard` 默认关闭。
- 检查范围：完整复核根目录 `AGENTS.md`、当前 QEMU 实现、`copyq`、`simplescreenrecorder`、`smplayer` 三个 quick-sharun 构建，以及 pkgforge-dev/QEMU-AppImage 的当前脚本。
- 修改文件：`qemu/build_qemu.sh`、`qemu/README.md`。
- 修复：文档中的 GTK 启动方式明确改为 `-display gtk,clipboard=on,...`，说明客户机 SPICE VDAgent 条件；构建脚本按仓库规范增加中文阶段标题，并把 QEMU 程序、模块和数据目录收敛为 pkgforge 官方的直接 quick-sharun 输入形式。
- 已知结果：入口、GTK 模块和软链接分派已由实机确认；显式加入 GTK `clipboard=on` 后，剪贴板也已完成实机确认。

### 2026-09-13：移除非必要构建检查并澄清剪贴板差异

- 故障现象：构建脚本在 quick-sharun 前后加入了程序、`ui-gtk.so` 和 `AppDir/AppRun` 的额外存在性检查；剪贴板说明没有解释旧 AppImage 使用相同命令仍能工作的原因。
- 根因：这些防御性检查不是 pkgforge-dev/QEMU-AppImage 官方最短打包链路的一部分；旧包的剪贴板行为来自 `AppRun.wrapper` 自动补充 GTK `clipboard=on`，而不是额外的 SPICE 依赖。
- 修改文件：`qemu/build_qemu.sh`、`qemu/README.md`。
- 修复：删除 `required_binaries` 循环、`ui-gtk.so` 单文件检查和 `AppDir/AppRun` 检查；保留已确认需要的 `qemu-ui-gtk` 与 `/usr/lib/qemu/*.so` 收集；将剪贴板说明改为当前官方入口所需的显式 GTK 参数。
- 已知结果：脚本保持 quick-sharun 官方直接收集与生成入口方式，未新增 AppRun、wrapper 或测试代码；实机确认 KVM、GTK、剪贴板、9P 共享目录和 `qemu-system-x86_64` 软链接入口均正常。

### 2026-09-13：最终稳定版实机确认

- 验证对象：当前 Arch 稳定包与 quick-sharun 构建路线生成的 `qemu.AppImage`。
- 实机结果：使用 `-enable-kvm -cpu host` 成功启动虚拟机，KVM 加速有效；GTK 窗口、显式启用的主客机剪贴板、virtio-9p 共享目录和 `qemu-system-x86_64` 软链接入口均正常。
- 最终结论：当前正式构建不需要增加其他软件包，不需要自定义 AppRun 或 wrapper；继续保留 `qemu-desktop`、`qemu-tools`、`qemu-ui-gtk`、`virt-viewer` 及现有 quick-sharun 输入。
- 稳定基线：后续没有新的构建日志或真实运行错误时，不得修改当前构建脚本、依赖列表、入口方式和已确认命令。

### 2026-09-13：补回 remote-viewer 简体中文翻译

- 故障现象：Linux 实机反馈 remote-viewer 可以连接远程桌面，但客户端菜单和快捷键界面显示英文。
- 根因：Arch 官方包包含 `zh_CN/LC_MESSAGES/virt-viewer.mo`；当前 quick-sharun 的 `_deploy_locale` 按已部署程序和 desktop 名称裁剪翻译，`remote-viewer` 与 `virt-viewer` 翻译域不匹配。原构建未在裁剪后补回该文件；此次未提取旧 AppImage，不能仅凭截图排除运行时语言环境的影响。
- 修改文件：`qemu/build_qemu.sh`、`qemu/README.md`。
- 修复：依赖收集后、最终封装前补回这一份官方简体中文翻译，并向 `AppDir/.env` 写入 `LANGUAGE=zh_CN`；保留原有 quick-sharun 路径映射、GTK 公共翻译、依赖列表、启动参数及 workflow，不增加 Fcitx5、IBus 或自定义入口。
- 已知结果：已核对 Arch 官方文件清单、quick-sharun 翻译裁剪与路径映射实现，并完成仓库外 Bash 语法和完整差异检查；提交后不监控 Actions，新产物中文界面仍待正式构建和 Linux 实机验证。

## 2026-09-16：接入统一软件版本元数据

- 构建时从本次实际安装的 Arch `qemu-desktop` 包读取 QEMU 软件版本，去掉 Arch epoch 与 pkgrel 后写入 `dist/version.txt`。
- workflow 使用 `SOFTWARE_KEY=qemu` 接入统一 `software_versions.json`。
- 本次不改变当前已验证的 Arch 稳定包、quick-sharun、多工具入口、GTK 模块、SPICE 或 remote-viewer 中文基线。
