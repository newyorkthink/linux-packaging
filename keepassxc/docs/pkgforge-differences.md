# KeePassXC 上游 pkgforge-dev 打包差异与取舍

## 核实来源

- **官方仓库**：[pkgforge-dev/KeePassXC-AppImage-Enhanced](https://github.com/pkgforge-dev/KeePassXC-AppImage-Enhanced)
- **固定提交**：`b269e163fc3e47d3ccac95349c70f4642296b3ad`（核对相关历史提交 `cf482bff362ff764a7aa611de9b7a6003679d260`、`2e6a99da59e75f2614bb1c8f0800c6b883fe148a`、`447945a54d1d216a4ccf3176d63ec70e2c4f82bb`）
- **已读原文件**：
  - [get-dependencies.sh](https://github.com/pkgforge-dev/KeePassXC-AppImage-Enhanced/blob/b269e163fc3e47d3ccac95349c70f4642296b3ad/get-dependencies.sh)
  - [make-appimage.sh](https://github.com/pkgforge-dev/KeePassXC-AppImage-Enhanced/blob/b269e163fc3e47d3ccac95349c70f4642296b3ad/make-appimage.sh)
  - [README.md](https://github.com/pkgforge-dev/KeePassXC-AppImage-Enhanced/blob/b269e163fc3e47d3ccac95349c70f4642296b3ad/README.md)

## 取舍总表

| 处理 | 决定 | 对应代码 | 当前依据、用途与影响 |
| --- | --- | --- | --- |
| 安装 `pcsclite` 并扫描 `/usr/lib/libpcsclite_real.so*` | 采用（按本仓库显式列表方式并入） | [build_keepassxc.sh](../build_keepassxc.sh#L13) 安装 `pcsclite`；[build_keepassxc.sh](../build_keepassxc.sh#L36) 单行调用：<br>`quick-sharun /usr/bin/keepassxc /usr/bin/keepassxc-cli /usr/bin/keepassxc-proxy /usr/bin/xclip /usr/bin/xclip-copyfile /usr/bin/xclip-cutfile /usr/bin/xclip-pastefile /usr/bin/xdotool /usr/lib/libXtst.so.6 /usr/lib/libxcb-xtest.so.0 /usr/lib/libpcsclite_real.so*` | **可核实作用**：安装 PC/SC 共享库并将运行时动态加载的 `libpcsclite_real.so*` 打入包内，避免智能卡/硬件密钥访问缺少底层真实库。<br>**官方原因**：官方提交 `cf482bff` 标题写明 `add pcsclite, only use software renderer`，未在 README、代码注释或 Issue 中附带更多文字说明；核对 `quick-sharun.sh`（`f86a9b31`）确认其不会自动收集 `libpcsclite_real.so*`。<br>**依据与影响**：随本仓库标准安装与收集行并入；新构建在 GitHub Actions 验证，智能卡硬件实测待实机连接确认。 |
| 扫描 `/usr/bin/keepassxc*` | 官方通配未启用（标准步骤保留显式入口与既有辅助工具） | [build_keepassxc.sh](../build_keepassxc.sh#L36) 显式传入 `/usr/bin/keepassxc /usr/bin/keepassxc-cli /usr/bin/keepassxc-proxy` 及既有 `xclip*`、`xdotool`、`libXtst.so.6`、`libxcb-xtest.so.0`、`libpcsclite_real.so*` | 覆盖 `keepassxc` 包全部可执行文件，同时保留本仓库已有的剪贴板与 X11 自动输入组件；避免无依据增删现有扫描目标。 |
| `export ICON` 与 `export DESKTOP` | `DESKTOP` 与上游一致；`ICON` 延续 Arch `svg` | [build_keepassxc.sh](../build_keepassxc.sh#L22-L24)：<br>`export ICON="/usr/share/icons/hicolor/scalable/apps/keepassxc.svg"`<br>`export DESKTOP="/usr/share/applications/org.keepassxc.KeePassXC.desktop"`（标准模板步骤） | 两处均直接取自 Arch 官方 `keepassxc` 软件包；保留原有矢量图标，无需切换为上游使用的 256x256 PNG。 |
| `export USE_HOST_DRIVERS_EXPERIMENTAL=1` | 未启用 | 未启用 | 官方提交 `2e6a99da`（`use host drivers, app is qt6 now`）启用；[导出注册表](../../Docs/packaging-export-registry.md) 未启用该实验开关，Mesa/LLVM 统一由 [quick-sharun-mesa-llvm.md](../../Docs/pending/quick-sharun-mesa-llvm.md) 独立跟踪。 |
| `get-debloated-pkgs --add-common --prefer-nano` | 未启用 | 未启用 | 官方未说明针对 KeePassXC 的单独原因；精简替换系统包不是本仓库标准步骤。 |
| `ADD_HOOKS="self-updater.hook"`、`UPINFO`、`quick-sharun --test` | 未启用 | 未启用（文件名由 `OUTNAME="keepassxc.AppImage"` 固定，版本与发布由公共入口及 `.github/workflows/build.yml` 负责） | 属于上游自更新、CI 发布及测试配置，不适用于本仓库统一构建与 `latest` Release 机制。 |

## 上游原始代码摘录（commit `b269e163fc3e47d3ccac95349c70f4642296b3ad`）

### `get-dependencies.sh`

```sh
#!/bin/sh

set -eu

ARCH=$(uname -m)

echo "Installing package dependencies..."
echo "---------------------------------------------------------------"
pacman -Syu --noconfirm \
	keepassxc \
	kvantum   \
	pcsclite  \
	qt6ct

echo "Installing debloated packages..."
echo "---------------------------------------------------------------"
get-debloated-pkgs --add-common --prefer-nano
```

### `make-appimage.sh`

```sh
#!/bin/sh

set -eu

ARCH=$(uname -m)
VERSION=$(pacman -Q keepassxc | awk '{print $2; exit}') # example command to get version of application here
export ARCH VERSION
export OUTPATH=./dist
export ADD_HOOKS="self-updater.hook"
export UPINFO="gh-releases-zsync|${GITHUB_REPOSITORY%/*}|${GITHUB_REPOSITORY#*/}|latest|*$ARCH.AppImage.zsync"
export ICON=/usr/share/icons/hicolor/256x256/apps/keepassxc.png
export DESKTOP=/usr/share/applications/org.keepassxc.KeePassXC.desktop
export USE_HOST_DRIVERS_EXPERIMENTAL=1

# Deploy dependencies
quick-sharun \
	/usr/bin/keepassxc* \
	/usr/lib/libpcsclite_real.so*

# Turn AppDir into AppImage
quick-sharun --make-appimage

# Test the app for 12 seconds, if the test fails due to the app
# having issues running in the CI use --simple-test instead
quick-sharun --test ./dist/*.AppImage
```
