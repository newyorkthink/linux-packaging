#!/usr/bin/env bash

############# 初始化脚本 #############

# 启用严格模式，在命令执行失败、引用未定义变量或管道执行失败时退出。
set -Eeuo pipefail

# 获取脚本所在目录的绝对路径。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

############# 准备构建目录 #############

# 设置本次构建的源码目录和产物路径。
SOURCE_DIR="$SCRIPT_DIR/upstream"
DIST_DIR="$SCRIPT_DIR/dist"
APPIMAGE="$DIST_DIR/hermes-desktop.AppImage"

# 清理上次构建的源码和产物，并重建产物目录。
"$SCRIPT_DIR/../common/build/prepare_x86_64_workspace.sh" "$SCRIPT_DIR" --skip-create upstream dist

############# 准备构建环境 #############

# 安装构建工具和应用所需的依赖包。
"$SCRIPT_DIR/../common/apt/install_packages.sh" \
  libgtk-3-0 libnotify4 libxss1 libxtst6 libatspi2.0-0 libgbm1 libasound2t64

############ 下载并准备应用 #############

# 下载最新正式 Release 标签的源码，成功后取得原始标签名。
SOURCE_REF="$(
  "$SCRIPT_DIR/../common/github/download_latest_stable_release_source.sh" NousResearch/hermes-agent "$SOURCE_DIR"
)"

############### 核心打包 ###############

(
  # 进入上游源码目录。
  cd -- "$SOURCE_DIR"

  # 设置 Desktop 目录和正式版本号。
  DESKTOP_DIR="$SOURCE_DIR/apps/desktop"
  VERSION="${SOURCE_REF#v}"

  # 在源码目录外创建上游工具链的临时工作目录。
  TOOLCHAIN_DIR="$(mktemp -d)"

  # 使用上游 CI 的 PM 入口准备锁定的 Node.js 和 pnpm。
  GITHUB_ENV=/dev/null GITHUB_OUTPUT=/dev/null GITHUB_PATH="$TOOLCHAIN_DIR/path" \
    python3 -S scripts/ci/setup_toolchain.py install --toolchain node --home "$TOOLCHAIN_DIR"

  # 按上游工具链输出的顺序加载工具目录。
  while IFS= read -r tool_dir; do
    PATH="$tool_dir:$PATH"
  done < "$TOOLCHAIN_DIR/path"

  # 按上游锁文件安装 JavaScript 工作区依赖。
  pnpm install --frozen-lockfile

  # 读取上游正式标签对应的提交。
  UPSTREAM_COMMIT="$(git rev-parse HEAD)"

  # 构建普通 Desktop，并记录实际的上游提交和正式标签。
  GITHUB_SHA="$UPSTREAM_COMMIT" GITHUB_REF_NAME="$SOURCE_REF" HERMES_PAYLOAD_TAG="$SOURCE_REF" \
    pnpm --dir "$DESKTOP_DIR" run build

  # 使用上游的 Linux AppImage 工具准备入口生成打包清单。
  PACKAGER_DIR="$DESKTOP_DIR/build/packager/linux-x64"
  node apps/desktop/scripts/prepare-packaging-tools.mjs --source "$SOURCE_DIR" --out "$PACKAGER_DIR" \
    --target linux-x64 --cache "$SOURCE_DIR/.cache/desktop-inputs/packager" --format AppImage

  # 从上游打包清单读取图标工具目录。
  PACKAGER="$PACKAGER_DIR/prepared.json"
  ICONS_DIR="$(jq -r '.toolsets.icons // empty' "$PACKAGER")"
  PACKAGING_TOOLS_DIR="$DESKTOP_DIR/build/prepared-packaging-tools"

  # 仅处理缺少模块声明且会被 Desktop 当作 ES 模块加载的 CommonJS 图标工具。
  if [[ -n "$ICONS_DIR" && -f "$ICONS_DIR/icon-tool.js" && ! -e "$ICONS_DIR/package.json" &&
        ! -e "$PACKAGING_TOOLS_DIR/package.json" ]] &&
     jq -e '.type == "module"' "$DESKTOP_DIR/package.json" >/dev/null &&
     grep -Fq 'require(' "$ICONS_DIR/icon-tool.js" &&
     node --input-type=commonjs --check < "$ICONS_DIR/icon-tool.js" >/dev/null 2>&1; then
    # 创建上游复制图标工具的临时目录。
    mkdir -p -- "$PACKAGING_TOOLS_DIR"

    # 为该临时目录声明 CommonJS 模块类型。
    printf '%s\n' '{"type":"commonjs"}' > "$PACKAGING_TOOLS_DIR/package.json"
  fi

  # 使用上游已准备的工具生成 AppImage，并设置正式产物版本。
  pnpm --dir "$DESKTOP_DIR" run builder --prepared "$PACKAGER" --native-deps "$DESKTOP_DIR/build/native-deps" \
    --linux AppImage --publish never "-c.extraMetadata.version=$VERSION"
)

############### 整理产物 ###############

# 定位上游生成的唯一 AppImage。
shopt -s nullglob
APPIMAGES=("$SOURCE_DIR"/apps/desktop/release/*.AppImage)
if (( ${#APPIMAGES[@]} != 1 )); then
  printf '错误：预期生成 1 个 AppImage，实际生成 %s 个。\n' "${#APPIMAGES[@]}" >&2
  exit 1
fi

# 复制 AppImage 到发布目录。
cp -- "${APPIMAGES[0]}" "$APPIMAGE"

# 打包成功后用公共脚本记下版本。
"$SCRIPT_DIR/../common/build/save_appimage_version.sh" "$APPIMAGE" "${SOURCE_REF#v}" "$DIST_DIR/version.txt"
