#!/usr/bin/env bash
set -Eeuo pipefail

###### 准备构建目录 ######
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
: "${GITHUB_WORKSPACE:?请通过 GitHub Actions 打包}"
BUILD_DIR="$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/micromamba.XXXXXX")"
mkdir -p "$BUILD_DIR/package"

###### 解析官方当前镜像 ######
# 官方 latest 持续更新；本次复制使用解析出的 digest，避免标签中途变化。
IMAGE="ghcr.io/mamba-org/micromamba"
IMAGE_INFO="$(skopeo --override-os linux --override-arch arm64 --command-timeout 10m \
  inspect --retry-times 3 --format '{{.Os}}/{{.Architecture}} {{.Digest}}' "docker://$IMAGE:latest")"
read -r IMAGE_PLATFORM IMAGE_DIGEST <<< "$IMAGE_INFO"
if [[ "$IMAGE_PLATFORM" != linux/arm64 || ! "$IMAGE_DIGEST" =~ ^sha256:[0-9a-f]{64}$ ]]; then
  echo "官方镜像的平台或 digest 不符合 Linux ARM64 要求：$IMAGE_INFO" >&2
  exit 1
fi

###### 复制完整 Linux 运行环境 ######
# 保留官方镜像的 glibc、证书、micromamba 和元数据，不在 Android 上重编 Python。
skopeo --override-os linux --override-arch arm64 --command-timeout 20m \
  copy --retry-times 3 "docker://$IMAGE@$IMAGE_DIGEST" \
  "oci-archive:$BUILD_DIR/package/micromamba.oci.tar"

###### 整理发布产物 ######
# 归档包含 Termux 启动脚本和可供 PRoot-Distro 导入的 OCI 镜像。
install -m 755 "$SCRIPT_DIR/micromamba" "$BUILD_DIR/package/micromamba"
cp "$SCRIPT_DIR/README.md" "$BUILD_DIR/package/README.md"
# 记录实际镜像来源，不把本次版本固定为后续构建版本。
printf '%s\n' "$IMAGE@$IMAGE_DIGEST" > "$BUILD_DIR/package/SOURCE.txt"
git -C "$SCRIPT_DIR" rev-parse HEAD >> "$BUILD_DIR/package/SOURCE.txt"
cd "$BUILD_DIR/package"
# 提供镜像和启动脚本的校验值。
sha256sum micromamba.oci.tar micromamba > SHA256SUMS
# 保持稳定发布名；手机端按 README 导入一次即可。
tar -czvf "$GITHUB_WORKSPACE/micromamba.termux.tar.gz" \
  micromamba.oci.tar micromamba README.md SOURCE.txt SHA256SUMS
sha256sum "$GITHUB_WORKSPACE/micromamba.termux.tar.gz"
