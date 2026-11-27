#!/usr/bin/env bash
# 核查仓库已跟踪文件与工作区未跟踪文件的权限模式，并支持按明确清单修正权限。
set -Eeuo pipefail

# 显示脚本帮助，不访问仓库或修改文件。
usage() {
  cat <<'HELP'
用法：
  ./check_file_modes.sh                        只读扫描全仓已跟踪文件及未跟踪文件的权限模式
  ./check_file_modes.sh --fix -- <文件...>     仅修正明确列出的普通文件工作区执行位，不改文件内容
  ./check_file_modes.sh --help | -h | /help    显示帮助，不访问仓库

规则：
  - *.sh 统一要求 100755（工作区 0755）。
  - 文档、配置、图片、补丁、源码等普通文件统一要求 100644（工作区 0644）。
  - 符号链接（120000）与子模块（160000）跳过检查；无固定扩展名规则的可执行文件（如 AppRun、wrapper、
    直接执行的 Python 脚本或 hook）保留其既有 Git 模式，同时核对工作区执行位是否漂移。
  - --fix 只执行 chmod 0755 / 0644，不自动 git add 或提交，便于后续交给 sync_repo.sh / git_commit.py。
  - 退出码：0 为检查通过、修正完成或帮助；1 为发现异常或执行失败；2 为参数错误。
HELP
}

# 输出错误并退出。
fail() {
  printf '错误：%s\n' "$*" >&2
  exit 1
}

# 输出参数错误并退出。
usage_error() {
  printf '参数错误：%s；使用 --help、-h 或 /help 查看说明。\n' "$*" >&2
  exit 2
}

# 解析命令行参数，先于仓库检查执行。
parse_args() {
  mode=check
  fix_paths=()
  if (( $# == 0 )); then
    return
  fi
  case "$1" in
    --help|-h|/help)
      (( $# == 1 )) || usage_error '帮助选项不能与其他参数混用'
      usage
      exit 0
      ;;
    --fix)
      (( $# >= 3 )) || usage_error '--fix 后必须使用 -- 并至少提供一个文件路径'
      [[ "$2" == -- ]] || usage_error '--fix 后必须紧跟 -- 再列出文件路径'
      shift 2
      mode=fix
      fix_paths=("$@")
      ;;
    *)
      usage_error "未知参数：$1"
      ;;
  esac
}

# 所有 Git 调用统一使用字面路径匹配。
repo_git() {
  command git --literal-pathspecs "$@"
}

# 检查运行条件并定位脚本所属 Git 工作区根目录。
locate_repository() {
  (( BASH_VERSINFO[0] > 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] >= 4) )) ||
    fail '需要 Bash 4.4 或更新版本'
  local command_name variable script_path script_dir
  for command_name in git readlink dirname chmod; do
    command -v "$command_name" >/dev/null 2>&1 || fail "缺少命令：$command_name"
  done
  for variable in GIT_DIR GIT_WORK_TREE GIT_COMMON_DIR GIT_INDEX_FILE \
    GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_NAMESPACE; do
    [[ ! -v "$variable" ]] || fail "请先取消仓库定位环境变量：$variable"
  done
  script_path="$(readlink -f -- "${BASH_SOURCE[0]}")" || fail '无法解析脚本真实路径'
  script_dir="$(dirname -- "$script_path")"
  repo_root="$(git -C "$script_dir" rev-parse --show-toplevel)" ||
    fail '脚本必须位于一个已有的 Git 工作区内'
  cd -- "$repo_root"
}

# 按仓库文件权限规范返回明确的目标模式；返回空字符串表示沿用既有用途判断。
expected_mode_for_path() {
  local path="$1"
  local lower="${path,,}"
  local base="${path##*/}"
  case "$lower" in
    *.sh)
      printf '100755'
      return 0
      ;;
    *.md|*.yml|*.yaml|*.json|*.txt|*.desktop|*.png|*.svg|*.jpg|*.jpeg|*.gif|*.ico|*.webp|*.xpm|*.patch|*.diff|*.c|*.h|*.cpp|*.cc|*.hpp|*.conf|*.cfg|*.ini|*.toml|*.xml|*.html|*.css|*.csv|*.tsv|*.service|*.rules|*.list|*.gpg|*.asc|*.key|*.pem|*.crt|*.lock|*.example)
      printf '100644'
      return 0
      ;;
  esac
  case "$base" in
    .gitignore|.gitattributes|.editorconfig|.dockerignore|LICENSE|NOTICE|COPYING|README|Makefile)
      printf '100644'
      return 0
      ;;
  esac
  printf ''
}

# 读取工作区普通文件的当前执行位映射。
worktree_mode() {
  if [[ -x "$1" ]]; then
    printf '100755'
  else
    printf '100644'
  fi
}

