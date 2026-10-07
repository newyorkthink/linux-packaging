#!/usr/bin/env bash
# 使用当前 AUR 配方编译 DeepSeek 官方桌面源码，再封装社区 Linux 预览版 AppImage。
set -Eeuo pipefail

# 所有构建路径均基于当前脚本目录。
readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

###### 准备构建环境 ######

# 公共入口检查 x86_64，只清理本项目的临时 AppDir 和 dist，并重新创建 dist。
"$SCRIPT_DIR/../common/build/prepare_x86_64_workspace.sh" \
  "$SCRIPT_DIR" --skip-create AppDir dist

# 安装统一的 Arch AppImage 基础包；其中包含 GTK 3 的 IBus 输入模块。
"$SCRIPT_DIR/../common/arch/install_packages.sh" --base

# 在临时 CI 容器中按当前 AUR 配方构建桌面版，并安装匹配 GTK 3 的 Fcitx5 模块。
# makepkg 校验配方提供的补丁摘要；应用内置运行时由上游下载器校验锁定的摘要。
"$SCRIPT_DIR/../common/arch/install_packages.sh" deepseek-harness-desktop fcitx5-gtk

# 使用 AUR 安装的真实 Electron ELF；/usr/bin/deepseek-harness-desktop 只是 shell 包装。
readonly APP_ROOT=/usr/lib/deepseek-harness-desktop
readonly APP_EXEC="$APP_ROOT/deepseek-harness"
readonly APPDIR="$SCRIPT_DIR/AppDir"
readonly DIST_DIR="$SCRIPT_DIR/dist"

# 从本次实际安装结果读取版本，保留 alpha 标识，去除 Arch epoch 和 pkgrel。
VERSION="$(pacman -Q deepseek-harness-desktop | awk '{print $2}')"
VERSION="${VERSION#*:}"
VERSION="${VERSION%-*}"
readonly VERSION

###### 核心打包 ######

# 沿用包内图标和 desktop，明确指定真实主程序，避免把 AUR 的 shell 当成入口。
export ARCH=x86_64
export VERSION
export APPNAME=deepseek-harness-desktop
export MAIN_BIN=deepseek-harness
export STARTUPWMCLASS=deepseek-ai-dsh-desktop
export ICON=/usr/share/icons/hicolor/512x512/apps/deepseek-harness.png
export DESKTOP=/usr/share/applications/deepseek-ai-dsh-desktop.desktop
export OUTPATH="$DIST_DIR"
export OUTNAME=deepseek-harness-desktop.AppImage

# 根据 ELF 收集依赖，构建期间不启动应用及其内置子程序。
export STRACE_MODE=0

# 内置 Node、CPython 和原生模块也有动态依赖，不能只扫描 Electron 主程序。
# 只选择当前 x86_64 ELF；不把其他架构文件和 setuid sandbox helper 纳入依赖扫描。
NATIVE_FILES=("$APP_EXEC")
while IFS= read -r -d '' native_file; do
  native_type="$(file -b -- "$native_file")"
  if [[ "$native_type" == ELF* && "$native_type" == *x86-64* ]]; then
    NATIVE_FILES+=("$native_file")
  fi
done < <(
  find "$APP_ROOT" -type f \
    \( -name '*.so*' -o -name '*.node' -o -perm /111 \) \
    ! -path "$APP_EXEC" ! -name chrome-sandbox -print0
)

# 一次收集应用自身依赖和 GTK 3 的 IBus / Fcitx5 模块，由工具生成启动入口。
quick-sharun \
  "${NATIVE_FILES[@]}" \
  /usr/lib/gtk-3.0/3.0.0/immodules/im-ibus.so \
  /usr/lib/gtk-3.0/3.0.0/immodules/im-fcitx5.so

# 补齐 Electron 相邻资源、完整 dsh 运行时和 Office 组件，不覆盖生成的主启动器。
rsync -a --exclude=/deepseek-harness --exclude=/chrome-sandbox \
  "$APP_ROOT/" "$APPDIR/bin/"

# 参照现有 Claude Desktop 布局，让真实 ELF 所在目录也能按原相对路径找到资源。
for app_file in "$APPDIR/bin/"*; do
  app_name="${app_file##*/}"
  if [[ ! -e "$APPDIR/shared/bin/$app_name" \
     && ! -L "$APPDIR/shared/bin/$app_name" ]]; then
    ln -s "../../bin/$app_name" "$APPDIR/shared/bin/$app_name"
  fi
done

# 保留 AUR 包中的上游 MIT 许可证，应用自带的第三方声明随完整资源一并保留。
install -Dm644 /usr/share/licenses/deepseek-harness-desktop/LICENSE \
  "$APPDIR/share/licenses/deepseek-harness-desktop/LICENSE"

# 包内提供中文 locale，输入法由宿主配置选择，不强制设置 GTK_IM_MODULE 或 LC_ALL。
mkdir -p "$APPDIR/lib/locale"
localedef --no-archive -i zh_CN -f UTF-8 "$APPDIR/lib/locale/zh_CN.utf8"
cat >> "$APPDIR/.env" <<'ENV'
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
LC_MESSAGES=zh_CN.UTF-8
LOCPATH=${SHARUN_DIR}/lib/locale
ENV

###### 整理产物 ######

# 生成唯一正式 AppImage；共享 Action 负责上传 latest Release 并发布版本信息。
quick-sharun --make-appimage

# 只有最终产物存在且非空时，才记录本次实际打包的应用版本。
"$SCRIPT_DIR/../common/build/save_appimage_version.sh" \
  "$DIST_DIR/deepseek-harness-desktop.AppImage" "$VERSION" "$DIST_DIR/version.txt"
