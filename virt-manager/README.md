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
- 上游 2026-09-01 的正式构建成功并发布了约 268 MiB 的 x86_64 AppImage；本仓库适配后的新产物尚未经过 Actions 构建或 Linux 实机运行确认。

## 变更记录

### 2026-09-13：接入统一 AppImage 工作流

- 评估对象：`pkgforge-dev/virt-manager-AppImage` 提交 `f494702afdac4b018374fc86331f0b38293b388b`、构建脚本、workflow、最新 Release 和最近 Actions。
- 已确认结论：上游使用 RunImage 构建完整根文件系统，再由 quick-sharun 生成最终 AppImage；2026-09-01 定时构建成功，最近多数定时构建成功。
- 修改文件：`virt-manager/build_virt-manager.sh`、`virt-manager/README.md`、`virt-manager/LICENSE`、`.github/workflows/build.yml`。
- 适配：保留上游完整虚拟化用户态组件和构建容器要求，改为本仓库固定资产名与统一 Release 上传；固定远程精简脚本提交以便审计。
- 已知结果：已完成源码和 workflow 静态核对；本仓库构建及实机结果待正式 Actions 和真实运行反馈确认。