# 只读扫描全仓已跟踪文件与未跟踪文件权限。
run_check() {
  local meta path idx_mode expected wt_mode
  local tracked_count=0 untracked_count=0 issue_count=0 notice_count=0
  local -a issues=() notices=()

  # 逐项核对已跟踪文件的 Git 索引模式与工作区执行位。
  while IFS=$'\t' read -r -d '' meta path; do
    idx_mode="${meta%% *}"
    if [[ "$idx_mode" == 120000 || "$idx_mode" == 160000 ]]; then
      continue
    fi
    tracked_count=$((tracked_count + 1))
    expected="$(expected_mode_for_path "$path")"
    if [[ -L "$path" ]]; then
      continue
    fi
    if [[ ! -e "$path" ]]; then
      if [[ -n "$expected" && "$idx_mode" != "$expected" ]]; then
        issues+=("$path | 索引=$idx_mode | 目标=$expected | 已跟踪文件模式不符")
        issue_count=$((issue_count + 1))
      fi
      continue
    fi
    wt_mode="$(worktree_mode "$path")"
    if [[ -n "$expected" ]]; then
      if [[ "$wt_mode" != "$expected" ]]; then
        issues+=("$path | 索引=$idx_mode 工作区=$wt_mode | 目标=$expected | 权限不符合仓库规范")
        issue_count=$((issue_count + 1))
      elif [[ "$idx_mode" != "$expected" ]]; then
        notices+=("$path | 索引=$idx_mode 工作区=$wt_mode | 目标=$expected | 工作区已修正，待提交生效")
        notice_count=$((notice_count + 1))
      fi
    elif [[ "$wt_mode" != "$idx_mode" ]]; then
      issues+=("$path | 索引=$idx_mode 工作区=$wt_mode | 目标=$idx_mode | 索引与工作区执行位不一致")
      issue_count=$((issue_count + 1))
    fi
  done < <(repo_git ls-files -z --stage)

  # 核对工作区未跟踪（且未被 .gitignore 忽略）的新文件权限。
  while IFS= read -r -d '' path; do
    if [[ -L "$path" || ! -f "$path" ]]; then
      continue
    fi
    untracked_count=$((untracked_count + 1))
    expected="$(expected_mode_for_path "$path")"
    if [[ -z "$expected" ]]; then
      continue
    fi
    wt_mode="$(worktree_mode "$path")"
    if [[ "$wt_mode" != "$expected" ]]; then
      issues+=("$path | 未跟踪 工作区=$wt_mode | 目标=$expected | 新文件工作区权限不符合仓库规范")
      issue_count=$((issue_count + 1))
    fi
  done < <(repo_git ls-files -z --others --exclude-standard)

  if (( notice_count > 0 )); then
    printf '待提交模式变更（%d 项）：\n' "$notice_count"
    printf '  - %s\n' "${notices[@]}"
  fi

  if (( issue_count > 0 )); then
    printf '发现 %d 个权限异常文件：\n' "$issue_count" >&2
    printf '  - %s\n' "${issues[@]}" >&2
    return 1
  fi

  printf '全仓 Git 文件模式检查通过（已扫描 %d 个已跟踪文件，%d 个未跟踪文件），未发现异常。\n' \
    "$tracked_count" "$untracked_count"
}

# 校验 --fix 传入的显式文件路径清单。
validate_fix_paths() {
  local path rest part prefix existing
  local -a seen=()
  for path in "${fix_paths[@]}"; do
    [[ -n "$path" && "$path" != /* && "$path" != */ && "$path" != *//* ]] ||
      usage_error '文件必须使用相对仓库根目录的完整文件路径'
    rest="$path"
    prefix=''
    while :; do
      part="${rest%%/*}"
      [[ -n "$part" && "$part" != . && "$part" != .. && "${part,,}" != .git ]] ||
        usage_error '路径不能包含 .、.. 或 Git 元数据目录'
      prefix="${prefix:+$prefix/}$part"
      if [[ "$rest" == */* ]]; then
        [[ ! -L "$prefix" ]] || usage_error '文件路径不能穿过符号链接目录'
        rest="${rest#*/}"
      else
        break
      fi
    done
    for existing in "${seen[@]}"; do
      [[ "$existing" != "$path" ]] || usage_error "文件路径重复：$path"
    done
    seen+=("$path")
    [[ ! -L "$path" ]] || usage_error "不支持对符号链接修改模式：$path"
    [[ -f "$path" ]] || usage_error "目标文件不存在或不是普通文件：$path"
  done
}

# 仅对明确列出的普通文件修正工作区执行位，不改文件内容，不自动暂存。
run_fix() {
  local path stage_line idx_mode expected target wt_mode chmod_mode
  local fixed_count=0
  validate_fix_paths

  for path in "${fix_paths[@]}"; do
    stage_line="$(repo_git ls-files --stage -- "$path")" || fail "无法读取文件索引状态：$path"
    expected="$(expected_mode_for_path "$path")"
    if [[ -n "$stage_line" ]]; then
      idx_mode="${stage_line%% *}"
      if [[ "$idx_mode" == 120000 || "$idx_mode" == 160000 ]]; then
        fail "拒绝修改符号链接或子模块权限：$path"
      fi
      if [[ -n "$expected" ]]; then
        target="$expected"
      else
        target="$idx_mode"
      fi
    else
      if [[ -z "$expected" ]]; then
        fail "未跟踪文件没有固定扩展名规则，请人工确认其实际执行用途后手动设置权限：$path"
      fi
      target="$expected"
    fi

    wt_mode="$(worktree_mode "$path")"
    if [[ "$wt_mode" == "$target" ]]; then
      printf '无需修改：%s（当前工作区已为 %s）\n' "$path" "$target"
      continue
    fi

    if [[ "$target" == 100755 ]]; then
      chmod_mode=0755
    else
      chmod_mode=0644
    fi
    # 只调整目标文件的执行位，保留原文件内容不变。
    chmod "$chmod_mode" -- "$path"
    printf '已修正：%s（工作区 %s -> %s，权限 %s）\n' "$path" "$wt_mode" "$target" "$chmod_mode"
    fixed_count=$((fixed_count + 1))
  done

  printf '权限修正完成：共更新 %d 个文件的工作区权限（未自动暂存或提交）。\n' "$fixed_count"
}

# 脚本主入口。
main() {
  parse_args "$@"
  locate_repository
  if [[ "$mode" == check ]]; then
    run_check
  else
    run_fix
  fi
}

main "$@"
