#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

rm -rf AppDir || true

ARCH="$(uname -m)"
export ARCH

export ICON=/usr/share/icons/hicolor/scalable/apps/com.devolutions.remotedesktopmanager.svg
export OUTPATH=./dist
export OUTNAME="remotedesktopmanager.AppImage"

# 必须在其他依赖之前安装 glycin-ng。它提供并替换 glycin；如果先安装官方 glycin，
# yay 在非交互模式下不会确认冲突替换，构建会直接失败。
yay -S --noconfirm glycin-ng

# 安装统一的 Arch AppImage 基础包
"$SCRIPT_DIR/../common/arch/install_packages.sh" --base

# 基本依赖
yay -S --noconfirm gcc base-devel wget binutils patchelf coreutils appstream-glib desktop-file-utils util-linux zsync jq

# remote-desktop-manager 及其依赖包
yay -S --noconfirm remote-desktop-manager ca-certificates libsecret vte3 webkit2gtk-4.1 xorg-server-xwayland libappindicator-gtk3 lsof gnome-keyring xdotool debugedit icu openssl

# fcitx5-gtk 提供 WebKitGTK / VTE 使用的 GTK3 中文输入模块。
yay -S --noconfirm fcitx5-gtk

# 编译 IME 启动钩子需要与 RDM 相同的 .NET SDK。
yay -S --noconfirm dotnet-sdk

# 复制并修改桌面文件的 Exec 行，匹配实际提取的二进制程序名称
cp /usr/share/applications/com.devolutions.remotedesktopmanager.desktop ./rdm.desktop
sed -i 's/remotedesktopmanager/RemoteDesktopManager/g' ./rdm.desktop
export DESKTOP=./rdm.desktop

# 一次性部署主程序、WebView 4.1 桥接库和 Fcitx5 GTK3 输入模块。
# quick-sharun 对同一个 AppDir 连续运行会重复生成 lib.path 硬链接并因目标已存在而失败。
quick-sharun \
    /usr/lib/devolutions/RemoteDesktopManager/RemoteDesktopManager \
    /usr/lib/devolutions/RemoteDesktopManager/libWebView-4.1.so \
    /usr/lib/gtk-3.0/3.0.0/immodules/im-fcitx5.so

# 补充环境变量以替代原本的 wrapper 脚本。
# 不要设置 LD_LIBRARY_PATH。sharun 用 bundled ld-linux 的 --library-path 加载主进程依赖；
# LD_LIBRARY_PATH 会遗传给 LocalTerm posix_spawn 的宿主 /bin/sh，使其加载包内 libc.so.6，
# 出现 GLIBC_PRIVATE 符号错误（__pointer_chk_guard）后立刻退出。
# .NET DllImport 会先搜程序目录；ICU 与 RDM 原生库已复制到 AppDir/bin。
echo 'DOTNET_EnableWriteXorExecute=0' >> AppDir/.env

# Avalonia 主界面直接连接 Fcitx5；WebKitGTK / VTE 使用随包提供的 GTK3 Fcitx5 模块。
# LANG 必须是中日韩语言环境，否则 Avalonia 默认不会启用 Linux IME。
# GTK3 模块 ID 是 fcitx，不是 fcitx5；后者会导致找不到 IM module，候选方向键漏进终端。
echo 'LANG=zh_CN.UTF-8' >> AppDir/.env
echo 'AVALONIA_IM_MODULE=fcitx5' >> AppDir/.env
echo 'GTK_IM_MODULE=fcitx' >> AppDir/.env
echo 'XMODIFIERS=@im=fcitx' >> AppDir/.env

