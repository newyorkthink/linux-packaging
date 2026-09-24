#!/usr/bin/env bash
set -Eeuo pipefail

APPDIR="${1:-}"
[[ -n "$APPDIR" ]] || {
  echo "错误：必须提供 AppDir 路径。" >&2
  exit 1
}
[[ -d "$APPDIR" ]] || {
  echo "错误：AppDir 不存在：$APPDIR" >&2
  exit 1
}
APPDIR="$(cd -- "$APPDIR" && pwd)"

if [[ -f "$APPDIR/AppRun.wrapped" ]]; then
  TARGET="$APPDIR/AppRun.wrapped"
elif [[ -f "$APPDIR/AppRun" ]]; then
  TARGET="$APPDIR/AppRun"
else
  echo "错误：AppDir 中没有 AppRun.wrapped 或 AppRun。" >&2
  exit 1
fi

# 只整理当前 AppRun 已经声明的路径型环境变量，不新增应用未声明的变量。
MANAGED_VARS=(
  PATH
  LD_LIBRARY_PATH
  XDG_DATA_DIRS
  QT_PLUGIN_PATH
  QT_QPA_PLATFORM_PLUGIN_PATH
  QML_IMPORT_PATH
  QML2_IMPORT_PATH
  QT_TRANSLATIONS_PATH
  GI_TYPELIB_PATH
  GTK_PATH
)

# 统计当前 AppRun 中指定变量的 export 行，避免只改到重复定义中的第一处。
export_count() {
  local var="$1"
  grep -Ec "^[[:space:]]*export[[:space:]]+${var}=" "$TARGET" || true
}

# 读取 export 行，并把 "$HERE"/usr 这类分段引号写法统一成便于分析的逻辑路径。
normalized_export_line() {
  local var="$1" line
  line="$(grep -Em1 "^[[:space:]]*export[[:space:]]+${var}=" "$TARGET" || true)"
  line="${line//\"\$HERE\"/\$HERE}"
  line="${line//\"\${HERE}\"/\${HERE}}"
  line="${line//\"\$ROOT\"/\$ROOT}"
  line="${line//\"\${ROOT}\"/\${ROOT}}"
  printf '%s\n' "$line"
}

# 从当前 export 行判断 AppDir 根路径变量名；公共脚本只复用现有 HERE/ROOT，不创造新的根变量。
detect_anchor() {
  local var="$1" line
  line="$(normalized_export_line "$var")"
  if grep -Eq '\$(\{)?HERE(\})?/' <<< "$line"; then
    printf '%s\n' 'HERE'
  elif grep -Eq '\$(\{)?ROOT(\})?/' <<< "$line"; then
    printf '%s\n' 'ROOT'
  else
    echo "错误：${TARGET} 中 ${var} 没有可识别的 \$HERE/ 或 \$ROOT/ AppDir 路径。" >&2
    exit 1
  fi
}

# 确认相对路径真实存在于 AppDir 内部，不接受上跳路径或指向外部的符号链接。
is_appdir_rel_dir() {
  local rel="$1" resolved
  [[ "$rel" != /* ]] || return 1
  case "/$rel/" in
    */../*|*/./*) return 1 ;;
  esac
  [[ -n "$rel" && -d "$APPDIR/$rel" ]] || return 1
  resolved="$(readlink -f -- "$APPDIR/$rel")"
  case "$resolved" in
    "$APPDIR"/*) return 0 ;;
    *) return 1 ;;
  esac
}

# 将 AppDir 中真实存在的安全目录加入结果并去重。
add_rel_dir() {
  local rel="$1"
  is_appdir_rel_dir "$rel" || return 0
  if [[ -z "${SEEN[$rel]:-}" ]]; then
    PATHS+=("\$$ANCHOR/$rel")
    SEEN["$rel"]=1
  fi
}

# 判断目录是否与当前环境变量的用途一致，避免只因目录存在就放进错误搜索路径。
is_semantic_dir() {
  local var="$1" rel="$2" dir="$APPDIR/$2" base child
  is_appdir_rel_dir "$rel" || return 1
  base="${rel##*/}"

  case "$var" in
    PATH)
      case "$rel" in
        usr/bin|usr/sbin|usr/libexec|bin|sbin) return 0 ;;
      esac
      [[ -n "$(find "$dir" -maxdepth 1 -type f -perm -u+x ! -name '*.so' ! -name '*.so.*' -print -quit 2>/dev/null)" ]]
      ;;

    LD_LIBRARY_PATH)
      case "$rel" in
        usr/lib|usr/lib64|lib|lib64|usr/lib/*-linux-gnu|*/lib|*/lib64) return 0 ;;
        */plugins|*/plugins/*|*/Plugins|*/Plugins/*|*/platforms|*/platforms/*|*/qml|*/qml/*|*/translations|*/translations/*|*/share|*/share/*|*/bin|*/sbin) return 1 ;;
      esac
      [[ -n "$(find "$dir" -maxdepth 1 -type f \( -name '*.so' -o -name '*.so.*' \) -print -quit 2>/dev/null)" ]]
      ;;

    XDG_DATA_DIRS)
      [[ "$base" == share ]] && return 0
      for child in applications icons mime glib-2.0; do
        [[ -d "$dir/$child" ]] && return 0
      done
      return 1
      ;;

    QT_PLUGIN_PATH)
      for child in platforms platforminputcontexts imageformats xcbglintegrations platformthemes styles sqldrivers; do
        if [[ -d "$dir/$child" ]] &&
          [[ -n "$(find "$dir/$child" -maxdepth 1 \( -type f -o -type l \) -name '*.so' -print -quit 2>/dev/null)" ]]; then
          return 0
        fi
      done
      return 1
      ;;

    QT_QPA_PLATFORM_PLUGIN_PATH)
      [[ "$base" == platforms ]]
      ;;

    QML_IMPORT_PATH|QML2_IMPORT_PATH)
      [[ "$base" == qml ]]
      ;;

    QT_TRANSLATIONS_PATH)
      [[ "$base" == translations ]]
      ;;

    GI_TYPELIB_PATH)
      [[ "$base" == girepository-1.0 ]]
      ;;

    GTK_PATH)
      [[ "$base" == gtk-* ]]
      ;;

    *)
      return 1
      ;;
  esac
}

