# QEMU AppImage

## 中文

这是一个非官方 QEMU AppImage 打包仓库。自动构建沿用原有 Compiled CI 流程，从 QEMU 官方上游源码构建，并使用原有运行时处理和高压缩 AppImage 打包方式。

### 下载

Release 固定只使用：

- Release：`Latest`
- Tag：`latest`
- 文件：`qemu.AppImage`

固定下载地址：

`https://github.com/newyorkthink/Qemu-AppImage/releases/download/latest/qemu.AppImage`

### 自动构建

- 每次向 `main` 推送都会自动构建。
- 每 6 天自动重新构建一次，从 QEMU 官方上游获取当时最新源码。
- 构建参数沿用原有 Compiled CI 配置。
- 保留 `AppRun`、`AppRun.wrapper` 和 `libunionpreload.so` 的既有运行时处理。
- 使用 `uruntime`、DWARFS 和 `zstd:level=22` 生成紧凑型 AppImage。
- 不使用 GitHub Actions Artifact。
- 构建成功后只更新固定的 `Latest` / `latest` Release 和 `qemu.AppImage`。

### 基本使用

添加执行权限：

```bash
chmod +x qemu.AppImage
```

查看 QEMU 版本：

```bash
./qemu.AppImage qemu-system-x86_64 --version
```

创建 QCOW2 磁盘：

```bash
./qemu.AppImage qemu-img create -f qcow2 disk.qcow2 30G
```

启动 x86_64 虚拟机：

```bash
./qemu.AppImage qemu-system-x86_64 \
  -enable-kvm \
  -cpu host \
  -smp 2 \
  -m 4G \
  -drive file=<磁盘镜像路径>,format=qcow2 \
  -cdrom <ISO路径> \
  -boot d
```

需要 KVM 硬件加速时，主机需要提供 `/dev/kvm` 并允许当前用户访问。

---

## English

This is an unofficial QEMU AppImage packaging repository. Automated builds preserve the existing Compiled CI flow, build from the official upstream QEMU source, and keep the existing runtime handling and compact AppImage packaging method.

### Download

The repository uses one fixed release:

- Release: `Latest`
- Tag: `latest`
- File: `qemu.AppImage`

Stable download URL:

`https://github.com/newyorkthink/Qemu-AppImage/releases/download/latest/qemu.AppImage`

### Automatic builds

- Every push to `main` automatically starts a build.
- A scheduled rebuild runs every 6 days and pulls the then-current official upstream QEMU source.
- The existing Compiled CI build options are preserved.
- The existing `AppRun`, `AppRun.wrapper`, and `libunionpreload.so` runtime handling is preserved.
- `uruntime`, DWARFS, and `zstd:level=22` are used to produce the compact AppImage.
- GitHub Actions Artifact is not used.
- A successful build only refreshes the fixed `Latest` / `latest` Release and `qemu.AppImage`.

### Basic usage

Make the AppImage executable:

```bash
chmod +x qemu.AppImage
```

Check the QEMU version:

```bash
./qemu.AppImage qemu-system-x86_64 --version
```

Create a QCOW2 disk:

```bash
./qemu.AppImage qemu-img create -f qcow2 disk.qcow2 30G
```

Start an x86_64 virtual machine:

```bash
./qemu.AppImage qemu-system-x86_64 \
  -enable-kvm \
  -cpu host \
  -smp 2 \
  -m 4G \
  -drive file=<disk-image-path>,format=qcow2 \
  -cdrom <iso-path> \
  -boot d
```

For KVM hardware acceleration, the host must provide `/dev/kvm` and allow the current user to access it.
