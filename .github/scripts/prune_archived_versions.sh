#!/usr/bin/env bash
set -Eeuo pipefail

# 始终在已检出的仓库根目录处理清单，仅使用可信 main 的归档映射。
cd "$(git rev-parse --show-toplevel)"
checkout_sha="$(git rev-parse HEAD)"
: "${GH_TOKEN:?缺少 GitHub token}"
: "${GITHUB_REPOSITORY:?缺少仓库名}"
: "${RUNNER_TEMP:?缺少 runner 临时目录}"
SOFTWARE_KEY=archive-cleanup
manifest_upload_started=false

# 每次运行使用独立快照，正式清单仍只保存在 latest Release。
workdir="$(mktemp -d "$RUNNER_TEMP/archived-software-versions.XXXXXXXX")"
manifest_name='software_versions.json'
manifest="$workdir/$manifest_name"
base_manifest="$workdir/base-$manifest_name"
verified_manifest="$workdir/verified-$manifest_name"
assets_json="$workdir/latest-release-assets.json"
report_json="$workdir/archive-cleanup-report.json"
release_json="$workdir/latest-release.json"
lock_name='software_versions.json.lock'
lock_file="$workdir/$lock_name"
lock_upload_error="$workdir/lock-upload-error.txt"

# main 已变化时停止，不能按旧的归档状态修改当前 Release。
require_current_main() {
  local current_sha
  current_sha="$(gh api -H 'Cache-Control: no-cache' \
    "repos/$GITHUB_REPOSITORY/git/ref/heads/main?publication_read=$(date +%s%N)" --jq '.object.sha')"
  [[ "$current_sha" == "$checkout_sha" ]] || {
    echo 'main 在检查期间已变化，停止使用旧归档映射。' >&2
    return 1
  }
}

# 资产必须完整分页读取；API 失败不能当作资产不存在。
refresh_assets() {
  gh api -H 'Cache-Control: no-cache' --paginate --slurp \
    "repos/$GITHUB_REPOSITORY/releases/$release_id/assets?per_page=100&publication_read=$(date +%s%N)" \
    > "$assets_json"
}

# 每次读取独立快照并传递 API 失败，禁止把失败或短暂缺失误认为可以从空清单开始。
read_manifest_row() {
  local rows
  rows="$(gh api -H 'Cache-Control: no-cache' \
    "repos/$GITHUB_REPOSITORY/releases/$release_id/assets?per_page=100&publication_read=$(date +%s%N)" \
    --paginate --jq ".[] | select(.name == \"$manifest_name\") | [.id, (.digest // \"\")] | @tsv")" || return 1
  if [[ -z "$rows" && "${1:-false}" == true ]]; then
    return 0
  fi
  [[ -n "$rows" && "$rows" != *$'\n'* ]] || {
    echo "$manifest_name 不存在或不唯一，禁止覆盖已有清单。" >&2
    return 1
  }
  printf '%s\n' "$rows"
}

