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
SOURCE_REF="$("$SCRIPT_DIR/../common/github/download_latest_stable_release_source.sh" \
  NousResearch/hermes-agent "$SOURCE_DIR")"

############### 核心打包 ###############

(
  # 进入上游源码目录。
  cd -- "$SOURCE_DIR"

  # 从正式标签读取官方构建声明，并核对标签对象和源码提交。
  RELEASE_CLAIM="$(python3 -B - "$SOURCE_REF" <<'PY'
import subprocess
import sys

from scripts.releases.versioning import parse_attempt_ref, tag_record, version_from_tag


def git(*args):
    return subprocess.check_output(["git", *args], encoding="utf-8").strip()


release_tag = sys.argv[1]
release_ref = f"refs/tags/{release_tag}"
release = tag_record(git("for-each-ref", "--format=%(contents)", release_ref))
claim_tag = release["claimTag"]
claim = parse_attempt_ref(claim_tag)
version = version_from_tag(release_tag)
if claim is None or claim[0] != version or release["version"] != version:
    raise SystemExit("错误：官方构建声明与正式版本不匹配。")

claim_ref = f"refs/tags/{claim_tag}"
head, release_commit, claim_object, claim_commit = git(
    "rev-parse", "HEAD", f"{release_ref}^{{commit}}", f"{claim_ref}^{{tag}}", f"{claim_ref}^{{commit}}"
).splitlines()
if (
    not (head == release_commit == claim_commit == release["commit"])
    or claim_object != release["claimTagObject"]
):
    raise SystemExit("错误：官方构建声明的标签对象或源码提交不匹配。")

print(f"{claim_tag}\t{claim_object}")
PY
)"

  # 读取官方构建入口所需的声明标签和对象。
  IFS=$'\t' read -r RELEASE_CLAIM_TAG RELEASE_CLAIM_OBJECT <<< "$RELEASE_CLAIM"

  # 使用上游正式版本的构建流程准备打包所需的依赖和工具。
  RELEASE_CLAIM_TAG="$RELEASE_CLAIM_TAG" RELEASE_CLAIM_OBJECT="$RELEASE_CLAIM_OBJECT" \
    python3 scripts/bundles/desktop.py --tag "$SOURCE_REF" --variant bundled --prepare-only

  # 从上游构建清单读取打包工具和 Node.js 的路径。
  PREPARED=".build/desktop-job/prepared.json"
  PACKAGER="$(jq -er '.packager' "$PREPARED")"
  NODE="$(jq -er '.node' "$PREPARED")"
  ICONS_DIR="$(jq -r '.toolsets.icons // empty' "$PACKAGER")"
  PACKAGING_TOOLS_DIR="apps/desktop/build/prepared-packaging-tools"

  # 仅处理缺少模块声明且会被 Desktop 当作 ES 模块加载的 CommonJS 图标工具。
  if [[ -n "$ICONS_DIR" && -f "$ICONS_DIR/icon-tool.js" && ! -e "$ICONS_DIR/package.json" &&
        ! -e "$PACKAGING_TOOLS_DIR/package.json" ]] &&
     jq -e '.type == "module"' apps/desktop/package.json >/dev/null &&
     grep -Fq 'require(' "$ICONS_DIR/icon-tool.js" &&
     "$NODE" --input-type=commonjs --check < "$ICONS_DIR/icon-tool.js" >/dev/null 2>&1; then
    # 创建上游复制图标工具的临时目录。
    mkdir -p -- "$PACKAGING_TOOLS_DIR"

    # 为该临时目录声明 CommonJS 模块类型。
    printf '%s\n' '{"type":"commonjs"}' > "$PACKAGING_TOOLS_DIR/package.json"
  fi

  # 使用上游已经准备的依赖和工具生成 Linux AppImage。
  python3 scripts/bundles/desktop.py --prepared "$PREPARED"
)

############### 整理产物 ###############

# 定位上游生成的唯一 AppImage。
shopt -s nullglob
APPIMAGES=("$SOURCE_DIR"/apps/desktop/release/*.AppImage)
if (( ${#APPIMAGES[@]} != 1 )); then
  printf '错误：预期生成 1 个 AppImage，实际生成 %s 个。\n' "${#APPIMAGES[@]}" >&2
  exit 1
fi

# 复制 AppImage 到发布目录并设置执行权限。
install -m 0755 -- "${APPIMAGES[0]}" "$APPIMAGE"

# 打包成功后用公共脚本记下版本。
"$SCRIPT_DIR/../common/build/save_appimage_version.sh" "$APPIMAGE" "${SOURCE_REF#v}" "$DIST_DIR/version.txt"