# 我们把真实目录里的所有文件复制到 AppDir/bin/ 和 AppDir/shared/bin/
# 复制到 shared/bin 是因为 sharun 运行时会使用 lib4bin 挂载 shared/bin 到 bin/
# (SquashFS 自动去重，不用担心体积翻倍)
mkdir -p AppDir/bin AppDir/shared/bin
cp -an /usr/lib/devolutions/RemoteDesktopManager/* AppDir/bin/ || true
cp -an /usr/lib/devolutions/RemoteDesktopManager/* AppDir/shared/bin/ || true

# 补充 .NET Core 强依赖但容易被 sharun 遗漏的系统动态库 (dlopen 形式加载)
# .NET 使用 DllImport 加载 icu 等库时，会优先查找程序所在目录 (bin)
cp -a /usr/lib/libicu*.so* AppDir/bin/ || true
cp -a /usr/lib/libicu*.so* AppDir/shared/bin/ || true

# RDM 的 Devolutions.TerminalControl 不请求 TextInputMethodClient，Avalonia 不会把按键交给 Fcitx5。
# 用 DOTNET_STARTUP_HOOKS 补一个 IME 客户端，让 ProcessKeyEvent 能吞掉选词键。
# 对照已安装的 RDM Avalonia.Base，避免钩子和主程序加载两套 Avalonia。
RDM_LIB=/usr/lib/devolutions/RemoteDesktopManager
if [ ! -f "$RDM_LIB/Avalonia.Base.dll" ]; then
    echo "缺少编译 IME 钩子所需的 Avalonia.Base.dll。" >&2
    exit 1
fi
dotnet build "$SCRIPT_DIR/ime-hook/RdmImeHook.csproj" -c Release -o /tmp/rdm-ime-hook -p:RdmDir="$RDM_LIB"
if [ ! -f /tmp/rdm-ime-hook/RdmImeHook.dll ]; then
    echo "编译 Remote Desktop Manager IME 启动钩子失败。" >&2
    exit 1
fi
cp -a /tmp/rdm-ime-hook/RdmImeHook.dll AppDir/bin/
cp -a /tmp/rdm-ime-hook/RdmImeHook.dll AppDir/shared/bin/
echo 'DOTNET_STARTUP_HOOKS=${APPDIR}/bin/RdmImeHook.dll' >> AppDir/.env

# 启动时按当前 AppImage 挂载路径生成 GTK3 immodules.cache。
# 构建期缓存会留下构建机绝对路径，GTK 无法加载；Remmina / dconf-editor 同样在运行时写缓存。
cat > AppDir/bin/rdm-gtk-immodules.src.hook << 'HOOK'
#!/bin/false

GTK_IMMODULE_DIR=""
for candidate in \
  "$APPDIR/lib/gtk-3.0/3.0.0/immodules" \
  "$APPDIR/usr/lib/gtk-3.0/3.0.0/immodules"; do
  if [ -d "$candidate" ]; then
    GTK_IMMODULE_DIR="$candidate"
    break
  fi
done

if [ -n "$GTK_IMMODULE_DIR" ]; then
  if [ -f "$GTK_IMMODULE_DIR/im-fcitx5.so" ]; then
    IM_CACHE_DIR="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}"
    IM_CACHE_FILE="$IM_CACHE_DIR/rdm-appimage-immodules-${UID:-0}.cache"
    cat > "$IM_CACHE_FILE" <<EOF
# GTK+ Input Method Modules file
"$GTK_IMMODULE_DIR/im-fcitx5.so"
"fcitx" "Fcitx 5" "fcitx" "" "ja:ko:zh:*"
EOF
    export GTK_IM_MODULE_FILE="$IM_CACHE_FILE"
    export GTK_IM_MODULE="fcitx"
  fi
fi
unset GTK_IMMODULE_DIR candidate IM_CACHE_DIR IM_CACHE_FILE
HOOK
chmod +x AppDir/bin/rdm-gtk-immodules.src.hook

# 打包前确认 WebView 4.1 的核心运行库和辅助进程已经完整进入 AppDir，避免生成必然无法启动的 AppImage。
for required_path in \
    AppDir/lib/libwebkit2gtk-4.1.so.0 \
    AppDir/lib/libsoup-3.0.so.0 \
    AppDir/lib/webkit2gtk-4.1/WebKitWebProcess \
    AppDir/lib/webkit2gtk-4.1/WebKitNetworkProcess \
    AppDir/lib/webkit2gtk-4.1/WebKitGPUProcess; do
    if [ ! -e "$required_path" ]; then
        echo "缺少 Remote Desktop Manager WebView 运行组件：$required_path" >&2
        exit 1
    fi
done

# 确认 Fcitx5 GTK3 模块和客户端库已经进入 AppDir。
if [ ! -f AppDir/lib/gtk-3.0/3.0.0/immodules/im-fcitx5.so ]; then
    echo "缺少 Remote Desktop Manager Fcitx5 GTK3 输入模块。" >&2
    exit 1
fi
if ! find AppDir/lib -maxdepth 1 \( -type f -o -type l \) -name 'libFcitx5GClient.so*' -print -quit | grep -q .; then
    echo "缺少 Remote Desktop Manager Fcitx5 D-Bus 客户端库。" >&2
    exit 1
fi

# 确认 glycin-ng 兼容层已经替换 GNOME glycin，避免运行时退回无沙箱模式。
if ! find AppDir/lib -maxdepth 1 \( -type f -o -type l \) -name 'libglycin-2.so*' -print -quit | grep -q .; then
    echo "缺少 glycin-ng 的 libglycin 兼容层。" >&2
    exit 1
fi
if ! find AppDir/lib -maxdepth 1 \( -type f -o -type l \) -name 'libglycin_ng.so*' -print -quit | grep -q .; then
    echo "缺少 glycin-ng 运行库。" >&2
    exit 1
fi

# 确认中文输入所需环境变量已完整写入。
for required_env in \
    'LANG=zh_CN.UTF-8' \
    'AVALONIA_IM_MODULE=fcitx5' \
    'GTK_IM_MODULE=fcitx' \
    'XMODIFIERS=@im=fcitx'; do
    if ! grep -Fxq "$required_env" AppDir/.env; then
        echo "缺少 Remote Desktop Manager 中文输入环境变量：$required_env" >&2
        exit 1
    fi
done

if ! grep -Fq 'DOTNET_STARTUP_HOOKS=${APPDIR}/bin/RdmImeHook.dll' AppDir/.env; then
    echo "缺少 Remote Desktop Manager IME 启动钩子环境变量。" >&2
    exit 1
fi
if [ ! -f AppDir/bin/RdmImeHook.dll ]; then
    echo "缺少 Remote Desktop Manager IME 启动钩子。" >&2
    exit 1
fi

if grep -Fxq 'GTK_IM_MODULE=fcitx5' AppDir/.env; then
    echo "Remote Desktop Manager 不应再设置 GTK_IM_MODULE=fcitx5。" >&2
    exit 1
fi

# 打包前去掉 .env 里的 LD_LIBRARY_PATH，避免内置终端继承包内 libc。
if [ -f AppDir/.env ]; then
    sed -i '/^LD_LIBRARY_PATH=/d' AppDir/.env
fi
if grep -q '^LD_LIBRARY_PATH=' AppDir/.env 2>/dev/null; then
    echo "Remote Desktop Manager 的 .env 仍含 LD_LIBRARY_PATH。" >&2
    exit 1
fi

if [ ! -f AppDir/bin/rdm-gtk-immodules.src.hook ]; then
    echo "缺少 Remote Desktop Manager GTK3 immodules 启动 hook。" >&2
    exit 1
fi
if ! grep -Fq '"fcitx" "Fcitx 5" "fcitx"' AppDir/bin/rdm-gtk-immodules.src.hook; then
    echo "Remote Desktop Manager GTK3 immodules hook 未登记模块 ID fcitx。" >&2
    exit 1
fi

quick-sharun --make-appimage
