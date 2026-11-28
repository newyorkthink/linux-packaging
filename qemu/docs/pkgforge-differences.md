# QEMU 上游 pkgforge-dev 打包差异与取舍

## 核实来源

- **官方仓库**：[pkgforge-dev/QEMU-AppImage](https://github.com/pkgforge-dev/QEMU-AppImage)
- **固定提交**：`9be8c9d4817443aae3301dfb22ba8de735013e2b`
- **已读原文件**：
  - [get-dependencies.sh](https://github.com/pkgforge-dev/QEMU-AppImage/blob/9be8c9d4817443aae3301dfb22ba8de735013e2b/get-dependencies.sh)
  - [make-appimage.sh](https://github.com/pkgforge-dev/QEMU-AppImage/blob/9be8c9d4817443aae3301dfb22ba8de735013e2b/make-appimage.sh)
  - [AppDir/bin/symlinks.hook](https://github.com/pkgforge-dev/QEMU-AppImage/blob/9be8c9d4817443aae3301dfb22ba8de735013e2b/AppDir/bin/symlinks.hook)
  - [AppDir/qemu.desktop](https://github.com/pkgforge-dev/QEMU-AppImage/blob/9be8c9d4817443aae3301dfb22ba8de735013e2b/AppDir/qemu.desktop)
  - [.github/workflows/appimage.yml](https://github.com/pkgforge-dev/QEMU-AppImage/blob/9be8c9d4817443aae3301dfb22ba8de735013e2b/.github/workflows/appimage.yml)
  - [README.md](https://github.com/pkgforge-dev/QEMU-AppImage/blob/9be8c9d4817443aae3301dfb22ba8de735013e2b/README.md)

## 取舍总表

| 处理 | 决定 | 对应代码 | 当前依据、用途与影响 |
| --- | --- | --- | --- |
| 直接收集 `/usr/bin/qemu-*`、`/usr/lib/qemu/*.so` 与 `/usr/share/qemu` | 同方向复用（在本仓库扫描行合并原有 `remote-viewer`） | [build_qemu.sh](../build_qemu.sh#L36)：<br>`quick-sharun /usr/bin/qemu-* /usr/lib/qemu/*.so /usr/bin/remote-viewer /usr/share/qemu`（标准模板步骤及既有 SPICE 入口） | 与上游均使用 `quick-sharun` 直接收集 `qemu-*`、动态模块 `/usr/lib/qemu/*.so`（含 `ui-gtk.so`）与 `/usr/share/qemu`，保留 quick-sharun 生成的 `AppRun` 与路径映射；本仓库另保留既有 `remote-viewer`。 |
| 桌面入口与图标 | 官方版本未启用（保留本仓库既有 `qemu.desktop` 与 `qemu.svg`） | [build_qemu.sh](../build_qemu.sh#L21-L24)：<br>`export ICON="$SCRIPT_DIR/qemu.svg"`<br>`export DESKTOP="$SCRIPT_DIR/qemu.desktop"`（标准配置及仓库自备文件） | 本仓库已有且已验证终端虚拟机用法对应的 `qemu.desktop`（`Terminal=true`）与离线 `qemu.svg`，无需改为上游远程 SVG 下载及 `Terminal=false` 的 desktop。 |
| 软件包扩展（`qemu-full`、`qemu-user*`、`edk2-*`、`spice-gtk`、`swtpm`、`virtiofsd`、`pipewire-*`、`zenity-rs-bin`）与额外扫描路径 | 未启用 | [build_qemu.sh](../build_qemu.sh#L13) 仅安装 `"qemu-desktop" qemu-tools qemu-ui-gtk virt-viewer` | 上游提供全架构模拟、TPM、user-mode binfmt 与 `spicy`；本仓库 [QEMU README](../README.md#2026-09-13最终稳定版实机确认) 已实机确认 `qemu-desktop`、`qemu-tools`、`qemu-ui-gtk`、`virt-viewer` 为稳定桌面虚拟机最小集合，无新增需求时不扩大体积。 |
| `DEPLOY_OPENGL=1`、`DEPLOY_VULKAN=1`、`DEPLOY_PIPEWIRE=1` | 未启用 | 未启用 | 官方未在文件或文档说明针对当前桌面包的单独原因；本仓库已实机验证 GTK、KVM、9P、剪贴板运行正常，不无证据引入额外体积与音频/驱动开关。 |
| `AppDir/bin/symlinks.hook` | 未启用 | 未启用 | 上游用于通过 `--make-symlinks` 在 `~/.local/bin` 创建软链接；本仓库 `quick-sharun` 已原生支持按当前目录软链接名和首参数分派，[QEMU README](../README.md#使用) 已围绕该方式验证通过。 |
| `get-debloated-pkgs`、`ADD_HOOKS="self-updater.hook"`、`UPINFO`、`quick-sharun --test` | 未启用 | 未启用 | `get-debloated-pkgs` 精简包替换不是本仓库默认步骤；其余为上游自更新、发布及 CI 测试配置。 |

## 上游原始代码摘录（commit `9be8c9d4817443aae3301dfb22ba8de735013e2b`）

### `get-dependencies.sh`

```sh
#!/bin/sh

set -eu

ARCH=$(uname -m)

echo "Installing package dependencies..."
echo "---------------------------------------------------------------"
if [ "$ARCH" = "aarch64" ]; then
    DATE=202608-1
    wget https://umea.mirror.pkgbuild.com/extra/os/x86_64/edk2-aarch64-${DATE}-any.pkg.tar.zst
    wget https://umea.mirror.pkgbuild.com/extra/os/x86_64/edk2-riscv64-${DATE}-any.pkg.tar.zst
    wget https://umea.mirror.pkgbuild.com/extra/os/x86_64/qemu-system-arm-firmware-11.1.2-1-x86_64.pkg.tar.zst
    wget https://umea.mirror.pkgbuild.com/extra/os/x86_64/edk2-ovmf-${DATE}-any.pkg.tar.zst
    wget https://umea.mirror.pkgbuild.com/extra/os/x86_64/seabios-1.17.0-2-any.pkg.tar.zst
    pacman -U *.pkg.tar.zst --noconfirm --arch x86_64
else
    pacman -S --noconfirm edk2-aarch64 edk2-riscv64 qemu-system-arm-firmware
fi
if [ "$ARCH" = "loongarch64" ]; then
    pacman -S --noconfirm edk2-loongarch64
fi
pacman -Syu --noconfirm --overwrite '/usr/share/qemu/*' \
    pipewire-audio   \
    pipewire-jack    \
    qemu-full        \
    qemu-desktop     \
    qemu-user        \
    qemu-user-binfmt \
    spice-gtk        \
    swtpm            \
    virtiofsd

echo "Installing debloated packages..."
echo "---------------------------------------------------------------"
get-debloated-pkgs --add-common --prefer-nano libdecor-mini

make-aur-package zenity-rs-bin
```

### `make-appimage.sh`

```sh
#!/bin/sh

set -eu

ARCH=$(uname -m)
VERSION=$(pacman -Q qemu-full | awk '{print $2; exit}')
export ARCH VERSION
export OUTPATH=./dist
export ADD_HOOKS="self-updater.hook"
export UPINFO="gh-releases-zsync|${GITHUB_REPOSITORY%/*}|${GITHUB_REPOSITORY#*/}|latest|*$ARCH.AppImage.zsync"
export ICON=https://gitlab.com/qemu-project/qemu/-/raw/master/ui/icons/qemu.svg
export DEPLOY_OPENGL=1
export DEPLOY_VULKAN=1
export DEPLOY_PIPEWIRE=1

# Deploy dependencies
quick-sharun \
	/usr/bin/qemu-*      \
	/usr/lib/qemu/*.so   \
	/usr/bin/zenity      \
	/usr/bin/spicy       \
	/usr/share/edk2      \
	/usr/share/qemu		 \
	/usr/lib/binfmt.d	 \
	/usr/lib/libcapstone.so*

# Turn AppDir into AppImage
quick-sharun --make-appimage

# Test the app for 12 seconds, if the test fails due to the app
# having issues running in the CI use --simple-test instead
quick-sharun --test ./dist/*.AppImage
```

### `AppDir/bin/symlinks.hook`

```sh
#!/bin/sh

_make_symlinks_in_path() {
	[ -n "$APPIMAGE" ] || return 1
	[ -n "$APPDIR" ] || return 1
	mkdir -p "$BINDIR"
	cd "$APPDIR"/bin
	set +e
	set -- ./qemu*
	for b do
		ln -sv "$APPIMAGE" "$BINDIR"/"${b##*/}" 2>/dev/null
	done
	exit 0
}

if [ "$1" = '--make-symlinks' ]; then
	_make_symlinks_in_path
fi
```

### `AppDir/qemu.desktop`

```ini
[Desktop Entry]
Name=QEMU
Exec=qemu-system-x86_64
Icon=qemu
StartupWMClass=qemu
Comment="A generic and open source machine & userspace emulator and virtualizer"
Type=Application
Terminal=false
Keywords=Emulator;Virtualization;KVM;
Categories=System;
```
