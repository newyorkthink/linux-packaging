#!/usr/bin/env bash
# 从当前分支对应的远端上游拉取最新快照，并将本地分支与工作区同步至云端状态。
set -Eeuo pipefail

# 显示脚本帮助，不访问仓库或网络。
usage() {
  cat <<'HELP'
用法：
  ./sync_from_remote.sh             拉取云端快照；本地干净时直接快进，有本地改动或未推送提交时先列清单并提示确认
  ./sync_from_remote.sh -y          跳过交互确认，直接以云端最新提交覆盖本地分支与工作区
  ./sync_from_remote.sh --force     与 -y 等价
  ./sync_from_remote.sh --preview   只读拉取并预览将被覆盖的改动、提交与未跟踪文件，不修改工作区
  ./sync_from_remote.sh --help | -h | /help
                                    显示帮助，不访问仓库或网络

说明：
  - 先联网获取远端快照；网络或认证失败时直接退出，不清空本地工作区。
  - 覆盖本地时执行 git reset --hard 与 git clean -fd，只清理未跟踪文件与目录，保留 .gitignore 忽略文件。
  - 仅作用于脚本自身所在的 Git 工作区及当前分支唯一上游；不强推远端，不切分支，不修改远端历史。
  - 退出码：0 为完成或帮助；2 为参数错误；其他非零表示取消或未完成。
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

# 解析命令行参数，先于仓库和网络检查执行。
parse_args() {
  mode=apply
  force=false
  local seen_mode=false
  local arg
  for arg in "$@"; do
    case "$arg" in
      --help|-h|/help)
        if (( $# != 1 )); then
          usage_error '帮助选项不能与其他参数混用'
        fi
        usage
        exit 0
        ;;
      --preview)
        if [[ "$seen_mode" == true ]]; then
          usage_error '重复或互斥的参数：--preview'
        fi
        mode=preview
        seen_mode=true
        ;;
      -y|--force)
        if [[ "$seen_mode" == true ]]; then
          usage_error "重复或互斥的参数：$arg"
        fi
        force=true
        seen_mode=true
        ;;
      *)
        usage_error "未知参数：$arg"
        ;;
    esac
  done
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
  for command_name in git readlink dirname; do
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
  branch_ref="$(git symbolic-ref --quiet HEAD)" || fail '当前为 detached HEAD，请先切换到明确分支'
  head_sha="$(git rev-parse --verify 'HEAD^{commit}')" || fail '当前分支还没有提交'
}

# 确认没有未完成的合并、变基、挑拣、冲突或稀疏检出状态。
require_idle() {
  local state state_path unmerged config_status
  for state in MERGE_HEAD CHERRY_PICK_HEAD REVERT_HEAD rebase-apply rebase-merge sequencer BISECT_LOG; do
    state_path="$(repo_git rev-parse --git-path "$state")" || fail '无法读取 Git 操作状态'
    [[ ! -e "$state_path" ]] || fail "存在未完成的 Git 操作：$state，请先结束该操作"
  done
  unmerged="$(repo_git ls-files --unmerged)" || fail '无法检查未合并文件'
  [[ -z "$unmerged" ]] || fail '存在未解决的合并冲突，请先结束当前冲突状态'
  if config_value="$(repo_git config --type=bool --get core.sparseCheckout)"; then
    [[ "$config_value" == false ]] || fail '当前为稀疏检出，不支持直接全量覆盖'
  else
    config_status=$?
    (( config_status == 1 )) || fail '稀疏检出配置无效'
  fi
}

# 解析当前分支唯一远端上游与拉取地址。
resolve_target() {
  local branch merge_refs fetch_urls
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
}

# 确认执行期间当前分支和 HEAD 未被并发改动。
require_head() {
  [[ "$(repo_git symbolic-ref --quiet HEAD)" == "$branch_ref" &&
    "$(repo_git rev-parse --verify 'HEAD^{commit}')" == "$head_sha" ]] ||
    fail '执行期间当前分支或 HEAD 已变化，停止并保留现场'
}

# 判断第一个提交是否为第二个提交的祖先。
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

# 获取唯一上游分支的最新快照，不下载无关分支、标签或子模块。
fetch_snapshot() {
  local status
  printf '正在读取云端上游最新快照……\n'
  if GIT_TERMINAL_PROMPT=0 repo_git fetch --quiet --no-tags --no-recurse-submodules \
    --refmap= -- "$remote" "$remote_ref:$upstream_ref" >/dev/null 2>&1; then
    remote_sha="$(repo_git rev-parse --verify 'FETCH_HEAD^{commit}')" ||
      fail '无法取得本次拉取的云端提交'
  else
    status=$?
    fail "fetch 失败（Git 退出码 $status）；请检查网络、已有认证或上游分支。未改动本地工作区"
  fi
  require_head
}

