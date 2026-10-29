# Claude Desktop 暂不采用的 pkgforge 处理

## 当前决定

**状态：仅作差异记录，未启用，不是当前构建步骤，也不构成后续启用授权。**

用户本次明确批准先使用本仓库的 69 行 Electron 基础模板：先系统安装，再独立下载 DEB 并整目录打包；暂不加入本页列出的 pkgforge 专属处理。当前实现见 [构建脚本](../build_claude-desktop.sh)、[README](../README.md) 和 [模板参数说明](template-deviations.md)。

AUR 安装阶段仍按应用包声明安装其正常依赖；这不等于主动把 pkgforge 的虚拟机组件部署、hook 或补丁接入 AppImage。本页保存源码只为说明差异，禁止后续 AI 看到旧代码就自动恢复。

## 已核对的来源

- 仓库：[pkgforge-dev/Claude-Desktop-AppImage](https://github.com/pkgforge-dev/Claude-Desktop-AppImage)。
- 本次已读源码快照：`6dd10c7dffd99206b5dbcb25f3676a702aace8c2`。这是历史证据，不表示后续始终适用，也不是构建时固定应用或工具版本。
- [get-dependencies.sh](https://github.com/pkgforge-dev/Claude-Desktop-AppImage/blob/6dd10c7dffd99206b5dbcb25f3676a702aace8c2/get-dependencies.sh)：架构参数、安装依赖、官方 APT 来源、解包、QEMU / 固件部署及 asar 修改。
- [make-appimage.sh](https://github.com/pkgforge-dev/Claude-Desktop-AppImage/blob/6dd10c7dffd99206b5dbcb25f3676a702aace8c2/make-appimage.sh)：额外 hook、更新元数据、图形部署开关、依赖输入和官方原脚本末尾检查。
- [fix-nspr.hook](https://github.com/pkgforge-dev/Claude-Desktop-AppImage/blob/6dd10c7dffd99206b5dbcb25f3676a702aace8c2/fix-nspr.hook)：独立环境设置文件。
- [README.md](https://github.com/pkgforge-dev/Claude-Desktop-AppImage/blob/6dd10c7dffd99206b5dbcb25f3676a702aace8c2/README.md)：AppImage、便携运行和 self-updater 说明。
- [.github/workflows/appimage.yml](https://github.com/pkgforge-dev/Claude-Desktop-AppImage/blob/6dd10c7dffd99206b5dbcb25f3676a702aace8c2/.github/workflows/appimage.yml)：官方在 Arch 容器中分别执行上述两个脚本，面向 x86_64 和 aarch64。本项目当前只批准 x86_64，不因本记录增加其他架构。

## 各项作用、官方说明与本次状态

以下“代码作用”根据已读命令和资源位置说明；它与“官方为何这样写”不是同一个问题。没有官方解释的项目，明确保留“官方未说明原因”，不把推断写成已确认的故障根因。

| 原有处理 | 代码作用 | 官方给出的原因或证据 | 本次状态 |
| --- | --- | --- | --- |
| 读取官方 APT Packages、curl 下载 DEB、写入 `~/version` | 从官方仓库元数据拼出下载地址，下载后由地址提取版本。 | 脚本给出实现，未解释为什么选用这一解析方式。 | 使用当前 AUR 来源解析、SHA-256 校验和既定公共版本接口替代这一通用来源流程，不复制其 curl 或版本解析。 |
| 按架构设置 QEMU、edk2 和固件名称 | 区分 x86_64 与 aarch64 的程序、软件包和固件布局。 | [Anthropic 官方 Linux 说明](https://code.claude.com/docs/en/desktop-linux) 明确 Cowork 使用 QEMU / KVM 虚拟机并需要 UEFI 固件；pkgforge 未逐项说明每个部署选择的故障背景。 | 只保存原文；不加入额外架构支持或专属安装命令。 |
| 复制 qemu-system、qemu-img、socat 及 `/usr/share/qemu` | 将虚拟机程序、通信工具及 QEMU 资源放进 AppDir。 | 虚拟机用途有 Anthropic 官方说明；具体复制集合的选择原因，pkgforge 官方未说明原因。 | 不主动部署进 AppImage。正常 AUR 依赖安装仍由第一阶段执行。 |
| 将 edk2 固件复制为 OVMF / AAVMF 文件 | 在包内准备按架构命名的 UEFI 固件文件。 | 官方确认 Cowork 需要 UEFI 固件；pkgforge 未说明具体路径选择的故障背景。 | 未启用。 |
| 复制独立 `fix-nspr.hook` | 设置 `NSPR_USE_ZONE_ALLOCATOR=0`。NSPR 在读取这一环境开关时，0 表示不启用 zone allocator。 | [NSPR 源码](https://chromium.googlesource.com/chromium/third_party/nss/+/37d451d9f190d738a14354926c9ae4bc57d7fe17/mozilla/nsprpub/pr/src/malloc/prmem.c) 可确认变量含义；为何在本应用采用该设置，pkgforge 官方未说明原因。 | hook 只作为文档原文保存，没有创建正式 hook 文件，也没有加入环境变量。 |
| 第一条 asar perl 修改 | 将两个系统 OVMF 固件候选路径改为 `process.env.APPDIR` 下的 `share/OVMF/OVMF_CODE_4M.fd`。 | 原命令可确认替换内容；对应原始故障及采用理由，官方未说明原因。 | 未执行、不接入构建。 |
| 第二条 asar perl 修改 | 将系统 AAVMF 候选路径改为原文中的 `process.env.APPDIR/AAVMF`。 | 仅记录原文；它与前面复制文件的 `share/AAVMF` 路径是否符合当前应用逻辑，本次未作运行验证，官方未说明原因。 | 未执行，不擅自改写这条历史命令。 |
| 第三条 asar perl 修改 | 把“系统 id 为 ubuntu 且版本以 22. 开头”的条件表达式替换为 `true`。 | 可确定修改的是这一条件；所控制的具体功能与采用理由，官方未说明原因，本次不推测为某项已确认修复。 | 未执行、不接入构建。 |
| `ADD_HOOKS`、`UPINFO` | 申请 self-updater、fix-namespaces hook，并配置该仓库的 zsync 更新来源。 | pkgforge README 说明 self-updater 用于更新提示；其他 hook 的应用专属故障背景未说明。 | 不加入这组 hook 或原仓库的更新来源。 |
| `DEPLOY_OPENGL`、`DEPLOY_VULKAN` 及额外 NSS / NIS / mDNS 输入 | 要求 quick-sharun 增加对应运行资源部署和额外库收集。 | 命令可确认部署输入；在本应用为何必须增加全部这些项，官方未说明原因。 | 当前只使用基础模板及应用真实依赖，不手工增加这些输入或开关。 |
| `pacman -Syu`、get-debloated-pkgs、末尾 `quick-sharun --test` | 分别涉及系统升级式安装、替换运行包和通用产物检查。 | 这些是官方原脚本中的通用流程，不等于应用专属兼容依据。 | 使用本仓库公共安装及基础模板；不照搬系统升级、瘦身或测试步骤，也不为此修改 workflow。 |

## 官方源码快照：仅供核对

下面保留本次已读文件的完整原文，包含其原始架构变量、命令、注释和上下文。它们只存在于本文代码块中，不是本仓库当前的执行文件。将来加入任何一项前，必须先按下一节重新查看官方当前源码，不能直接复制旧快照。

### get-dependencies.sh

来源：[固定源码链接](https://github.com/pkgforge-dev/Claude-Desktop-AppImage/blob/6dd10c7dffd99206b5dbcb25f3676a702aace8c2/get-dependencies.sh)。

```bash
#!/bin/sh

set -euo pipefail

ARCH=$(uname -m)

echo "Installing package dependencies..."
echo "---------------------------------------------------------------"

case "$ARCH" in
	x86_64)
		farch=amd64
		qemu_pkg="qemu-system-x86"
		edk2_flag="-S"
		edk2_pkg="edk2-ovmf"
		edk_arch="x64"
		vmf_dir="OVMF"
		code_src="OVMF_CODE.4m.fd"
		vars_src="OVMF_VARS.4m.fd"
		vmf_sfx="_4M"
		;;
	aarch64)
		farch=arm64
		qemu_pkg="qemu-system-aarch64"
		edk2_flag="-U"
		curl -sSfL "https://archlinux.org/packages/extra/any/edk2-aarch64/download/" -o /tmp/edk2-aarch64.pkg.tar.zst
		edk2_pkg="/tmp/edk2-aarch64.pkg.tar.zst"
		edk_arch="aarch64"
		vmf_dir="AAVMF"
		code_src="QEMU_EFI.fd"
		vars_src="QEMU_VARS.fd"
		vmf_sfx=""
		;;
esac

pacman -Syu --noconfirm patchelf libnss_nis nss-mdns nss socat qemu-img $qemu_pkg
pacman $edk2_flag --noconfirm $edk2_pkg

echo "Installing debloated packages..."
echo "---------------------------------------------------------------"
get-debloated-pkgs --add-common --prefer-nano

echo "Getting binary..."
echo "---------------------------------------------------------------"

BASE_URL="https://downloads.claude.ai/claude-desktop/apt/stable"
link="$BASE_URL/$(curl -sL --compressed "$BASE_URL/dists/stable/main/binary-$farch/Packages" | awk '/^Filename:/ {val=$2} END {print val}')"

curl -sSfL --retry 30 --retry-connrefused "$link" -o /tmp/temp.deb
echo "$link" | grep -oP 'claude-desktop_\K[^_]+' > ~/version

echo "Preparing AppDir..."
mkdir -p ./AppDir/
bsdtar -xOf /tmp/temp.deb data.tar.xz | bsdtar -xf - --strip-components=2 -C ./AppDir/

cp /usr/bin/qemu-system-$ARCH /usr/bin/qemu-img /usr/bin/socat ./AppDir/bin/
mv -f ./AppDir/lib/claude-desktop/* ./AppDir/bin/
rm -rf ./AppDir/lib

cp -r /usr/share/qemu ./AppDir/share/
cp ./fix-nspr.hook ./AppDir/bin/fix-nspr.hook
mkdir ./AppDir/share/$vmf_dir
cp -f /usr/share/edk2/$edk_arch/$code_src ./AppDir/share/$vmf_dir/${vmf_dir}_CODE${vmf_sfx}.fd
cp -f /usr/share/edk2/$edk_arch/$vars_src ./AppDir/share/$vmf_dir/${vmf_dir}_VARS${vmf_sfx}.fd

perl -pi -e 's/\Q[`\/usr\/share\/OVMF\/OVMF_CODE_4M.fd`,`\/usr\/share\/OVMF\/OVMF_CODE.fd`]\E/sprintf("%-*s", length($&), "[\`\${process.env.APPDIR}\/share\/OVMF\/OVMF_CODE_4M.fd\`]")/e' ./AppDir/bin/resources/app.asar
perl -pi -e 's/\Q[`\/usr\/share\/AAVMF\/AAVMF_CODE.fd`]\E/sprintf("%-*s", length($&), "[\`\${process.env.APPDIR}\/AAVMF\`]")/e' ./AppDir/bin/resources/app.asar
perl -pi -e 's/\Qe?.id===`ubuntu`&&(e.versionId??``).startsWith(`22.`)\E/sprintf("%-*s", length($&), "true")/e' ./AppDir/bin/resources/app.asar
# sed -i 's|MimeType=x-scheme-handler/claude;|MimeType=x-scheme-handler/claude;x-scheme-handler/claude-desktop;|' ./AppDir/share/applications/com.anthropic.Claude.desktop
```

### make-appimage.sh

来源：[固定源码链接](https://github.com/pkgforge-dev/Claude-Desktop-AppImage/blob/6dd10c7dffd99206b5dbcb25f3676a702aace8c2/make-appimage.sh)。

```sh
#!/bin/sh

set -eu

ARCH=$(uname -m)
export ARCH
export OUTPATH=./dist
export ADD_HOOKS="self-updater.hook:fix-namespaces.hook"
export UPINFO="gh-releases-zsync|${GITHUB_REPOSITORY%/*}|${GITHUB_REPOSITORY#*/}|latest|*$ARCH.AppImage.zsync"
export ICON=./AppDir/share/icons/hicolor/256x256/apps/claude-desktop.png
export DESKTOP=./AppDir/share/applications/com.anthropic.Claude.desktop

export DEPLOY_GTK=1
export DEPLOY_OPENGL=1
export DEPLOY_VULKAN=1

quick-sharun ./AppDir/bin/* /usr/lib/libnss_nis.so* /usr/lib/libnsl.so* /usr/lib/libnss_mdns*_minimal.so*
quick-sharun --make-appimage
quick-sharun --test ./dist/*.AppImage
```

### fix-nspr.hook

来源：[固定源码链接](https://github.com/pkgforge-dev/Claude-Desktop-AppImage/blob/6dd10c7dffd99206b5dbcb25f3676a702aace8c2/fix-nspr.hook)。

```sh
#!/bin/sh
export NSPR_USE_ZONE_ALLOCATOR=0
```

## 后续用户要求加入时

1. 只针对准备加入的那一项重新读取 pkgforge 对应仓库的当前源码、相关说明和调用上下文，确认官方现在是否仍保留，是否已有改写或移除；不要重查其他应用或重新遍历整个组织。
2. 结合当前官方 DEB、目标架构、现有模板和具体功能反馈，确认该处理是否仍适用。官方已经移除或不再适用时，不得按本页快照恢复。
3. 说明当前原始代码、可核实的作用、官方理由或“官方未说明原因”、新增文件及实际影响，取得本次加入的明确同意。
4. 获批后才按对应阶段加入当前官方代码和独立配套文件，并同步更新 README、模板差异和固定配置说明。涉及与模板、路径或其他规则的冲突时，先报告具体冲突，不自行改写官方命令。
5. 保存实际检查和运行结果，不把基础打包成功、文件存在或本页源码说明写成 Cowork、沙盒或其他功能已实机通过。
