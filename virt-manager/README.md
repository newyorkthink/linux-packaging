# Virt Manager AppImage

## 用途与产物

本目录构建 Virt Manager 图形虚拟机管理器，固定发布资产为 `virt-manager.AppImage`。打包方案基于 [pkgforge-dev/virt-manager-AppImage](https://github.com/pkgforge-dev/virt-manager-AppImage) 提交 `f494702afdac4b018374fc86331f0b38293b388b` 的现有实现，并适配本仓库统一 workflow 和固定 Release 资产名。

## 技术栈

- Virt Manager：Python、GTK、libvirt。
- 虚拟化组件：QEMU/KVM、SPICE、virtiofsd、swtpm、dnsmasq、bridge-utils。
- 构建架构：x86_64。
- 打包环境：具有 FUSE 设备权限的 Arch Linux container。
- 许可证：上游打包脚本采用 GPL-2.0，许可证见 [LICENSE](./LICENSE)。

## 打包方式

`build_virt-manager.sh` 保留上游已经持续构建成功的 RunImage 路线：

1. 下载 RunImage continuous runtime。
2. 在隔离根文件系统中动态安装 Arch Linux 当前稳定版 `virt-manager`、QEMU、libvirt 依赖和虚拟化辅助组件。
3. 使用固定提交中的上游精简工具处理根文件系统，避免构建期间远程脚本无审计漂移。
4. 生成临时 RunImage 并提取完整 `RunDir`。
5. 使用 quick-sharun 最终封装为 `dist/virt-manager.AppImage`。

正式入口为 `.github/workflows/build.yml` 中独立的 `Build Virt Manager` Job。该 Job 保留上游构建需要的 privileged container 和 `/dev/fuse`，只更新 `latest` Release 中的 `virt-manager.AppImage`。

## 使用

在包含 AppImage 的当前目录执行：

```bash
# 添加执行权限。
chmod +x virt-manager.AppImage

# 启动 Virt Manager。
./virt-manager.AppImage
```

## 运行与兼容说明

- AppImage 包含 Virt Manager、QEMU 和相关用户态组件，但不能替代宿主内核的 KVM 支持。
- 硬件加速依赖宿主提供 `/dev/kvm` 并允许当前用户访问。
- 使用 `qemu:///system` 时，宿主仍需具备可用的 libvirt 系统服务、网络和权限配置；AppImage 不启动系统服务、不修改 `/etc`、不加载内核模块、不调整用户组。
- 上游 2026-09-01 的正式构建成功并发布了约 268 MiB 的 x86_64 AppImage；本仓库产物已有 Linux 实机图形界面启动反馈，但本地 libvirt 连接失败，虚拟机功能尚未验证；本次未核查 Actions 构建结果。

### 本地虚拟机需要宿主安装什么

**使用本地 `qemu:///system` 时，需要宿主机安装并提供可用的 libvirt 系统服务和 QEMU 后端；仅下载本 AppImage 不会自动完成这些系统配置。**

- **libvirt 系统服务及 QEMU 驱动：** 负责接收 Virt Manager 的请求、创建和管理虚拟机。只安装 libvirt 客户端库并不够。
- **宿主 QEMU 后端：** 由宿主 libvirt 服务调用。不能因为 AppImage 内包含 QEMU，就认为宿主服务会自动找到并使用包内程序。
- **软件包名称：** 以 Debian 系发行版为例，`libvirt-daemon-system` 提供常用的系统级 QEMU/libvirt 部署，`libvirt-daemon-driver-qemu` 是 QEMU 驱动，`qemu-system-x86` 是 x86 虚拟机后端；`libvirt-clients` 提供 `virsh` 等管理工具。实际依赖由发行版包管理器解析，不需要为了使用本 AppImage 再安装宿主 `virt-manager` 图形界面。
- **服务和权限：** 安装后还需按发行版配置可用的服务/socket、访问权限及所需网络。传统 `libvirtd` 使用 `/run/libvirt/libvirt-sock`，模块化 `virtqemud` 使用 `/run/libvirt/virtqemud-sock`；应与宿主实际服务模式匹配，不能把两种服务都当作必须安装和启动的项目。

软件包职责参考 [Debian libvirt-daemon-system](https://packages.debian.org/sid/libvirt-daemon-system) 与 [QEMU 驱动](https://packages.debian.org/sid/libvirt-daemon-driver-qemu)，服务模式参考 [libvirt 官方文档](https://libvirt.org/daemons.html)。

### 与 QEMU AppImage 的区别

- [QEMU AppImage](../qemu/README.md) 直接运行 QEMU，不依赖 libvirt 服务；适合已有 QEMU 启动命令、直接运行虚拟机的用法。KVM 加速仍依赖宿主内核和设备权限。
- 本 Virt Manager AppImage 通过 libvirt 提供图形化管理，适合管理多台虚拟机或连接远程 libvirt 主机；它不是 QEMU AppImage 的必需配套程序。
- 连接远程主机时，libvirt/QEMU 后端部署在远程虚拟化主机上，不要求本地安装同一套系统服务。
- `qemu:///session` 属于用户会话模式，不能套用本地 `qemu:///system` 的全部要求；本包利用内置组件运行该模式的能力尚未实机验证。
- pkgforge-dev 原版同样采用 `RIM_AUTORUN=virt-manager`，其构建脚本没有额外启动系统级 libvirt 服务的步骤；“包含全部组件”不代表系统服务已经运行，不能保证换用原版就能解决缺少 socket 的报错。

## 变更记录

### 2026-09-13：接入统一 AppImage 工作流

- 评估对象：`pkgforge-dev/virt-manager-AppImage` 提交 `f494702afdac4b018374fc86331f0b38293b388b`、构建脚本、workflow、最新 Release 和最近 Actions。
- 已确认结论：上游使用 RunImage 构建完整根文件系统，再由 quick-sharun 生成最终 AppImage；2026-09-01 定时构建成功，最近多数定时构建成功。
- 修改文件：`virt-manager/build_virt-manager.sh`、`virt-manager/README.md`、`virt-manager/LICENSE`、`.github/workflows/build.yml`。
- 适配：保留上游完整虚拟化用户态组件和构建容器要求，改为本仓库固定资产名与统一 Release 上传；固定远程精简脚本提交以便审计。
- 已知结果：已完成源码和 workflow 静态核对；本仓库构建及实机结果待正式 Actions 和真实运行反馈确认。

### 2026-09-13：检查本地 libvirt 连接要求

- 检查对象：当前 `build_virt-manager.sh`（Git blob `344ed5f0c2fb12a17712d3d7f8dde27deb4c4246`）、README、对应 workflow Job，以及 pkgforge-dev 原版启动配置。
- 问题现象：Linux 实机已显示图形界面，但连接 `qemu:///system` 时提示找不到 `/var/run/libvirt/virtqemud-sock`；反馈确认宿主未安装 libvirt 系统服务，且 `/run/libvirt/` 不存在。
- 证据与结论：依据真实运行反馈、两份构建脚本和 libvirt 官方文档，当前本地系统连接缺少可用的服务端；没有依据因此修改打包入口或依赖。保留现有打包方案，仅修改 `virt-manager/README.md`，说明宿主组件和适用场景。
- 未确认事项：未验证安装服务后的连接、虚拟机创建与启动、用户会话模式或原版产物的实机行为；界面启动不等于全部虚拟化功能可用。本次未检查 Actions 构建结果。
