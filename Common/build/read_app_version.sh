#!/usr/bin/env bash
set -Eeuo pipefail

# 定位公共脚本目录，供版本来源入口复用。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# 显示公共版本读取入口的参数用法。
usage() {
  echo "用法：$0 <package-json|pacman|text|ini|command> <文件路径、包名或程序> [--version-file <版本文件>] [--desktop <桌面入口文件>]... [--section <INI 节> --key <INI 键>] [--field <版本字段编号> -- <程序参数>...]" >&2
  exit 2
}

# 解析版本来源；具体文件路径和软件包名由调用方传入。
if (( $# < 2 )) || [[ -z "$1" || -z "$2" ]]; then
  usage
fi
source_type="$1"
source_value="$2"
shift 2
version_file=
desktop_files=()
version_field=
ini_section=
ini_key=
command_args=()

# 解析可选的构建元数据输出，默认只返回版本。
while (( $# > 0 )); do
  case "$1" in
    --version-file|--desktop)
      (( $# >= 2 )) && [[ -n "$2" ]] || usage
      if [[ "$1" == --version-file ]]; then
        version_file="$2"
      else
        desktop_files+=("$2")
      fi
      shift 2
      ;;
    --section|--key)
      [[ "$source_type" == ini && $# -ge 2 && "${2:-}" =~ ^[A-Za-z0-9_.-]+$ ]] || usage
      if [[ "$1" == --section ]]; then
        [[ -z "$ini_section" ]] || usage
        ini_section="$2"
      else
        [[ -z "$ini_key" ]] || usage
        ini_key="$2"
      fi
      shift 2
      ;;
    --field)
      [[ "$source_type" == command && $# -ge 2 && "${2:-}" =~ ^[1-9][0-9]*$ ]] || usage
      version_field="$2"
      shift 2
      ;;
    --)
      [[ "$source_type" == command ]] || usage
      shift
      command_args=("$@")
      break
      ;;
    *) usage ;;
  esac
done

# 按来源读取版本；新增来源时在这里扩展，现有调用接口保持不变。
case "$source_type" in
  package-json)
    version="$(jq -er '.version | select(type == "string" and length > 0)' "$source_value")"
    ;;
  text)
    version="$(cat -- "$source_value")"
    ;;
  ini)
    [[ -n "$ini_section" && -n "$ini_key" ]] || usage
    # 只读取指定节中唯一的键，兼容 CRLF 以及等号两侧的空白。
    if ! version="$(awk -v section="$ini_section" -v key="$ini_key" '
      function trim(value) {
        sub(/^[[:space:]]+/, "", value)
        sub(/[[:space:]]+$/, "", value)
        return value
      }
      {
        line = trim($0)
        if (line ~ /^[[].*[]]$/) {
          current = substr(line, 2, length(line) - 2)
        } else if (current == section && line !~ /^[#;]/ && (separator = index(line, "="))) {
          if (trim(substr(line, 1, separator - 1)) == key) {
            matches++
            value = trim(substr(line, separator + 1))
          }
        }
      }
      END {
        if (matches != 1) exit 1
        print value
      }
    ' < "$source_value")"; then
      echo "错误：无法读取唯一的 INI 版本 [${ini_section}] ${ini_key}：$source_value" >&2
      exit 1
    fi
    ;;
  pacman)
    version="$("$SCRIPT_DIR/../arch/get_package_version.sh" "$source_value")"
    ;;
  command)
    # 命令参数和输出字段由调用方明确指定，保留程序原有的版本查询方式。
    [[ -n "$version_field" ]] || usage
    command_output="$("$source_value" "${command_args[@]}")"
    version="$(awk -v field="$version_field" 'NR == 1 { print $field; exit }' <<< "$command_output")"
    [[ "$version" =~ ^[0-9]+([.][0-9]+)+([.+-][0-9A-Za-z.-]+)?$ ]] || {
      echo "错误：无法从程序输出解析有效版本：$source_value" >&2
      printf '%s\n' "$command_output" >&2
      exit 1
    }
    ;;
  *) usage ;;
esac

# 无效版本或缺失的桌面文件不能用于生成构建元数据。
[[ -n "$version" && "$version" != *[[:space:]]* ]] || {
  echo "错误：版本为空或包含空白字符：$source_value" >&2
  exit 1
}
for desktop_file in "${desktop_files[@]}"; do
  if [[ ! -f "$desktop_file" ]]; then
    echo "错误：桌面入口文件不存在：$desktop_file" >&2
    exit 1
  fi
done

# 按调用方要求保存构建版本，并仅在 desktop 缺少版本字段时追加。
if [[ -n "$version_file" ]]; then
  printf '%s\n' "$version" > "$version_file"
fi
for desktop_file in "${desktop_files[@]}"; do
  grep -q '^X-AppImage-Version=' "$desktop_file" \
    || printf 'X-AppImage-Version=%s\n' "$version" >> "$desktop_file"
done

# 标准输出只返回版本，供调用方赋给 VERSION。
printf '%s\n' "$version"
