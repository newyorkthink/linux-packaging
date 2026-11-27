#!/usr/bin/env bash

# 从 PKGBUILD 的字面量字段读取来源，下载并校验文件，再保存版本。
download_pkgbuild_asset() (
  set -Eeuo pipefail

  if (( $# < 6 )); then
    printf '%s\n' \
      '用法：download_pkgbuild_asset <PKGBUILD URL> <地址字段> <SHA-256 字段> <版本字段> <输出文件> <版本文件>' \
      '      [--url-regex <正则>] [--version-regex <正则>] [--downloader <下载器>]' \
      '      [--resolve-url <函数> | --resolve-json-url <Cookie URL> <POST URL> <请求字段> <返回字段路径>]' \
      '      [--resolve-header <请求头>]...' >&2
    return 2
  fi

  pkgbuild_url="$1"
  url_field="$2"
  checksum_field="$3"
  version_field="$4"
  output="$5"
  version_file="$6"
  shift 6

  url_regex=''
  version_regex=''
  resolver=''
  downloader=''
  resolve_args=()
  resolve_headers=()
  while (( $# )); do
    if (( $# < 2 )) || [[ -z "$2" ]]; then
      printf '错误：%s 缺少参数值。\n' "$1" >&2
      return 2
    fi
    case "$1" in
      --url-regex) url_regex="$2" ;;
      --version-regex) version_regex="$2" ;;
      --resolve-url) resolver="$2" ;;
      --downloader) downloader="$2" ;;
      --resolve-json-url)
        if (( $# < 5 )) || (( ${#resolve_args[@]} )); then
          printf '错误：--resolve-json-url 需要四个参数，且只能设置一次。\n' >&2
          return 2
        fi
        resolve_args=("$1" "$2" "$3" "$4" "$5")
        shift 5
        continue
        ;;
      --resolve-header) resolve_headers+=("$1" "$2") ;;
      *)
        printf '错误：未知参数 %s。\n' "$1" >&2
        return 2
        ;;
    esac
    shift 2
  done

  https_url='^https://[^/?#@[:space:]]+([/?#][^[:space:]]*)?$'
  identifier='^[A-Za-z_][A-Za-z0-9_]*$'
  if [[ ! "$pkgbuild_url" =~ $https_url || ! "$url_field" =~ $identifier ||
        ! "$checksum_field" =~ $identifier || ! "$version_field" =~ $identifier ]]; then
    printf '错误：必须提供 HTTPS 配方地址和有效的字段名。\n' >&2
    return 2
  fi
  if [[ -n "$resolver" ]] && { [[ ! "$resolver" =~ $identifier ]] || ! declare -F -- "$resolver" >/dev/null; }; then
    printf '错误：地址处理函数须在调用入口前定义。\n' >&2
    return 2
  fi

  if [[ -n "$downloader" && "$downloader" != curl && "$downloader" != wget && "$downloader" != aria2c ]]; then
    printf '错误：下载器只能为 curl、wget 或 aria2c。\n' >&2
    return 2
  fi
  if (( ${#resolve_args[@]} )); then
    if [[ -n "$resolver" ]]; then
      printf '错误：两种地址处理方式只能选择一种。\n' >&2
      return 2
    fi
    resolve_args+=("${resolve_headers[@]}" --)
  elif (( ${#resolve_headers[@]} )); then
    printf '错误：--resolve-header 需要同时指定 --resolve-json-url。\n' >&2
    return 2
  fi

  # 核对两个输出位置，防止版本文件覆盖下载文件。
  if [[ -z "$output" || -z "$version_file" || "$output" == */ || "$version_file" == */ ||
        -d "$output" || -d "$version_file" ]]; then
    printf '错误：输出文件和版本文件必须是文件路径。\n' >&2
    return 2
  fi
  output_path="$(readlink -m -- "$output")" || return
  version_path="$(readlink -m -- "$version_file")" || return
  if [[ "$output_path" == "$version_path" ]]; then
    printf '错误：输出文件和版本文件必须使用不同路径。\n' >&2
    return 2
  fi

  script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)" || return
  download_file="$script_dir/../download/download_file.sh"

  # 下载临时配方并在退出时清理本次使用的文件。
  work_dir="$(mktemp -d "${TMPDIR:-/tmp}/aur-pkgbuild-download.XXXXXXXX")" || return
  version_temp=''
  trap 'rm -rf -- "$work_dir"; if [[ -n "$version_temp" ]]; then rm -f -- "$version_temp"; fi' EXIT
  "$download_file" "$pkgbuild_url" "$work_dir/PKGBUILD" >&2 || return

  # 只解析行首的独立赋值，以文本方式读取指定字段。
  metadata="$(
    LC_ALL=C awk -v url_field="$url_field" -v checksum_field="$checksum_field" -v version_field="$version_field" '
      function fail(message) {
        print "错误：" message > "/dev/stderr"
        failed = 1
        exit 1
      }

      function read_literal(value,    quote, last, suffix) {
        sub(/^[[:blank:]]+/, "", value)
        sub(/[[:blank:]]+$/, "", value)
        quote = substr(value, 1, 1)
        if (quote == "\"" || quote == single_quote) {
          value = substr(value, 2)
          last = index(value, quote)
          suffix = substr(value, last + 1)
          if (!last || suffix !~ /^([[:blank:]]+#.*)?$/)
            fail("配方字段不是单行字面量：" field)
          value = substr(value, 1, last - 1)
          if (quote == "\"" && value ~ /[$`\\]/)
            fail("配方字段包含动态值或转义：" field)
        } else {
          sub(/[[:blank:]]+#.*$/, "", value)
          if (value !~ /^[0-9A-Za-z._~:\/?@%#=,+-]+$/)
            fail("配方字段不是单行字面量：" field)
        }
        return value
      }

      BEGIN { single_quote = sprintf("%c", 39) }
      {
        sub(/\r$/, "", $0)
        if (!match($0, /^[A-Za-z_][A-Za-z0-9_]*=/))
          next
        field = substr($0, 1, RLENGTH - 1)
        if (field != url_field && field != checksum_field && field != version_field)
          next
        if (field in values)
          fail("配方字段重复：" field)
        values[field] = read_literal(substr($0, RLENGTH + 1))
      }
      END {
        if (failed)
          exit 1
        if (!(url_field in values) || !(checksum_field in values))
          fail("配方缺少地址字段或 SHA-256 字段。")
        print values[url_field]
        print values[checksum_field]
        print values[version_field]
      }
    ' "$work_dir/PKGBUILD"
  )" || return
  mapfile -t fields <<< "$metadata"
  asset_url="${fields[0]}"
  checksum="${fields[1]:-}"
  version="${fields[2]:-}"

  if [[ ! "$asset_url" =~ $https_url || ! "$checksum" =~ ^[0-9A-Fa-f]{64}$ ]]; then
    printf '错误：配方必须给出有效的 HTTPS 下载地址和完整的 SHA-256。\n' >&2
    return 1
  fi
  checksum="${checksum,,}"
  if [[ -n "$url_regex" ]] && [[ ! "$asset_url" =~ $url_regex ]]; then
    printf '错误：配方下载地址不符合指定规则。\n' >&2
    return 1
  fi

  # 优先使用原始地址中的版本，未匹配时使用配方版本字段。
  if [[ -n "$version_regex" ]]; then
    if [[ "$asset_url" =~ $version_regex ]]; then
      if (( ${#BASH_REMATCH[@]} < 2 || ${#BASH_REMATCH[@]} > 3 )) || [[ -z "${BASH_REMATCH[1]}" ]]; then
        printf '错误：版本正则必须提供一个或两个捕获组，首组不能为空。\n' >&2
        return 1
      fi
      version="${BASH_REMATCH[1]}"
      if [[ -n "${BASH_REMATCH[2]:-}" ]]; then
        version+="-${BASH_REMATCH[2]}"
      fi
    elif (( $? == 2 )); then
      printf '错误：版本正则无效。\n' >&2
      return 2
    fi
  fi
  if [[ ! "$version" =~ ^[0-9][0-9A-Za-z.+:~_-]*$ ]]; then
    printf '错误：无法取得有效版本。\n' >&2
    return 1
  fi

  # 在调用方提供地址处理函数时，使用它返回的最终 HTTPS 地址。
  if [[ -n "$resolver" ]]; then
    asset_url="$("$resolver" "$asset_url")" || return
    if [[ ! "$asset_url" =~ $https_url ]]; then
      printf '错误：地址处理函数未返回单一 HTTPS 地址。\n' >&2
      return 1
    fi
  fi

  # 准备临时版本文件，下载和校验通过后才更新正式版本。
  mkdir -p -- "$(dirname -- "$version_file")" || return
  version_temp="$(mktemp -- "$version_file.part.XXXXXXXX")" || return
  printf '%s\n' "$version" > "$version_temp" || return
  # 下载器只用于文件传输，取链接配置由公共下载入口处理。
  download_args=("$asset_url" "$output" "$checksum")
  if [[ -n "$downloader" ]]; then
    download_args+=("" "$downloader")
  fi
  "$download_file" "${resolve_args[@]}" "${download_args[@]}" >&2 || return
  mv -fT -- "$version_temp" "$version_file" || return
  version_temp=''
)

# 无需传入地址处理函数时，也可独立执行公共脚本。
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  download_pkgbuild_asset "$@"
fi
