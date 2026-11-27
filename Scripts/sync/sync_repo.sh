#!/usr/bin/env bash
# 同步脚本所在的 Git 仓库；仓库、分支和认证均使用当前检出的配置。
set -Eeuo pipefail

usage() {
  cat <<'HELP'
用法：
  ./sync_repo.sh pull                拉取当前分支的上游更新，只允许快进
  ./sync_repo.sh push                只推送当前分支已有的提交
  ./sync_repo.sh push -m "提交说明" -- "文件1" "文件2"
                                    只提交列明文件，然后推送
  ./sync_repo.sh                     不带参数时默认执行 pull
  ./sync_repo.sh --help | -h | /help  显示帮助，不访问仓库或网络

参数：
  pull                工作区和暂存区必须干净；历史分叉时停止。
  push                推送当前分支全部未推送提交，不自动合并远端。
  -m, --message 文本  与文件清单一起使用；文本可包含真实换行。
  -- 文件...          路径相对仓库根目录，按字面匹配，不展开通配符。
                       只接受单个文件路径；重命名须列出旧、新两条路径。

运行条件：
  Bash 4.4+、Git 2.31+、GNU readlink 和常用 Linux 工具。
  已有非空 git clone 工作区、当前分支唯一上游及可用认证。
  拉取地址须唯一；推送还要求收发地址相同，不支持三角或镜像推送。
  可从任何目录调用；更新的是脚本自身所在的仓库。
  自动提交模式拒绝已有暂存内容，其他未列明改动保持原状。
  请先保存编辑器内容；脚本无法检测尚未落盘的编辑缓冲区。

不会自动 stash、reset、clean、rebase、强推、切分支或安装依赖。
提交成功但推送失败时保留本地提交；之后使用 push 重试。
Git hooks、签名及认证设置照常生效；不要同时运行其他 Git 写操作。
推送可能触发目标仓库现有的 CI 或发布；脚本不添加跳过标记。
退出码：0 为完成或帮助；2 为参数错误；其他非零表示未完成。
HELP
}

fail() {
  printf '错误：%s\n' "$*" >&2
  exit 1
}

usage_error() {
  printf '参数错误：%s；使用 --help、-h 或 /help 查看说明。\n' "$*" >&2
  exit 2
}

