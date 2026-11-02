# Gemini 与 pkgforge 打包的差异

本次读取 [pkgforge-dev/Gemini-Desktop-AppImage](https://github.com/pkgforge-dev/Gemini-Desktop-AppImage)，固定 commit 为 `e7bf2237e223c0cb8b2625dfdd0b1d2f211ccabc`。本页区分直接复用的原文、公共入口集成和未启用项；代码作用与官方原始理由分别记录，不把推断冒称官方说明。

原文件：

- [get-dependencies.sh](https://github.com/pkgforge-dev/Gemini-Desktop-AppImage/blob/e7bf2237e223c0cb8b2625dfdd0b1d2f211ccabc/get-dependencies.sh)：更新服务查询、资源提取、runtime 与图标。
- [make-appimage.sh](https://github.com/pkgforge-dev/Gemini-Desktop-AppImage/blob/e7bf2237e223c0cb8b2625dfdd0b1d2f211ccabc/make-appimage.sh)：打包元数据、依赖收集和封装。
- [appimage.yml](https://github.com/pkgforge-dev/Gemini-Desktop-AppImage/blob/e7bf2237e223c0cb8b2625dfdd0b1d2f211ccabc/.github/workflows/appimage.yml)：Arch 容器及正式构建步骤。
- [README.md](https://github.com/pkgforge-dev/Gemini-Desktop-AppImage/blob/e7bf2237e223c0cb8b2625dfdd0b1d2f211ccabc/README.md)：quick-sharun、uruntime 和自更新说明。

## 当前取舍

| 处理 | 决定 | 对应代码 | 当前依据、用途与影响 |
| --- | --- | --- | --- |
| Windows 产品资源配合 Linux Electron | 采用路线，联网与解包由公共入口集成 | [本页完整公共调用](#本仓库实际公共调用)，[build_gemini.sh](../build_gemini.sh#L20) | 当前采用现成官方完整包与 Linux runtime，不编译替代程序。 |
| 包内 PNG 来源 | 直接复用官方设置 | `export ICON=./AppDir/bin/resources/app.asar.unpacked/assets/icon.png`，[build_gemini.sh](../build_gemini.sh#L121) | 1.17.0 实包中存在有效 PNG，退出 ICO 转换链。 |
| 依赖收集 | 采用 quick-sharun，保留本仓库既有完整参数 | [本页完整命令](#本仓库实际依赖收集与封装)，[build_gemini.sh](../build_gemini.sh#L137) | 本仓库兼容处理，并非逐字复制官方 NSS 参数。 |
| 最终封装 | 采用，标准步骤与上游同一命令 | `quick-sharun --make-appimage`，[build_gemini.sh](../build_gemini.sh#L150) | 仅最终 AppImage 成功后由现有公共入口保存版本。 |
| package.json 读取 Electron 版本 | 官方命令未启用 | [本页实际替代代码](#本仓库精确运行时识别)，[build_gemini.sh](../build_gemini.sh#L41) | 1.17.0 声明 `^42.4.1`，实际程序为 `44.5.1`；不以开发依赖范围替代精确 runtime。 |
| 提取时排除所有 .node | 官方命令未启用 | 保留完整提取与既有 PE 模块移除，[build_gemini.sh](../build_gemini.sh#L81) | 本仓库还需非 sticky 修补；先删除外置文件再提取 ASAR 曾报 `ENOENT`。 |
| 系统升级、libnss_nis 与瘦身包替换 | 未启用 | 无现有执行代码 | 使用本仓库基础包及既有精确依赖；当前故障来自日志断言，没有新增这些处理的必要证据。 |
| 小写 gemini 入口 | 未启用 | 继续安装既有 `patches/Gemini`，[build_gemini.sh](../build_gemini.sh#L94) | 保留已确认的大写入口，避免与命令行工具重名。 |
| 额外 hicolor PNG 副本 | 官方复制命令未启用 | 由已采用的 `ICON` 设置交给 quick-sharun 部署，[build_gemini.sh](../build_gemini.sh#L121) | 不手工添加重复图标文件；未恢复窗口图标注入。 |
| 自更新 hook 与 UPINFO | 未启用 | 无现有执行代码 | 沿用本仓库统一 Release 发布；上游 README 说明这些设置用于自更新，本次不增加新的运行时行为。 |
| quick-sharun --test | 未启用 | 无现有执行代码 | 上游注释称其运行短时检查；本仓库的临时验证留在提交之外，不向正式构建加入测试。 |

## 本仓库实际公共调用

以下命令属于本仓库集成，不冒称直接复用了上游 curl、URL 拼接或解包命令。

```bash
"$SCRIPT_DIR/../common/download/download_omaha_package.sh" \
  'https://update.googleapis.com/service/update2' \
  '{533dd80c-942a-4464-b6a9-2e59428d784e}' \
  prod win 10.0.22000 x64 \
  'https://dl.google.com/' '/release2/Google DeepMind/' \
  'GeminiSetup-{version}(_uncompressed)?[.]exe' \
  work/GeminiSetup.exe work/source-version.txt >/dev/null

"$SCRIPT_DIR/../common/archive/extract_archive.sh" work/GeminiSetup.exe work/windows

"$SCRIPT_DIR/../common/download/download_latest_checksum_asset.sh" \
  "https://github.com/electron/electron/releases/download/v$ELECTRON_VERSION/SHASUMS256.txt" \
  "^electron-v${ELECTRON_VERSION//./[.]}-linux-x64[.]zip$" \
  work/electron.zip >/dev/null

"$SCRIPT_DIR/../common/archive/extract_archive.sh" work/electron.zip work/electron
```

## 本仓库精确运行时识别

这是保留的本仓库兼容处理。只接受实际程序中的精确版本；无法识别时停止，不回退开发依赖或猜测 runtime。

```bash
ELECTRON_VERSION="$(
  {
    strings -a "$WINDOWS_EXE" 2>/dev/null || true
    strings -el "$WINDOWS_EXE" 2>/dev/null || true
  } \
    | grep -Eo 'Electron[/ ]v?[0-9]+\.[0-9]+\.[0-9]+' \
    | sed -E 's#Electron[/ ]v?##' \
    | sort -Vu \
    | tail -n 1 \
    || true
)"
[[ "$ELECTRON_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
  printf '错误：无法从当前程序确定 Electron 精确版本。\n' >&2
  exit 1
}
```

## 本仓库实际依赖收集与封装

依赖参数沿用既有构建，最终封装命令与标准模板、上游相同。`--base` 提供 NSS、IBus、inetutils 等，GTK3 和 Fcitx5 由现有独立依赖行提供。

```bash
quick-sharun AppDir/bin/* /usr/bin/hostname /usr/lib/libnss* /usr/lib/libsoftokn3.so /usr/lib/libfreeblpriv3.so /usr/lib/pkcs11/*

quick-sharun --make-appimage
```

## 上游原始代码与原因

### 更新服务查询和直接下载

以下原文未接入本仓库。源码可核实其用途是取得当前完整包及版本；官方未说明使用这些具体解析命令的原因。本仓库使用公共入口补全并集中维护响应、来源、大小与摘要校验。

```sh
OMAHA_RESP=$(curl -s -d '<?xml version="1.0" encoding="UTF-8"?><request protocol="3.0"><os platform="win" version="10.0" arch="x64"/><app appid="{533DD80C-942A-4464-B6A9-2E59428D784E}" version="0.0.0.0" ap="prod"><updatecheck/></app></request>' "https://tools.google.com/service/update2")
link="$(echo "$OMAHA_RESP" | grep -oP '<url[^>]+codebase="\Khttps[^"]+' | head -n1)$(echo "$OMAHA_RESP" | grep -oP '<package[^>]+name="\K[^"]+')"
curl -sSfL --retry 30 --retry-connrefused "$link" -o /tmp/temp.exe
echo "$OMAHA_RESP" | grep -oP '<manifest[^>]+version="\K[^"]+' > ~/version
```

### 资源提取

以下原文未接入本仓库。命令会排除 `.node`、`.exe`、`.dll` 并整理资源目录；官方未说明这些排除项的原始原因。由于本仓库保留必要的非 sticky 修补，外置文件必须先参与完整 ASAR 提取，再按已确认的名称和格式移除。

```sh
7z x /tmp/temp.exe "app-*/resources/*" -y "-xr!*.node" "-xr!*.exe" "-xr!*.dll" -o./AppDir/bin/
mv ./AppDir/bin/app-*/resources ./AppDir/bin/resources
rm -rf ./AppDir/bin/app-*
```

### runtime 版本、下载和小写入口

以下原文未启用。官方未说明为何把 package.json 中的开发依赖值作为 runtime 来源。实际包内数据与程序版本不一致，因此保留本仓库识别方式；运行时下载仍使用同一官方 Electron Release 来源，并增加既有公共 SHA-256 校验。

```sh
E_VERSION=v$(grep -a -oP '"electron":\s*"\^?\K[0-9.]+' ./AppDir/bin/resources/app.asar.unpacked/package.json | head -n 1)
if [ "$ARCH" = "x86_64" ]; then
    E_ARCH="x64"
elif [ "$ARCH" = "aarch64" ]; then
    E_ARCH="arm64"
fi

curl -sSfL "https://github.com/electron/electron/releases/download/${E_VERSION}/electron-${E_VERSION}-linux-${E_ARCH}.zip" | bsdtar -xf - -C ./AppDir/bin/
mv ./AppDir/bin/electron ./AppDir/bin/gemini
chmod +x ./AppDir/bin/gemini
```

### 图标

直接采用以下官方设置，可执行代码逐字保留；用途是把包内 PNG 交给 quick-sharun。官方未说明选择该路径的原始原因。本次对 1.17.0 的文件存在性、PNG 有效性和字节一致性进行了实际检查。

```sh
export ICON=./AppDir/bin/resources/app.asar.unpacked/assets/icon.png
```

官方还把同一 PNG 复制到 hicolor 目录，原文如下；本仓库没有启用这两条复制准备命令，官方未说明额外副本的原始原因。

```sh
mkdir -p ./AppDir/share/icons/hicolor/256x256/apps/
cp ./AppDir/bin/resources/app.asar.unpacked/assets/icon.png ./AppDir/share/icons/hicolor/256x256/apps/gemini.png
```

### 系统依赖、收集参数及额外行为

官方的包安装、瘦身包和 NSS 参数如下。命令用途可由源码核实；官方未说明逐个选择这些包和库的原因。本仓库采用已验证的基础包、运行依赖和原有收集列表，不因上游存在某项处理就直接加入。

```sh
pacman -Syu --noconfirm libnss_nis
get-debloated-pkgs --add-common --prefer-nano
quick-sharun ./AppDir/bin/* /usr/lib/libnss_nis.so* /usr/lib/libnsl.so* /usr/lib/libnss_mdns*_minimal.so*
```

以下自更新及检查命令未启用。自更新用途见上游 README；短时检查用途见原脚本注释。本仓库继续使用自身的发布与验证边界。

```sh
export ADD_HOOKS="self-updater.hook"
export UPINFO="gh-releases-zsync|${GITHUB_REPOSITORY%/*}|${GITHUB_REPOSITORY#*/}|latest|*$ARCH.AppImage.zsync"
quick-sharun --test ./dist/*.AppImage
```

## 验证与维护边界

1.17.0 实包检查确认：原生模块加载异常仍被捕获，日志已变成 `Will use fallbacks`；`Gemini.exe` 的 Electron 标识为 `44.5.1`，包内 PNG 可直接使用。已完成实际资源组装和补丁检查，未把静态检查写成完整 AppImage、GUI 或登录验收。

常规更新仍动态取得版本、包地址和摘要，不需要人工修改版本号或日志字符串。上游如改变实际程序的版本标识、资源布局、窗口调用或原生依赖，仍须重新核对。本页记录不授权自动恢复任何未启用的处理。