# 复核锁资产内容属于本次写入，防止失去锁的旧写入者继续覆盖新清单。
require_own_lock() {
  local row digest created_epoch now_epoch remaining
  row="$(gh api -H 'Cache-Control: no-cache' \
    "repos/$GITHUB_REPOSITORY/releases/assets/$lock_asset_id?publication_read=$(date +%s%N)" \
    --jq '[.digest, .created_at] | @tsv')" || return 1
  digest="${row%%$'\t'*}"
  [[ "$digest" == "sha256:$lock_sha256" ]] || {
    echo '清单写锁已变化，禁止继续写入。' >&2
    return 1
  }
  # 保留原有 300 秒过期锁回收；本次上传必须在该期限前结束，避免旧写入者越过锁期限。
  created_epoch="$(date -u -d "${row#*$'\t'}" +%s)" || return 1
  now_epoch="$(date -u +%s)"
  remaining=$((created_epoch + 290 - now_epoch))
  (( remaining > 0 )) || {
    echo '清单写锁即将到期，停止旧快照写入。' >&2
    return 1
  }
  upload_timeout=$((remaining < 120 ? remaining : 120))
}

# 读取唯一清单的实际内容，核对摘要和快照后再判断是否存在归档残留。
read_snapshot() {
  base_row="$(read_manifest_row)"
  manifest_asset_id="${base_row%%$'\t'*}"
  base_digest="${base_row#*$'\t'}"
  [[ "$base_digest" =~ ^sha256:[0-9a-f]{64}$ ]] || {
    echo '原版本清单缺少有效 SHA-256，禁止清理。' >&2
    return 1
  }
  gh api -H 'Cache-Control: no-cache' -H 'Accept: application/octet-stream' \
    "repos/$GITHUB_REPOSITORY/releases/assets/$manifest_asset_id?publication_read=$(date +%s%N)" \
    > "$base_manifest"
  [[ "sha256:$(sha256sum "$base_manifest" | awk '{print tolower($1)}')" == "$base_digest" ]] || {
    echo '原版本清单内容与资产摘要不一致，禁止清理。' >&2
    return 1
  }
  [[ "$(read_manifest_row)" == "$base_row" ]] || {
    echo '版本清单在读取期间已变化，停止使用旧快照。' >&2
    return 1
  }
  refresh_assets
}

# 按精确归档映射生成候选清单，不修改其他软件记录。
plan_cleanup() {
  python3 .github/scripts/prune_archived_versions.py plan \
    --manifest "$base_manifest" --assets "$assets_json" --output "$manifest" --report "$report_json"
}

# 日志和摘要只报告实际完成的清理，或明确说明本次没有修改。
report_cleanup() {
  python3 .github/scripts/prune_archived_versions.py report "$report_json"
}

# 无残留时直接结束，不创建写锁，也不上传没有变化的清单。
require_current_main
gh api "repos/$GITHUB_REPOSITORY/releases/tags/latest" > "$release_json"
release_id="$(jq -er '.id | numbers' "$release_json")"
read_snapshot
plan_cleanup
if [[ "$(jq '.removed | length' "$report_json")" == 0 ]]; then
  report_cleanup
  exit 0
fi

# 与逐项发布 Action 使用同一把资产锁和相同的所有权、过期时间及快照校验协议。
printf '%s\n' "run=$GITHUB_RUN_ID job=$GITHUB_JOB attempt=$GITHUB_RUN_ATTEMPT" > "$lock_file"
printf '%s\n' "key=$SOFTWARE_KEY nonce=$(date +%s%N)-$$-$RANDOM" >> "$lock_file"
lock_sha256="$(sha256sum "$lock_file" | awk '{print tolower($1)}')"

lock_asset_id=''
lock_owned=false
cleanup_lock() {
  if [[ "$lock_owned" == true && -n "$lock_asset_id" ]]; then
    gh api --method DELETE "repos/$GITHUB_REPOSITORY/releases/assets/$lock_asset_id" >/dev/null 2>&1 || true
  fi
}
trap cleanup_lock EXIT

acquired=false
for attempt in $(seq 1 180); do
  : > "$lock_upload_error"
  if gh release upload latest "$lock_file" --repo "$GITHUB_REPOSITORY" \
    >/dev/null 2>"$lock_upload_error"; then
    lock_asset_id=''
    for visibility_attempt in $(seq 1 15); do
      mapfile -t lock_ids < <(
        gh api "repos/$GITHUB_REPOSITORY/releases/$release_id/assets?per_page=100" --paginate \
          --jq ".[] | select(.name == \"$lock_name\" and .digest == \"sha256:$lock_sha256\") | .id"
      )
      if (( ${#lock_ids[@]} == 1 )); then
        lock_asset_id="${lock_ids[0]}"
        break
      fi
      if (( ${#lock_ids[@]} > 1 )); then
        echo "latest Release 中存在多个 $lock_name，禁止继续写入清单。" >&2
        exit 1
      fi
      sleep 1
    done
    [[ -n "$lock_asset_id" ]] || {
      echo '已取得 software_versions.json 写锁，但无法读取锁资产 ID。' >&2
      exit 1
    }
    lock_owned=true
    acquired=true
    break
  fi

  mapfile -t lock_rows < <(
    gh api "repos/$GITHUB_REPOSITORY/releases/$release_id/assets?per_page=100" --paginate \
      --jq ".[] | select(.name == \"$lock_name\") | [.id,.created_at] | @tsv" \
      || true
  )
  if (( ${#lock_rows[@]} > 1 )); then
    echo "latest Release 中存在多个 $lock_name，禁止继续写入清单。" >&2
    exit 1
  fi
  if (( ${#lock_rows[@]} == 0 )); then
    # 422 already_exists：别人刚抢到锁，列表还没刷新。
    # 404/5xx：全量并发打 uploads.github.com 时的瞬时失败，锁并不存在。
    # 这两种都继续等，不要当成“锁系统坏了”直接退出。
    sleep 2
    continue
  fi
  lock_row="${lock_rows[0]}"
  lock_id="${lock_row%%$'\t'*}"
  created_at="${lock_row#*$'\t'}"
  created_epoch="$(date -u -d "$created_at" +%s 2>/dev/null || echo 0)"
  now_epoch="$(date -u +%s)"
  if (( created_epoch > 0 && now_epoch - created_epoch > 300 )); then
    gh api --method DELETE "repos/$GITHUB_REPOSITORY/releases/assets/$lock_id" >/dev/null 2>&1 || true
  fi
  sleep 2
done
[[ "$acquired" == true ]] || {
  echo '短暂等待 software_versions.json 写锁超时。' >&2
  exit 1
}

# 上传失败且原清单已被替换操作移除时，在仍持有锁的前提下恢复原快照。
finish_cleanup() {
  local status=$? current_row
  trap - EXIT
  if (( status != 0 )) && [[ "$manifest_upload_started" == true && "$lock_owned" == true && -s "$base_manifest" ]]; then
    if require_own_lock && current_row="$(read_manifest_row true)" && [[ -z "$current_row" ]]; then
      if cp "$base_manifest" "$manifest" && require_own_lock && \
        timeout "$upload_timeout" gh release upload latest "$manifest" --repo "$GITHUB_REPOSITORY" && \
        current_row="$(read_manifest_row)" && [[ "${current_row#*$'\t'}" == "$base_digest" ]]; then
        echo '清理失败，已恢复原版本清单；本次仍按失败处理。' >&2
      else
        echo '清理失败且未能确认原清单已恢复，需要检查 Release 版本清单。' >&2
      fi
    fi
  fi
  cleanup_lock
  exit "$status"
}
trap finish_cleanup EXIT

# 取得锁后重新读取最新清单和完整资产列表，保留等待期间其他 Job 写入的记录。
require_own_lock
require_current_main
read_snapshot
plan_cleanup
if [[ "$(jq '.removed | length' "$report_json")" == 0 ]]; then
  report_cleanup
  exit 0
fi
require_current_main

manifest_sha256="$(sha256sum "$manifest" | awk '{print tolower($1)}')"
uploaded=false
for attempt in $(seq 1 8); do
  # 重试时允许本次 clobber 已删除旧清单，但仍拒绝覆盖其他写入者的新清单。
  allow_missing=false
  if (( attempt > 1 )); then
    allow_missing=true
  fi
  current_row="$(read_manifest_row "$allow_missing")"
  if [[ -n "$current_row" && "${current_row#*$'\t'}" == "sha256:$manifest_sha256" ]]; then
    uploaded=true
    break
  fi
  if [[ "$current_row" != "$base_row" && ( -n "$current_row" || "$allow_missing" != true ) ]]; then
    echo '清单写入前远端已变化，停止旧快照上传；交由完整性监督处理。' >&2
    exit 1
  fi
  require_own_lock
  refresh_assets
  plan_cleanup
  manifest_sha256="$(sha256sum "$manifest" | awk '{print tolower($1)}')"
  if [[ "$(jq '.removed | length' "$report_json")" == 0 && "$current_row" == "$base_row" ]]; then
    report_cleanup
    exit 0
  fi
  require_current_main
  require_own_lock
  manifest_upload_started=true
  if timeout "$upload_timeout" gh release upload latest "$manifest" --repo "$GITHUB_REPOSITORY" --clobber; then
    uploaded=true
    break
  fi
  sleep $((attempt * 2))
done
[[ "$uploaded" == true ]] || {
  echo "上传 $manifest_name 失败。" >&2
  exit 1
}

# 重新下载正式清单，核对 digest 和完整内容，确认其他条目没有丢失。
verified=false
for attempt in $(seq 1 12); do
  manifest_row="$(read_manifest_row)"
  mapfile -t manifest_rows <<< "$manifest_row"
  if (( ${#manifest_rows[@]} == 1 )); then
    manifest_asset_id="${manifest_rows[0]%%$'\t'*}"
    manifest_digest="${manifest_rows[0]#*$'\t'}"
    if [[ "$manifest_digest" == "sha256:$manifest_sha256" ]]; then
      rm -f "$verified_manifest"
      if gh api -H 'Cache-Control: no-cache' \
        -H 'Accept: application/octet-stream' \
        "repos/$GITHUB_REPOSITORY/releases/assets/$manifest_asset_id?publication_read=$(date +%s%N)" \
        > "$verified_manifest"; then
        if [[ "$(sha256sum "$verified_manifest" | awk '{print tolower($1)}')" == "$manifest_sha256" ]] && \
          cmp -s "$manifest" "$verified_manifest"
        then
          verified=true
          break
        fi
      fi
    fi
  fi
  sleep 2
done
[[ "$verified" == true ]] || {
  echo "$SOFTWARE_KEY 写入 latest Release/$manifest_name 后校验失败。" >&2
  exit 1
}

# 释放自己的写锁后再报告本次结果。
gh api --method DELETE "repos/$GITHUB_REPOSITORY/releases/assets/$lock_asset_id" >/dev/null
lock_owned=false
trap - EXIT
report_cleanup
