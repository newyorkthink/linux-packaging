#!/usr/bin/env bash

# 启用严格模式，在命令执行失败、引用未定义变量或管道执行失败时退出。
set -Eeuo pipefail

# 仅在本次 AppDir 的官方运行目录与专属依赖目录中准备运行库。
if (( $# != 1 )) || [[ -z "$1" ]]; then
    echo "用法：$0 <AppDir>" >&2
    exit 2
fi
APPDIR="$(readlink -m -- "$1")"
[[ -d "$APPDIR" && "$APPDIR" != / ]] || {
    echo "错误：AppDir 必须存在且不能是根目录。" >&2
    exit 1
}
RELEASE_DIR="$APPDIR/opt/dingtalk/release"
CEF_LIB_DIR="$RELEASE_DIR/plugins/dtwebview"
RUNTIME_LIB="$APPDIR/usr/lib/dingtalk-runtime"
DINGTALK_LIBRARY_PATH="$RELEASE_DIR:$CEF_LIB_DIR:$RUNTIME_LIB"
nss_target="$RELEASE_DIR"

# 创建当前应用独立的外部依赖目录。
mkdir -p "$RUNTIME_LIB"

log() {
    printf '[DingTalk] %s\n' "$*"
}

die() {
    printf '错误：%s\n' "$*" >&2
    exit 1
}

# 保留同一发行版的完整 NSS/NSPR 清单；复制由主 build 的公共入口完成。
nss_files=(
  libfreebl3.chk
  libfreebl3.so
  libfreeblpriv3.chk
  libfreeblpriv3.so
  libnspr4.so
  libnss3.so
  libnssckbi.so
  libnssdbm3.chk
  libnssdbm3.so
  libnssutil3.so
  libplc4.so
  libplds4.so
  libsmime3.so
  libsoftokn3.chk
  libsoftokn3.so
  libssl3.so
)


# 沿用既有 NSS 依赖与符号版本检查，避免混用不同运行库集合。
check_dependencies() {
  local target="$1"
  local dependencies

  dependencies="$(LD_LIBRARY_PATH="$nss_target" ldd "$target")"
  printf '%s\n' "$dependencies"
  if grep -F 'not found' <<<"$dependencies"; then
    echo "NSS/NSPR 组件仍存在缺失依赖：$target" >&2
    exit 1
  fi
}

check_symbol_versions() {
  local consumer="$1"
  local provider="$2"
  local prefix="$3"
  local required_versions provided_versions version

  required_versions="$(
    readelf --version-info "$consumer" 2>/dev/null \
      | awk -v prefix="$prefix" '{
          for (i = 1; i <= NF; i++)
            if ($i == "Name:" && $(i + 1) ~ ("^" prefix "_"))
              print $(i + 1)
        }' \
      | sort -u
  )"
  provided_versions="$(
    readelf --version-info "$provider" 2>/dev/null \
      | awk -v prefix="$prefix" '{
          for (i = 1; i <= NF; i++)
            if ($i == "Name:" && $(i + 1) ~ ("^" prefix "_"))
              print $(i + 1)
        }' \
      | sort -u
  )"

  while IFS= read -r version; do
    [[ -z "$version" ]] && continue
    if ! grep -Fxq "$version" <<<"$provided_versions"; then
      echo "符号版本不匹配：$(basename "$consumer") 需要 $version" >&2
      exit 1
    fi
  done <<<"$required_versions"
}

for nss_file in "${nss_files[@]}"; do
  [[ "$nss_file" == *.so ]] || continue
  check_dependencies "$nss_target/$nss_file"
  check_symbol_versions \
    "$nss_target/$nss_file" "$nss_target/libnssutil3.so" NSSUTIL
  check_symbol_versions \
    "$nss_target/$nss_file" "$nss_target/libnspr4.so" NSPR
done


