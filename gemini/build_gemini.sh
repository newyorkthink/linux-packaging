#!/usr/bin/env bash

# 命令失败、用了没定义的变量，或管道里任一命令失败，就退出。
set -Eeuo pipefail

# 切到脚本所在目录，后面的 AppDir 和 dist 都写在这里。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 打包工具。GTK、输入法不要塞进这一行。
"$SCRIPT_DIR/../common/arch/install_packages.sh" --base
# 安装运行依赖及产品层处理工具。
"$SCRIPT_DIR/../common/arch/install_packages.sh" asar alsa-lib gtk3 cups libxss libxtst libnotify libsecret libpulse mesa fcitx5-gtk

# 清掉上次的打包目录。
"$SCRIPT_DIR/../common/build/prepare_x86_64_workspace.sh" "$SCRIPT_DIR" --skip-create cache work AppDir dist
mkdir -p AppDir/bin work/windows work/electron work/app-asar-linux

# 查询官方当前正式版，校验并下载完整安装包，同时记录来源版本。
"$SCRIPT_DIR/../common/download/download_omaha_package.sh" \
  'https://update.googleapis.com/service/update2' \
  '{533dd80c-942a-4464-b6a9-2e59428d784e}' \
  prod win 10.0.22000 x64 \
  'https://dl.google.com/' '/release2/Google DeepMind/' \
  'GeminiSetup-{version}(_uncompressed)?[.]exe' \
  work/GeminiSetup.exe work/source-version.txt >/dev/null

# 解包官方完整安装包，保留产品归档提取时需要的外置模块。
"$SCRIPT_DIR/../common/archive/extract_archive.sh" work/GeminiSetup.exe work/windows

# 定位唯一产品归档，保持主程序与资源来自同一安装目录。
mapfile -t WINDOWS_ASARS < <(find work/windows -type f -path '*/resources/app.asar' -print | sort)
[[ ${#WINDOWS_ASARS[@]} -eq 1 ]] || {
  printf '错误：应找到唯一的 resources/app.asar，实际为 %s 个。\n' "${#WINDOWS_ASARS[@]}" >&2
  exit 1
}
WINDOWS_RESOURCES="$(dirname "${WINDOWS_ASARS[0]}")"
WINDOWS_EXE="$(dirname "$WINDOWS_RESOURCES")/Gemini.exe"

# 本仓库兼容处理：从实际程序读取运行时版本，不使用开发依赖范围替代。
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

# 下载对应版本的官方 Linux 运行时，并按官方校验清单核对 SHA-256。
"$SCRIPT_DIR/../common/download/download_latest_checksum_asset.sh" \
  "https://github.com/electron/electron/releases/download/v$ELECTRON_VERSION/SHASUMS256.txt" \
  "^electron-v${ELECTRON_VERSION//./[.]}-linux-x64[.]zip$" \
  work/electron.zip >/dev/null

# 解包已校验的 Linux 运行时。
"$SCRIPT_DIR/../common/archive/extract_archive.sh" work/electron.zip work/electron

# 整个程序目录原样放进 AppDir/bin。
cp -a work/electron/. AppDir/bin/

# 本仓库兼容处理：沿用现有沙盒文件处理。
rm -f -- AppDir/bin/chrome-sandbox

# 用官方产品资源替换运行时自带的默认应用资源。
rm -rf -- AppDir/bin/resources
mkdir -p AppDir/bin/resources
cp -a "$WINDOWS_RESOURCES"/. AppDir/bin/resources/

# Windows 更新器和动态库不进入最终 Linux 产品层。
find AppDir/bin/resources -type f \( -iname '*.exe' -o -iname '*.dll' \) -delete

# 先完整提取产品归档，再处理其中的外置模块。
asar extract AppDir/bin/resources/app.asar work/app-asar-linux

# 保留现有原生模块移除逻辑，未知 Windows 模块仍会中止构建。
bash "$SCRIPT_DIR/patches/remove_windows_native_addon.sh" "$SCRIPT_DIR/AppDir/bin" "$SCRIPT_DIR/work/app-asar-linux" >/dev/null

# 本仓库兼容处理：仅取消已确认的跨工作区调用。
python3 "$SCRIPT_DIR/patches/disable_visible_on_all_workspaces.py" work/app-asar-linux

# 用修补后的产品层重新生成归档。
rm -f -- AppDir/bin/resources/app.asar
asar pack work/app-asar-linux AppDir/bin/resources/app.asar

# 保留已经验证有效的简体中文启动器。
install -m 755 "$SCRIPT_DIR/patches/Gemini" AppDir/bin/Gemini

# 保留运行时主程序的执行权限。
chmod +x AppDir/bin/electron

# 生成与现有产物名称一致的桌面入口。
cat > work/Gemini.desktop <<'DESKTOP'
[Desktop Entry]
Name=Gemini
Comment=Google Gemini desktop app
Exec=Gemini %U
Icon=Gemini
Terminal=false
Type=Application
Categories=Utility;
StartupWMClass=Gemini
DESKTOP

# 把当前机器架构传给 quick-sharun。
export ARCH="$(uname -m)"
# 成品里的应用名。
export APPNAME=Gemini
# 包里的真实程序名。
export MAIN_BIN=Gemini
# 让窗口对上 desktop 里的 StartupWMClass。
export STARTUPWMCLASS=Gemini
# 复用官方代码：使用产品资源中已有的 PNG 图标。
export ICON=./AppDir/bin/resources/app.asar.unpacked/assets/icon.png
# 使用当前构建生成的桌面入口。
export DESKTOP="$SCRIPT_DIR/work/Gemini.desktop"
# 把 AppImage 写到脚本目录下的 dist。
export OUTPATH="$SCRIPT_DIR/dist"
# 固定最终 AppImage 的文件名。
export OUTNAME=Gemini.AppImage
# 这是 GTK 3 程序。输入模块由 quick-sharun 自己收集。
export DEPLOY_GTK=1
# 本仓库兼容处理：保留现有不剥离二进制的配置。
export NO_STRIP=1

# 读取本次打包使用的版本。
VERSION="$("$SCRIPT_DIR/../common/build/read_app_version.sh" text work/source-version.txt --desktop "$DESKTOP")"

# 收集程序及其运行依赖。
quick-sharun AppDir/bin/* /usr/bin/hostname /usr/lib/libnss* /usr/lib/libsoftokn3.so /usr/lib/libfreeblpriv3.so /usr/lib/pkcs11/*

# 在包里生成中文 locale，运行时不依赖用户机器是否生成过。
mkdir -p AppDir/lib/locale
localedef --no-archive -i zh_CN -f UTF-8 AppDir/lib/locale/zh_CN.utf8
cat >> AppDir/.env <<'ENV'
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
LC_MESSAGES=zh_CN.UTF-8
LOCPATH=${SHARUN_DIR}/lib/locale
ENV

# 把 AppDir 打成 AppImage。
quick-sharun --make-appimage

# 打包成功后用公共脚本记下版本。
"$SCRIPT_DIR/../common/build/save_appimage_version.sh" dist/Gemini.AppImage "$VERSION" dist/version.txt