# 汇总本地与云端的差异、未推送提交及待清理的未跟踪文件。
collect_state() {
  unpushed_commits="$(repo_git log --oneline "$remote_sha..$head_sha")" ||
    fail '无法读取本地未推送提交'
  incoming_commits="$(repo_git log --oneline "$head_sha..$remote_sha")" ||
    fail '无法读取云端新增提交'
  tracked_changes="$(repo_git status --porcelain=v1 --untracked-files=no --ignore-submodules=none)" ||
    fail '无法读取已跟踪文件改动'
  untracked_preview="$(repo_git clean -nd)" ||
    fail '无法检查未跟踪文件'
  has_local_loss=false
  if [[ -n "$unpushed_commits" || -n "$tracked_changes" || -n "$untracked_preview" ]]; then
    has_local_loss=true
  fi
}

# 输出本次同步的差异摘要。
print_summary() {
  local branch_name
  branch_name=${branch_ref#refs/heads/}
  printf '当前分支：%s\n' "$branch_name"
  printf '本地提交：%s\n' "$head_sha"
  printf '云端提交：%s\n' "$remote_sha"
  if [[ -n "$incoming_commits" ]]; then
    printf '\n云端新增提交：\n%s\n' "$incoming_commits"
  fi
  if [[ -n "$unpushed_commits" ]]; then
    printf '\n将被覆盖的本地未推送提交：\n%s\n' "$unpushed_commits"
  fi
  if [[ -n "$tracked_changes" ]]; then
    printf '\n将被覆盖的已跟踪改动：\n%s\n' "$tracked_changes"
  fi
  if [[ -n "$untracked_preview" ]]; then
    printf '\n将被清理的未跟踪内容（保留 .gitignore 忽略文件）：\n%s\n' "$untracked_preview"
  fi
}

# 执行同步：本地无待丢弃内容时直接快进，否则经确认后重置并清理未跟踪文件。
apply_sync() {
  local short_remote reply new_head remaining
  if [[ "$head_sha" == "$remote_sha" && "$has_local_loss" == false ]]; then
    printf '当前分支已与云端一致（%s），工作区干净，无需覆盖。\n' "$remote_sha"
    return 0
  fi

  print_summary

  if [[ "$mode" == preview ]]; then
    printf '\n预览完成，未修改本地分支或工作区。\n'
    return 0
  fi

  if [[ "$has_local_loss" == false ]]; then
    is_ancestor "$head_sha" "$remote_sha" ||
      fail '本地与远端提交关系异常，已停止；请先核对分支历史'
    # 本地无改动且仅为落后时，直接快进更新到远端提交。
    repo_git -c merge.autoStash=false merge --ff-only --no-autostash \
      --no-overwrite-ignore "$remote_sha" ||
      fail '快进更新失败，请检查是否存在与远端同名的忽略文件'
    printf '\n同步完成：当前分支已快进到云端提交 %s，工作区干净。\n' "$remote_sha"
    return 0
  fi

  if [[ "$force" == false ]]; then
    if [[ ! -t 0 ]]; then
      fail '存在将被丢弃的本地改动、未跟踪文件或未推送提交；非交互模式请先用 --preview 核对后再传入 -y 或 --force'
    fi
    short_remote="$(repo_git rev-parse --short "$remote_sha")"
    printf '\n确认丢弃以上本地内容并用云端提交 %s 覆盖工作区？[y/N] ' "$short_remote"
    read -r reply || reply=''
    case "$reply" in
      y|Y) ;;
      *)
        printf '已取消，未修改本地分支或工作区。\n' >&2
        exit 1
        ;;
    esac
  fi

  require_head

  # 重置当前分支、暂存区与全部已跟踪文件至云端快照。
  repo_git reset --hard "$remote_sha" ||
    fail 'git reset --hard 失败，请检查工作区状态'

  # 清理未跟踪的文件与目录，保留 .gitignore 忽略文件。
  repo_git clean -fd ||
    fail 'git clean -fd 失败，请检查工作区未跟踪文件权限'

  new_head="$(repo_git rev-parse --verify 'HEAD^{commit}')" ||
    fail '无法验证同步后的提交'
  [[ "$new_head" == "$remote_sha" ]] ||
    fail "同步后 HEAD（$new_head）与云端提交（$remote_sha）不一致"
  remaining="$(repo_git status --porcelain=v1 --untracked-files=normal --ignore-submodules=none)" ||
    fail '无法验证同步后的工作区状态'
  [[ -z "$remaining" ]] ||
    fail '同步后工作区仍有残留改动，请检查文件权限或子模块状态'

  printf '\n同步完成：当前分支已强制对齐云端提交 %s，工作区干净。\n' "$remote_sha"
}

# 脚本主入口。
main() {
  parse_args "$@"
  locate_repository
  require_idle
  resolve_target
  fetch_snapshot
  collect_state
  apply_sync
}

# 在脚本被更新前完成整份解析，避免覆盖自身后读取到新文件偏移。
{ main "$@"; exit "$?"; }