# 新内核和 glibc 会拒绝加载带可执行栈标记的钉钉私有库。
# 对所有 ELF 文件执行幂等清理，覆盖 dingtalk_dll.so、会议库及后续版本新增库。
log "清除钉钉 ELF 文件的可执行栈标记"
while IFS= read -r -d '' target; do
    readelf -h "$target" >/dev/null 2>&1 || continue
    elf_type="$(readelf -h "$target" | awk '/^[[:space:]]*Type:/{print $2; exit}')"
    case "$elf_type" in
        DYN|EXEC) patchelf --clear-execstack "$target" ;;
    esac
done < <(find "$RELEASE_DIR" -type f -print0)

copy_dependency() {
    local source="$1"
    local real source_name real_name

    [[ -f "$source" ]] || return 0
    case "$source" in
        "$RELEASE_DIR"/*|"$RUNTIME_LIB"/*)
            return 0
            ;;
    esac

    source_name="$(basename "$source")"
    case "$source_name" in
        ld-linux*.so*|libc.so.*|libm.so.*|libpthread.so.*|libdl.so.*|librt.so.*|\
        libresolv.so.*|libutil.so.*|libnss_*.so.*|libanl.so.*|libthread_db.so.*|\
        libGL.so.*|libEGL.so.*|libGLX.so.*|libOpenGL.so.*|libvulkan.so.*|\
        libdrm.so.*|libgbm.so.*)
            return 0
            ;;
    esac

    real="$(readlink -f "$source")"
    [[ -f "$real" ]] || return 0
    real_name="$(basename "$real")"

    if [[ ! -e "$RUNTIME_LIB/$real_name" ]]; then
        cp -L "$real" "$RUNTIME_LIB/$real_name"
        chmod 0755 "$RUNTIME_LIB/$real_name"
    fi
    if [[ "$source_name" != "$real_name" ]]; then
        ln -sfn "$real_name" "$RUNTIME_LIB/$source_name"
    fi
}

collect_dependencies() {
    local target="$1"
    local dependency

    readelf -h "$target" >/dev/null 2>&1 || return 0
    while IFS= read -r dependency; do
        case "$dependency" in
            /*) copy_dependency "$dependency" ;;
        esac
    done < <(
        LD_LIBRARY_PATH="$DINGTALK_LIBRARY_PATH" \
            lddtree -l "$target" 2>/dev/null | sort -u
    )
}

# 扫描主程序、Qt/CEF 插件、会议组件和私有库，收集它们在 Ubuntu 24.04 上的外部依赖。
log "收集钉钉所有 ELF 文件的外部动态库"
while IFS= read -r -d '' target; do
    collect_dependencies "$target"
done < <(find "$RELEASE_DIR" -type f -print0)

# 再扫描一次已复制的运行库，保证其递归依赖完整。
while IFS= read -r -d '' target; do
    collect_dependencies "$target"
done < <(find "$RUNTIME_LIB" -type f -print0)


main_dependencies="$(
    LD_LIBRARY_PATH="$DINGTALK_LIBRARY_PATH" \
        ldd "$RELEASE_DIR/com.alibabainc.dingtalk"
)"
printf '%s\n' "$main_dependencies"
if grep -F 'not found' <<<"$main_dependencies"; then
    die "钉钉主程序仍存在缺失动态库。"
fi

missing_dependencies=0
while IFS= read -r -d '' target; do
    readelf -h "$target" >/dev/null 2>&1 || continue
    dependencies="$(LD_LIBRARY_PATH="$DINGTALK_LIBRARY_PATH" ldd "$target" 2>&1 || true)"
    if grep -F 'not found' <<<"$dependencies"; then
        printf '缺失依赖文件：%s\n%s\n' "$target" "$dependencies" >&2
        missing_dependencies=1
    fi
done < <(find "$RELEASE_DIR" "$RUNTIME_LIB" -type f -print0)
[[ "$missing_dependencies" -eq 0 ]] || die "钉钉组件仍存在缺失动态库。"
