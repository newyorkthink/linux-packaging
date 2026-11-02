#!/usr/bin/env bash
set -Eeuo pipefail

TARGET_DIR="${1:-}"

WITH_NSPR="${2:-}"

(( $# >= 1 && $# <= 2 )) && [[ -n "$TARGET_DIR" && ( -z "$WITH_NSPR" || "$WITH_NSPR" == --with-nspr ) ]] || {
  echo "用法：$0 <目标 lib 目录> [--with-nspr]" >&2
  exit 1
}

# NSS 核心库与 dlopen 模块必须来自同一发行版运行库集合，避免包内 NSS 与宿主机版本混用。
MULTIARCH="$(dpkg-architecture -qDEB_HOST_MULTIARCH)"
# 优先沿用完整的 nss 子目录；模块平铺或旧子目录不完整时，整组使用 multiarch 目录。
NSS_MODULE_DIR="/usr/lib/$MULTIARCH/nss"
if [[ ! -f "$NSS_MODULE_DIR/libnssckbi.so" || ! -f "$NSS_MODULE_DIR/libnssdbm3.so" || ! -f "$NSS_MODULE_DIR/libnssdbm3.chk" || ! -f "$NSS_MODULE_DIR/libsoftokn3.so" || ! -f "$NSS_MODULE_DIR/libsoftokn3.chk" ]]; then
  NSS_MODULE_DIR="/usr/lib/$MULTIARCH"
fi

mkdir -p "$TARGET_DIR"
cp -a \
  "/usr/lib/$MULTIARCH/libnss3.so" \
  "/usr/lib/$MULTIARCH/libnssutil3.so" \
  "/usr/lib/$MULTIARCH/libsmime3.so" \
  "/usr/lib/$MULTIARCH/libssl3.so" \
  "/usr/lib/$MULTIARCH/libfreebl3.so" \
  "/usr/lib/$MULTIARCH/libfreebl3.chk" \
  "/usr/lib/$MULTIARCH/libfreeblpriv3.so" \
  "/usr/lib/$MULTIARCH/libfreeblpriv3.chk" \
  "$NSS_MODULE_DIR/libnssckbi.so" \
  "$NSS_MODULE_DIR/libnssdbm3.so" \
  "$NSS_MODULE_DIR/libnssdbm3.chk" \
  "$NSS_MODULE_DIR/libsoftokn3.so" \
  "$NSS_MODULE_DIR/libsoftokn3.chk" \
  "$TARGET_DIR/"

# 直接封装等调用方需要完整 NSS/NSPR 集合时，按显式参数补齐同一环境的 NSPR。
if [[ "$WITH_NSPR" == --with-nspr ]]; then
  cp -a \
    "/usr/lib/$MULTIARCH/libnspr4.so" \
    "/usr/lib/$MULTIARCH/libplc4.so" \
    "/usr/lib/$MULTIARCH/libplds4.so" \
    "$TARGET_DIR/"
fi