# 参数检查先于环境检查，帮助在未克隆、未认证时也能显示。
parse_args() {
  action=pull
  message=''
  commit_requested=false
  paths=()
  if (( $# == 1 )); then
    case "$1" in --help|-h|/help) usage; exit 0 ;; esac
  fi
  if (( $# > 0 )); then
    case "$1" in pull|push) action=$1; shift ;; *) usage_error "未知操作：$1" ;; esac
  fi
  if (( $# == 1 )); then
    case "$1" in --help|-h|/help) usage; exit 0 ;; esac
  fi
  if [[ "$action" == pull ]]; then
    (( $# == 0 )) || usage_error 'pull 不接受其他参数'
    return
  fi
  if (( $# == 0 )); then
    return
  fi
  case "$1" in
    -m|--message)
      (( $# >= 4 )) || usage_error '提交说明后需要 -- 和至少一个文件路径'
      message=$2
      [[ -n "${message//[[:space:]]/}" ]] || usage_error '提交说明不能为空'
      [[ "$3" == -- ]] || usage_error '文件清单前必须使用 --'
      shift 3
      paths=("$@")
      commit_requested=true
      ;;
    *) usage_error "未知 push 参数：$1" ;;
  esac
}

# 不接受会把 Git 命令重定向到另一个仓库或暂存区的环境变量。
locate_repository() {
  (( BASH_VERSINFO[0] > 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] >= 4) )) ||
    fail '需要 Bash 4.4 或更新版本'
  local command_name variable script_path script_dir
  for command_name in git readlink dirname cat mktemp rm; do
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
  branch_ref="$(git symbolic-ref --quiet HEAD)" || fail '当前为 detached HEAD，请先明确现有分支'
  head_sha="$(git rev-parse --verify 'HEAD^{commit}')" || fail '当前分支还没有提交'
}

# 所有文件清单按字面路径处理，避免把方括号等文件名解释成 pathspec。
repo_git() {
  command git --literal-pathspecs "$@"
}

read_optional_config() {
  local status
  if config_value="$(repo_git config --get "$1")"; then
    :
  else
    status=$?
    (( status == 1 )) || fail "无法读取 Git 配置项：$1"
    config_value=''
  fi
}

require_idle() {
  local state state_path unmerged config_status
  for state in MERGE_HEAD CHERRY_PICK_HEAD REVERT_HEAD rebase-apply rebase-merge sequencer BISECT_LOG; do
    state_path="$(repo_git rev-parse --git-path "$state")" || fail '无法读取 Git 操作状态'
    [[ ! -e "$state_path" ]] || fail "存在未完成的 Git 操作：$state"
  done
  unmerged="$(repo_git ls-files --unmerged)" || fail '无法检查未合并文件'
  [[ -z "$unmerged" ]] || fail '存在未解决的冲突'
  if config_value="$(repo_git config --type=bool --get core.sparseCheckout)"; then
    [[ "$config_value" == false ]] || fail '当前为稀疏检出，请先明确需要同步的完整工作区'
  else
    config_status=$?
    (( config_status == 1 )) || fail '稀疏检出配置无效'
  fi
}

# 只处理当前分支唯一上游，不猜测 origin/main 或静默改用另一推送目标。
resolve_target() {
  local branch merge_refs fetch_urls push_urls mirror_status
  branch=${branch_ref#refs/heads/}
  remote="$(repo_git for-each-ref --format='%(upstream:remotename)' "$branch_ref")"
  remote_ref="$(repo_git for-each-ref --format='%(upstream:remoteref)' "$branch_ref")"
  upstream_ref="$(repo_git for-each-ref --format='%(upstream)' "$branch_ref")"
  merge_refs="$(repo_git config --get-all "branch.$branch.merge")" ||
    fail '当前分支没有配置上游'
  [[ -n "$remote" && "$remote" != . && "$remote" != -* &&
    "$remote" != *$'\n'* && "$remote_ref" == refs/heads/* &&
    "$remote_ref" != *$'\n'* && "$upstream_ref" == refs/remotes/* &&
    "$upstream_ref" != *$'\n'* && "$merge_refs" == "$remote_ref" ]] ||
    fail '需要一个明确的远端上游分支，不支持多个上游或本地上游'
  repo_git check-ref-format "$remote_ref" || fail '上游分支引用无效'
  repo_git check-ref-format "$upstream_ref" || fail '远端跟踪引用无效'
  fetch_urls="$(repo_git remote get-url --all -- "$remote")" || fail '无法读取上游远端'
  [[ -n "$fetch_urls" && "$fetch_urls" != *$'\n'* ]] ||
    fail '上游远端必须只有一个拉取地址'
  if [[ "$action" == push ]]; then
    push_urls="$(repo_git remote get-url --push --all -- "$remote")" || fail '无法读取推送地址'
    [[ -n "$push_urls" && "$push_urls" != *$'\n'* && "$push_urls" == "$fetch_urls" ]] ||
      fail '仅支持拉取与推送使用同一个唯一地址的远端'
    read_optional_config "branch.$branch.pushRemote"
    [[ -z "$config_value" || "$config_value" == "$remote" ]] ||
      fail '当前分支配置了不同的 pushRemote，停止以免推错目标'
    read_optional_config remote.pushDefault
    [[ -z "$config_value" || "$config_value" == "$remote" ]] ||
      fail '配置了不同的 pushDefault，停止以免推错目标'
    if config_value="$(repo_git config --type=bool --get "remote.$remote.mirror")"; then
      [[ "$config_value" == false ]] || fail '不支持镜像推送远端'
    else
      mirror_status=$?
      (( mirror_status == 1 )) || fail '远端 mirror 配置无效'
    fi
  fi
}

require_head() {
  [[ "$(repo_git symbolic-ref --quiet HEAD)" == "$branch_ref" &&
    "$(repo_git rev-parse --verify 'HEAD^{commit}')" == "$head_sha" ]] ||
    fail '执行期间当前分支或 HEAD 已变化，停止并保留现场'
}

require_clean() {
  local status_text
  status_text="$(repo_git status --porcelain=v1 --untracked-files=normal --ignore-submodules=none)" ||
    fail '无法读取工作区状态'
  [[ -z "$status_text" ]] || fail '存在未提交改动或未跟踪文件，请先处理后再拉取'
}

require_no_staged() {
  local status
  if repo_git diff --cached --quiet --exit-code --ignore-submodules=none; then
    return
  else
    status=$?
    (( status == 1 )) || fail '无法检查暂存区'
    fail '已有暂存内容，自动提交停止；请先处理原暂存内容'
  fi
}

is_ancestor() {
  local status
  if repo_git merge-base --is-ancestor "$1" "$2"; then
    return 0
  else
    status=$?
    (( status == 1 )) && return 1
    fail '无法判断提交关系，可能需要完整历史或检查 Git 状态'
  fi
}

# 获取唯一上游分支的固定快照；不下载所有分支、标签或子模块。
fetch_snapshot() {
  local status
  printf '正在读取当前分支的上游更新……\n'
  if GIT_TERMINAL_PROMPT=0 repo_git fetch --quiet --no-tags --no-recurse-submodules \
    --refmap= -- "$remote" "$remote_ref:$upstream_ref" >/dev/null 2>&1; then
    remote_sha="$(repo_git rev-parse --verify 'FETCH_HEAD^{commit}')" ||
      fail '无法取得本次拉取的提交'
  else
    status=$?
    fail "fetch 失败（Git 退出码 $status）；请检查网络、已有认证、上游分支或远端历史变化。未更新工作区"
  fi
  require_head
}

pull_updates() {
  require_clean
  fetch_snapshot
  require_clean
  if [[ "$head_sha" == "$remote_sha" ]]; then
    printf '当前分支已与本次远端快照一致，无需更新。\n'
  elif is_ancestor "$head_sha" "$remote_sha"; then
    # 远端修改会正常替换旧跟踪文件；忽略文件发生冲突时也停止。
    repo_git -c merge.autoStash=false merge --ff-only --no-autostash \
      --no-overwrite-ignore "$remote_sha" || fail '快进更新失败，请检查工作区，未强制覆盖'
    printf '拉取完成，当前分支已更新到 %s。\n' "$remote_sha"
  elif is_ancestor "$remote_sha" "$head_sha"; then
    printf '本地含未推送提交，已保留；没有需要拉取的新提交。可明确执行 push。\n'
  else
    fail '本地与远端历史已分叉，请先明确处理冲突；未自动合并或改写历史'
  fi
}

path_is_allowed() {
  local expected
  for expected in "${paths[@]}"; do
    [[ "$1" != "$expected" ]] || return 0
  done
  return 1
}

# 仅接受仓库内的单个文件；支持已删除文件和带空格、方括号的文件名。
validate_paths() {
  local path rest part prefix existing mode_line
  local -a listed=() seen=()
  for path in "${paths[@]}"; do
    [[ -n "$path" && "$path" != /* && "$path" != */ && "$path" != *//* ]] ||
      usage_error '文件必须使用相对仓库根目录的完整文件路径'
    rest=$path
    prefix=''
    while :; do
      part=${rest%%/*}
      [[ -n "$part" && "$part" != . && "$part" != .. && "${part,,}" != .git ]] ||
        usage_error '路径不能包含 .、.. 或 Git 元数据目录'
      prefix="${prefix:+$prefix/}$part"
      if [[ "$rest" == */* ]]; then
        [[ ! -L "$prefix" ]] || usage_error '文件路径不能穿过符号链接目录'
        rest=${rest#*/}
      else
        break
      fi
    done
    for existing in "${seen[@]}"; do
      [[ "$existing" != "$path" ]] || usage_error '文件清单不能重复'
    done
    seen+=("$path")
    [[ ! -d "$path" || -L "$path" ]] || usage_error '请逐个列出文件，不接受整个目录'
    repo_git ls-files -z -- "$path" > "$work_dir/tracked" || fail '无法检查文件是否受 Git 管理'
    mapfile -d '' -t listed < "$work_dir/tracked"
    if (( ${#listed[@]} > 0 )); then
      (( ${#listed[@]} == 1 )) && [[ "${listed[0]}" == "$path" ]] ||
        usage_error '必须提供单个文件，不能提供目录或通配路径'
      mode_line="$(repo_git ls-files --stage -- "$path")" || fail '无法读取文件模式'
      [[ "$mode_line" != 160000\ * ]] || usage_error '不支持把子模块作为普通文件提交'
    else
      [[ -f "$path" || -L "$path" ]] || usage_error '指定的新文件不存在或不是普通文件'
    fi
  done
}

audit_paths() {
  local path
  while IFS= read -r -d '' path; do
    path_is_allowed "$path" || fail '实际提交范围出现未列明文件，已停止；请检查暂存区和本地提交'
  done < "$1"
}

commit_files() {
  local before new_head parents
  require_no_staged
  validate_paths
  require_head
  before=$head_sha
  repo_git add -- "${paths[@]}" || fail '暂存失败，请检查暂存区；未提交或推送'
  repo_git diff --cached --no-renames --ignore-submodules=none --name-only -z > "$work_dir/staged" ||
    fail '无法核对暂存范围'
  audit_paths "$work_dir/staged"
  [[ -s "$work_dir/staged" ]] || fail '列明文件没有可提交变化；已有提交可单独执行 push'
  repo_git commit -m "$message" || fail '提交失败，请检查暂存区、hooks、身份或签名；未推送'
  new_head="$(repo_git rev-parse --verify 'HEAD^{commit}')" || fail '无法读取新提交'
  parents="$(repo_git rev-list --parents -n 1 "$new_head")" || fail '无法核对新提交的父提交'
  [[ "$parents" == "$new_head $before" ]] ||
    fail '提交结果不符合单个普通提交的预期，停止推送并保留现场'
  head_sha=$new_head
  require_head
  repo_git diff-tree --no-commit-id -r --no-renames --ignore-submodules=none --name-only -z "$new_head" > "$work_dir/committed" ||
    fail '无法核对新提交范围；本地提交已保留'
  audit_paths "$work_dir/committed"
  require_no_staged
  printf '已生成本地提交 %s。\n' "$head_sha"
}

push_updates() {
  local status
  if [[ "$commit_requested" == true ]]; then
    require_no_staged
    validate_paths
  fi
  fetch_snapshot
  is_ancestor "$remote_sha" "$head_sha" ||
    fail '远端已有本地未包含的提交，请先完成拉取或冲突处理；未提交或推送'
  if [[ "$commit_requested" == true ]]; then
    commit_files
  fi
  require_head
  printf '正在推送当前分支已有提交；未提交的工作区内容不随本次推送上传。\n'
  # 显式限定一个提交和一个上游分支，不附带标签或推送子模块。
  if GIT_TERMINAL_PROMPT=0 repo_git push --quiet --no-follow-tags --recurse-submodules=no \
    -- "$remote" "$head_sha:$remote_ref" >/dev/null 2>&1; then
    printf '推送完成：%s。\n' "$head_sha"
  else
    status=$?
    fail "push 失败（Git 退出码 $status）；本地提交已保留。检查认证、网络或远端变化后，用 push 重试，勿重复提交"
  fi
}

main() {
  parse_args "$@"
  locate_repository
  require_idle
  resolve_target
  work_dir="$(mktemp -d "${TMPDIR:-/tmp}/sync-repo.XXXXXXXX")" || fail '无法创建本次临时目录'
  trap 'rm -rf -- "$work_dir"' EXIT
  if [[ "$action" == pull ]]; then
    pull_updates
  else
    push_updates
  fi
}

# 本命令块在更新前整体解析；脚本被远端替换后，不继续读取新文件的旧偏移。
{ main "$@"; exit "$?"; }
