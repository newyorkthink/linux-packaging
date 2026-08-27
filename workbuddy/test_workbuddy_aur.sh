#!/usr/bin/env bash
set -Eeuo pipefail

# 仅做 AUR 元数据与当前 PKGBUILD 的只读检查，不执行 makepkg/yay，不安装任何 AUR 包。
AUR_PACKAGES=(workbuddy workbuddy-bin)

# 使用独立临时目录，避免污染仓库工作区。
WORK_ROOT="${TMPDIR:-/tmp}/workbuddy-aur-probe-$$"

# 退出时只清理本脚本创建的临时目录。
cleanup() {
  rm -rf "$WORK_ROOT"
}
trap cleanup EXIT

# 创建本次检查使用的临时目录。
mkdir -p "$WORK_ROOT"

MATCHED_53=0
AUDIT_FAILED=0
CLONED=0

check_package() {
  local pkg="$1"
  local repo="$WORK_ROOT/$pkg"
  local pkgbuild="$repo/PKGBUILD"
  local srcinfo="$repo/.SRCINFO"
  local version=""
  local pkgrel=""
  local commit=""
  local suspicious_regex

  echo
  echo "============================================================"
  echo "AUR package: $pkg"
  echo "============================================================"

  # 克隆完整 AUR Git 历史，既读取当前配方，也能查看 2026-06 供应链事件期间的提交记录。
  for attempt in 1 2 3; do
    rm -rf "$repo"
    if git -c http.version=HTTP/1.1 clone "https://aur.archlinux.org/${pkg}.git" "$repo"; then
      break
    fi

    if [[ "$attempt" -eq 3 ]]; then
      echo "ERROR: 无法克隆 AUR ${pkg}。" >&2
      return 1
    fi

    sleep 5
  done

  CLONED=$((CLONED + 1))

  # AUR 仓库必须同时包含 PKGBUILD 与提交后的 .SRCINFO；缺失时不继续猜版本。
  if [[ ! -f "$pkgbuild" || ! -f "$srcinfo" ]]; then
    echo "ERROR: ${pkg} 缺少 PKGBUILD 或 .SRCINFO。" >&2
    AUDIT_FAILED=1
    return 0
  fi

  # 直接读取 .SRCINFO 中的 pkgver，避免 source PKGBUILD 而执行任何顶层 Shell 代码。
  version="$(sed -nE 's/^[[:space:]]*pkgver[[:space:]]*=[[:space:]]*(.+)$/\1/p' "$srcinfo" | head -n 1)"

  # 读取 pkgrel，仅用于完整显示 AUR 当前包版本。
  pkgrel="$(sed -nE 's/^[[:space:]]*pkgrel[[:space:]]*=[[:space:]]*(.+)$/\1/p' "$srcinfo" | head -n 1)"

  # 记录当前 AUR Git 提交，方便后续复核具体配方版本。
  commit="$(git -C "$repo" rev-parse HEAD)"

  echo "AUR version: ${version:-unknown}${pkgrel:+-$pkgrel}"
  echo "AUR commit : $commit"

  # 只要当前配方明确属于 5.3.x，就记为已经跟踪 WorkBuddy 5.3 系列；这不等价于运行验证通过。
  if [[ "$version" == 5.3.* ]]; then
    MATCHED_53=$((MATCHED_53 + 1))
    echo "5.3.x track: YES"
  else
    echo "5.3.x track: NO"
  fi

  echo
  echo "--- 当前 PKGBUILD 的来源与校验字段 ---"

  # 输出来源和校验字段，便于确认实际下载的是官方包、社区补丁还是第三方预构建产物。
  grep -nE '^[[:space:]]*(source|source_[[:alnum:]_]+|sha(1|224|256|384|512)sums|b2sums|md5sums)[[:space:]]*=' "$pkgbuild" || true

  echo
  echo "--- 当前 PKGBUILD 的关键函数 ---"

  # 只列出构建函数入口，不执行 PKGBUILD。
  grep -nE '^[[:space:]]*(prepare|pkgver|build|check|package)\(\)' "$pkgbuild" || true

  echo
  echo "--- 当前 PKGBUILD 静态危险模式检查 ---"

  # WorkBuddy-bin 曾出现在 2026-06 AUR 供应链事件的受影响名单中，因此当前配方先做静态危险模式检查。
  suspicious_regex='(curl|wget)[^|;]*\|[[:space:]]*(ba)?sh|base64[^|;]*-d[^|;]*\|[[:space:]]*(ba)?sh|/dev/tcp/|[[:space:]]nc[[:space:]].*-e[[:space:]]|bash[[:space:]]+-i|systemctl[[:space:]].*enable|/etc/systemd/system/|\.config/systemd/|nohup[[:space:]].*(curl|wget|https?://)'

  # 命中上述模式时直接标记检查失败，不自动执行或安装该包。
  if grep -En "$suspicious_regex" "$pkgbuild"; then
    echo "AUDIT: FAIL - 当前 PKGBUILD 命中高风险模式。" >&2
    AUDIT_FAILED=1
  else
    echo "AUDIT: PASS - 当前 PKGBUILD 未命中本脚本定义的高风险模式。"
  fi

  echo
  echo "--- 最近 8 条 AUR 提交 ---"

  # 显示最近提交，确认包是否仍在维护以及近期版本更新轨迹。
  git -C "$repo" log -8 --date=iso-strict --pretty='format:%h %ad %an %s'

  echo
  echo "--- 2026-06-09 至 2026-06-16 提交记录 ---"

  # 单独显示 AUR 供应链事件窗口内的提交，便于判断该包当时是否发生过异常变更及后续回滚。
  git -C "$repo" log \
    --since='2026-06-09T00:00:00Z' \
    --until='2026-06-16T23:59:59Z' \
    --date=iso-strict \
    --pretty='format:%h %ad %an %s' \
    -- PKGBUILD .SRCINFO || true

  echo
}

# 逐个检查 workbuddy 与 workbuddy-bin，两者互不替代，最终根据当前元数据给出结论。
for pkg in "${AUR_PACKAGES[@]}"; do
  if ! check_package "$pkg"; then
    echo "WARN: ${pkg} 本次未能完成检查。" >&2
  fi
done

# 两个 AUR 仓库都无法读取时，检查结果无效，直接失败。
if [[ "$CLONED" -eq 0 ]]; then
  echo "ERROR: 两个 AUR 仓库均无法读取，本次无法判断版本。" >&2
  exit 2
fi

# 当前两个配方都不是 5.3.x 时，明确返回失败，避免把旧版适配误判成当前版本可用。
if [[ "$MATCHED_53" -eq 0 ]]; then
  echo "ERROR: 当前未发现任何一个 AUR WorkBuddy 配方跟踪 5.3.x。" >&2
  exit 3
fi

# 当前 PKGBUILD 命中高风险静态模式时，不进入后续构建阶段。
if [[ "$AUDIT_FAILED" -ne 0 ]]; then
  echo "ERROR: AUR 当前配方静态安全检查未通过。" >&2
  exit 4
fi

# 本阶段只确认版本跟踪与当前 PKGBUILD 静态安全，不宣称 Linux GUI 已经运行验证通过。
echo "OK: 至少一个 AUR WorkBuddy 配方当前跟踪 5.3.x，且当前 PKGBUILD 未命中本脚本定义的高风险模式。"
echo "NEXT: 若要确认真正适配，需要再做安装包提取、ELF/native module 检查和 Xvfb 启动 smoke test。"
