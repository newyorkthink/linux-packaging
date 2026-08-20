#!/usr/bin/env bash
set -e

# 注意：
# 1. 不将 /usr/bin/perl 加入 AppImage；单独打包解释器会缺少 strict.pm 等核心模块，
#    i3-dmenu-desktop、i3-save-tree 等 Perl 脚本继续使用主机 Perl。
# 2. i3lock 单独制作成独立 AppImage 时可以正常解锁；但不能将 i3lock 一并打入 i3 AppImage，
#    两者的运行环境和认证依赖会发生冲突，导致输入正确密码也无法解锁。
# 3. slock 依赖主机用户组或 setuid 权限，同样不打包；锁屏程序请在主机安装并配置。
# 4. AppImage 仅保留 xss-lock，由 i3 配置指定它调用主机锁屏程序。

rm -rf AppDir || true

ARCH="$(uname -m)"
export ARCH

# 使用 i3 软件包自带的 desktop 和 icon 文件
export ICON=/usr/share/doc/i3/logo-30.png
export DESKTOP=/usr/share/applications/i3.desktop
export STARTUPWMCLASS="i3"
export OUTPATH=./dist
export OUTNAME="i3.AppImage"

# 将默认配置映射到 AppImage 内部
export PATH_MAPPING='
/etc/i3:${SHARUN_DIR}/etc/i3
/etc/i3status.conf:${SHARUN_DIR}/etc/i3status.conf
'

# 基本打包依赖
yay -S --noconfirm gcc base-devel wget binutils patchelf coreutils appstream-glib desktop-file-utils util-linux zsync xorg-server xorg-server-common xorg-server-xvfb

# i3wm、默认状态栏、启动器及常用 X11 工具
yay -S --noconfirm i3-wm i3status dmenu xss-lock perl perl-anyevent-i3 perl-json-xs dbus xorg-xrandr xorg-xset xorg-xprop xorg-xmodmap xorg-xsetroot xorg-xmessage

# 打包 i3wm 及其全部常用工具
quick-sharun \
  /usr/bin/i3 \
  /usr/bin/i3bar \
  /usr/bin/i3-config-wizard \
  /usr/bin/i3-dmenu-desktop \
  /usr/bin/i3-dump-log \
  /usr/bin/i3-input \
  /usr/bin/i3-migrate-config-to-v4 \
  /usr/bin/i3-msg \
  /usr/bin/i3-nagbar \
  /usr/bin/i3-save-tree \
  /usr/bin/i3-sensible-editor \
  /usr/bin/i3-sensible-pager \
  /usr/bin/i3-sensible-terminal \
  /usr/bin/i3-with-shmlog \
  /usr/bin/i3status \
  /usr/bin/dmenu \
  /usr/bin/dmenu_path \
  /usr/bin/dmenu_run \
  /usr/bin/stest \
  /usr/bin/xss-lock

# 保留 i3 和 i3status 的默认配置
mkdir -p AppDir/etc/i3
cp -a /etc/i3/. AppDir/etc/i3/
cp -a /etc/i3status.conf AppDir/etc/i3status.conf

quick-sharun --make-appimage
