#!/usr/bin/env bash

# 启用严格模式，在命令执行失败、引用未定义变量或管道执行失败时退出。
set -Eeuo pipefail

# 本程序专属处理：接收主构建脚本传入的 AppDir 绝对路径。
APPDIR="$1"

# 本程序专属处理：读取 Ubuntu 多架构库目录名称。
DEB_MULTIARCH="$(dpkg-architecture -qDEB_HOST_MULTIARCH)"

# 本程序专属处理：创建 libao 输出插件目录。
mkdir -p "$APPDIR/usr/lib/ao/plugins-4"

# 本程序专属处理：复制 libao 的 PulseAudio 输出模块。
install -m755 "/usr/lib/$DEB_MULTIARCH/ao/plugins-4/libpulse.so" "$APPDIR/usr/lib/ao/plugins-4/libpulse.so"

# 本程序专属处理：复制 libao 的 ALSA 输出模块。
install -m755 "/usr/lib/$DEB_MULTIARCH/ao/plugins-4/libalsa.so" "$APPDIR/usr/lib/ao/plugins-4/libalsa.so"

# 本程序专属处理：补入 PulseAudio 输出模块依赖的 libpulse-simple 运行库。
install -m755 "/usr/lib/$DEB_MULTIARCH/libpulse-simple.so.0" "$APPDIR/usr/lib/libpulse-simple.so.0"

# 本程序专属处理：补入 ALSA 输出模块依赖的 libasound 运行库。
install -m755 "/usr/lib/$DEB_MULTIARCH/libasound.so.2" "$APPDIR/usr/lib/libasound.so.2"

# 本程序专属处理：将 libao 的宿主插件目录等长重定位到 AppRun 保留的包内目录描述符路径。
LIBAO_SYSTEM_PLUGIN_DIR="/usr/lib/$DEB_MULTIARCH/ao/plugins-4" \
LIBAO_APPDIR_PLUGIN_DIR=/proc/self/fd/9/usr/lib/ao/plugins-4 \
perl -0777 -pi -e '
  BEGIN {
    $old = $ENV{LIBAO_SYSTEM_PLUGIN_DIR};
    $new = $ENV{LIBAO_APPDIR_PLUGIN_DIR};
    die "libao 包内插件路径长于原路径。\n" if length($new) > length($old);
  }
  $count += s/\Q$old\E/$new . ("\0" x (length($old) - length($new)))/ge;
  END { die "未能唯一重定位 libao 插件路径。\n" unless $count == 1; }
' "$APPDIR/usr/lib/libao.so.4"
