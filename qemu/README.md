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
3. 一次收集现有 `/usr/bin/qemu-*`、`remote-viewer`、`/usr/lib/qemu/*.so` 模块和固件数据目录。
4. 保留 quick-sharun 生成的 sharun `AppRun`，把本目录入口安装为 `AppRun.sh`，在路径映射 Hook 执行后支持 `qemu-system-x86_64`、`qemu-img` 等多工具分派。
5. 对 GTK 显示参数保留 `clipboard=on` 自动补充逻辑。
6. 由 quick-sharun 生成 `dist/qemu.AppImage`。

正式入口为 `.github/workflows/build.yml` 中独立的 `Build QEMU` Job，只更新 `latest` Release 的 `qemu.AppImage`。

## 使用

在包含 AppImage 的当前目录执行：

```bash
# 添加执行权限。
chmod +x qemu.AppImage

# 查看 QEMU 版本。
./qemu.AppImage qemu-system-x86_64 --version

# 创建 QCOW2 磁盘。
./qemu.AppImage qemu-img create -f qcow2 disk.qcow2 30G

# 启动 x86_64 虚拟机。
./qemu.AppImage qemu-system-x86_64 -enable-kvm -cpu host -m 4G -drive file=disk.qcow2,format=qcow2
```

## 运行与兼容说明

- KVM 加速依赖宿主提供 `/dev/kvm`，并允许当前用户访问。
- TAP、桥接网络和系统级 SPICE / libvirt 配置仍由宿主负责；AppImage 不修改 `/etc`、不加载内核模块、不调整用户组。
- 默认启动 `qemu-system-x86_64`；把受支持的 `qemu-*` 工具名作为第一个参数即可调用对应工具。
- 2026-09-13 第二次实机反馈确认：`ui-gtk.so` 已打入成品，但自定义入口覆盖 sharun 后未执行路径映射 Hook，仍会报 GTK display backend 不可用；当前入口修复后的新产物待 Actions 构建和 Linux 实机确认。

## 变更记录

### 2026-09-13：改用 Arch 官方包与 quick-sharun

- 原问题：旧仓库直接编译 QEMU 上游 `master`，2026-09-13 因上游代码在 `-Werror` 下出现未使用函数而再次失败；此前也曾因 Python 版本与模块要求变化失败。
- 根因：构建持续跟随开发分支源码和构建依赖变化，故障发生在 QEMU 编译阶段，并非 AppImage 最终封装阶段。
- 修改文件：`qemu/build_qemu.sh`、`qemu/AppRun`、`qemu/qemu.desktop`、`qemu/qemu.svg`、`qemu/README.md`、`.github/workflows/build.yml`。
- 修复：停止现场编译上游 `master`，改用 Arch 官方当前稳定包并由 quick-sharun 收集依赖；保留多工具入口和 GTK 剪贴板处理。
- 已知结果：旧方案 2026-09-07 构建曾成功，2026-09-13 定时构建失败；本次新链路仅完成静态核对，构建及实机结果待正式 Actions 和真实运行反馈确认。

### 2026-09-13：补齐 GTK 显示模块

- 故障现象：使用 `-display gtk,show-menubar=off,full-screen=off` 启动时，QEMU 报错 `Display 'gtk' is not available`。
- 根因：Arch 将 GTK backend 放在 `qemu-ui-gtk` 的 `/usr/lib/qemu/ui-gtk.so` 中；原脚本只把 `/usr/lib/qemu` 目录作为 quick-sharun 输入，没有逐个部署动态模块，成品未获得可加载的 GTK backend。
- 修改文件：`qemu/build_qemu.sh`、`qemu/README.md`。
- 修复：显式安装 `qemu-ui-gtk`，要求 `ui-gtk.so` 必须存在，并将 `/usr/lib/qemu/*.so` 全部作为 quick-sharun 输入；原有 AppRun 和 GTK 剪贴板参数处理保持不变。
- 已知结果：Arch 官方包清单确认 `qemu-ui-gtk` 提供 `ui-gtk.so`，pkgforge-dev 的 QEMU quick-sharun 构建同样逐个传入 `/usr/lib/qemu/*.so`；修复后产物待正式 Actions 构建和 Linux 实机确认。

### 2026-09-13：恢复 sharun 入口与 QEMU 模块路径映射

- 故障现象：显式加入 `qemu-ui-gtk` 和 `/usr/lib/qemu/*.so` 后，Actions 构建成功并发布了新产物，但实机仍报 `Display 'gtk' is not available`。
- 根因：构建日志确认 `ui-gtk.so` 已部署到 `AppDir/lib/qemu/ui-gtk.so`，同时检测到 QEMU 二进制硬编码 `/usr/lib/qemu`。原脚本随后用自定义脚本覆盖了 quick-sharun 生成的 `AppDir/AppRun`，导致 sharun 及 `01-path-mapping-hardcoded.hook` 未执行，模块存在但 QEMU 无法按映射路径加载。
- 修改文件：`qemu/build_qemu.sh`、`qemu/README.md`。
- 修复：保留 quick-sharun 生成的 sharun `AppDir/AppRun`，仅把现有 QEMU 多工具入口安装为 `AppDir/AppRun.sh`；原启动参数、GTK 剪贴板逻辑和已部署模块保持不变，不要求在宿主系统创建 `/usr/lib/qemu` 链接。
- 已知结果：修复方式与 quick-sharun 当前入口规范一致；新产物待正式 Actions 构建和 Linux 实机确认。