# 从当前 export 行中只保留仍真实存在、属于 AppDir 且用途正确的路径。
add_existing_dirs() {
  local var="$1" line token rel
  line="$(normalized_export_line "$var")"
  [[ -n "$line" ]] || return 0

  while IFS= read -r token; do
    [[ -n "$token" ]] || continue
    rel="$(sed -E 's/^\$(\{)?(HERE|ROOT)(\})?\///' <<< "$token")"
    rel="${rel%/}"
    is_semantic_dir "$var" "$rel" || continue
    add_rel_dir "$rel"
  done < <(grep -oE '(\$HERE|\$\{HERE\}|\$ROOT|\$\{ROOT\})/[^:"$}[:space:]]+' <<< "$line" || true)
}

# 根据最终 AppDir 的实际结构补入与变量语义匹配的目录。
add_discovered_dirs() {
  local var="$1" dir rel parent

  case "$var" in
    PATH)
      add_rel_dir "usr/bin"
      add_rel_dir "usr/libexec"
      add_rel_dir "bin"
      if [[ -d "$APPDIR/opt" ]]; then
        while IFS= read -r dir; do
          [[ -n "$(find "$dir" -maxdepth 1 -type f -perm -u+x ! -name '*.so' ! -name '*.so.*' -print -quit 2>/dev/null)" ]] || continue
          rel="${dir#"$APPDIR"/}"
          add_rel_dir "$rel"
        done < <(find "$APPDIR/opt" -mindepth 1 -maxdepth 1 -type d -print 2>/dev/null | sort)
      fi
      ;;

    LD_LIBRARY_PATH)
      add_rel_dir "usr/lib"
      add_rel_dir "usr/lib64"
      add_rel_dir "lib"
      add_rel_dir "lib64"
      if [[ -d "$APPDIR/usr/lib" ]]; then
        while IFS= read -r dir; do
          rel="${dir#"$APPDIR"/}"
          add_rel_dir "$rel"
        done < <(find "$APPDIR/usr/lib" -mindepth 1 -maxdepth 1 -type d -name '*-linux-gnu' -print 2>/dev/null | sort)
      fi
      if [[ -d "$APPDIR/opt" ]]; then
        while IFS= read -r dir; do
          rel="${dir#"$APPDIR"/}"
          add_rel_dir "$rel"
        done < <(find "$APPDIR/opt" -mindepth 2 -maxdepth 2 -type d \( -name lib -o -name lib64 \) -print 2>/dev/null | sort)
      fi
      ;;

    XDG_DATA_DIRS)
      add_rel_dir "usr/share"
      add_rel_dir "share"
      if [[ -d "$APPDIR/opt" ]]; then
        while IFS= read -r dir; do
          rel="${dir#"$APPDIR"/}"
          add_rel_dir "$rel"
        done < <(find "$APPDIR/opt" -mindepth 2 -maxdepth 2 -type d -name share -print 2>/dev/null | sort)
      fi
      ;;

    QT_PLUGIN_PATH)
      while IFS= read -r dir; do
        parent="${dir%/*}"
        rel="${parent#"$APPDIR"/}"
        is_semantic_dir "$var" "$rel" || continue
        add_rel_dir "$rel"
      done < <(
        find "$APPDIR" -mindepth 2 -maxdepth 8 -type d \
          \( -name platforms -o -name platforminputcontexts -o -name imageformats -o -name xcbglintegrations -o -name platformthemes -o -name styles -o -name sqldrivers \) \
          -print 2>/dev/null | sort
      )
      ;;

    QT_QPA_PLATFORM_PLUGIN_PATH)
      while IFS= read -r dir; do
        rel="${dir#"$APPDIR"/}"
        add_rel_dir "$rel"
      done < <(find "$APPDIR" -mindepth 2 -maxdepth 8 -type d -name platforms -print 2>/dev/null | sort)
      ;;

    QML_IMPORT_PATH|QML2_IMPORT_PATH)
      while IFS= read -r dir; do
        rel="${dir#"$APPDIR"/}"
        add_rel_dir "$rel"
      done < <(find "$APPDIR" -mindepth 2 -maxdepth 8 -type d -name qml -print 2>/dev/null | sort)
      ;;

    QT_TRANSLATIONS_PATH)
      add_rel_dir "usr/translations"
      if [[ -d "$APPDIR/opt" ]]; then
        while IFS= read -r dir; do
          rel="${dir#"$APPDIR"/}"
          add_rel_dir "$rel"
        done < <(find "$APPDIR/opt" -mindepth 2 -maxdepth 3 -type d -name translations -print 2>/dev/null | sort)
      fi
      ;;

    GI_TYPELIB_PATH)
      add_rel_dir "usr/lib/girepository-1.0"
      if [[ -d "$APPDIR/usr/lib" ]]; then
        while IFS= read -r dir; do
          rel="${dir#"$APPDIR"/}"
          add_rel_dir "$rel"
        done < <(find "$APPDIR/usr/lib" -mindepth 2 -maxdepth 2 -type d -name girepository-1.0 -print 2>/dev/null | sort)
      fi
      ;;

    GTK_PATH)
      if [[ -d "$APPDIR/usr/lib" ]]; then
        while IFS= read -r dir; do
          rel="${dir#"$APPDIR"/}"
          add_rel_dir "$rel"
        done < <(find "$APPDIR/usr/lib" -mindepth 1 -maxdepth 2 -type d -name 'gtk-*' -print 2>/dev/null | sort)
      fi
      ;;
  esac
}

