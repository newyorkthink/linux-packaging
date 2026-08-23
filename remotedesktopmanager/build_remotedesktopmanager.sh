#!/usr/bin/env bash
set -e

rm -rf AppDir || true

ARCH="$(uname -m)"
export ARCH

export ICON=/usr/share/icons/hicolor/scalable/apps/com.devolutions.remotedesktopmanager.svg
export OUTPATH=./dist
export OUTNAME="remotedesktopmanager.AppImage"

# 必须在其他依赖之前安装 glycin-ng。它提供并替换 glycin；如果先安装官方 glycin，
# yay 在非交互模式下不会确认冲突替换，构建会直接失败。
yay -S --noconfirm glycin-ng

# 基本依赖
yay -S --noconfirm gcc base-devel wget binutils patchelf coreutils appstream-glib desktop-file-utils util-linux zsync jq

# remote-desktop-manager 及其依赖包
yay -S --noconfirm remote-desktop-manager ca-certificates libsecret vte3 webkit2gtk-4.1 xorg-server-xwayland libappindicator-gtk3 lsof gnome-keyring xdotool debugedit icu openssl

# fcitx5-gtk 提供 WebKitGTK3 中文输入模块。
yay -S --noconfirm fcitx5-gtk

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

# 补充环境变量以替代原本的 wrapper 脚本
echo 'DOTNET_EnableWriteXorExecute=0' >> AppDir/.env
echo 'LD_LIBRARY_PATH=${APPDIR}/bin:${APPDIR}/lib:${APPDIR}/shared/lib:${LD_LIBRARY_PATH}' >> AppDir/.env

# Avalonia 主界面直接连接 Fcitx5；WebKitGTK 输入框使用随包提供的 GTK3 Fcitx5 模块。
# LANG 必须是中日韩语言环境，否则 Avalonia 默认不会启用 Linux IME。
echo 'LANG=zh_CN.UTF-8' >> AppDir/.env
echo 'AVALONIA_IM_MODULE=fcitx5' >> AppDir/.env
echo 'GTK_IM_MODULE=fcitx5' >> AppDir/.env
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
    'GTK_IM_MODULE=fcitx5' \
    'XMODIFIERS=@im=fcitx'; do
    if ! grep -Fxq "$required_env" AppDir/.env; then
        echo "缺少 Remote Desktop Manager 中文输入环境变量：$required_env" >&2
        exit 1
    fi
done

quick-sharun --make-appimage