# 替换对应 export 行；没有任何有效 AppDir 目录时删除该 export，其他启动逻辑保持不变。
replace_export() {
  local var="$1" joined suffix replacement tmp

  if ((${#PATHS[@]} > 0)); then
    printf -v joined '%s:' "${PATHS[@]}"
    joined="${joined%:}"
    suffix="\${${var}:+:\$${var}}"
    replacement="export ${var}=\"${joined}${suffix}\""
  else
    replacement=""
  fi

  tmp="$(mktemp "${TARGET}.tmp.XXXXXX")"
  awk -v var="$var" -v replacement="$replacement" '
    BEGIN { replaced = 0 }
    $0 ~ "^[[:space:]]*export[[:space:]]+" var "=" && replaced == 0 {
      if (replacement != "") print replacement
      replaced = 1
      next
    }
    { print }
    END { if (replaced == 0) exit 42 }
  ' "$TARGET" > "$tmp" || {
    rm -f "$tmp"
    echo "错误：无法更新 ${TARGET} 中的 ${var}。" >&2
    exit 1
  }
  chmod --reference="$TARGET" "$tmp"
  mv -f "$tmp" "$TARGET"
}

for var in "${MANAGED_VARS[@]}"; do
  count="$(export_count "$var")"
  [[ "$count" -eq 0 ]] && continue
  [[ "$count" -eq 1 ]] || {
    echo "错误：${TARGET} 中 ${var} 存在重复 export，拒绝自动修改。" >&2
    exit 1
  }

  ANCHOR="$(detect_anchor "$var")"
  declare -a PATHS=()
  declare -A SEEN=()

  # 先保留当前应用已经声明且真实存在的路径，再补入最终 AppDir 中自动发现的同用途目录。
  # 这样不会打乱应用已有路径优先级，同时能补上第二次 linuxdeploy 后才生成的目录。
  add_existing_dirs "$var"
  add_discovered_dirs "$var"

  replace_export "$var"
  unset PATHS SEEN ANCHOR
done

# 确认只整理 export 后，实际启动入口仍是有效 Shell 语法。
bash -n "$TARGET"
