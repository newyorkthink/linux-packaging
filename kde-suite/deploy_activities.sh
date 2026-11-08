# KDE Suite 的 Plasma Activities 部署函数。
# 由 deploy_suite_apps.sh 在现有应用集成脚本前后分两阶段调用。

if [ "${KDE_SUITE_ACTIVITIES_HELPERS_READY:-0}" = "1" ]; then
    return 0
fi
KDE_SUITE_ACTIVITIES_HELPERS_READY=1

# 第一阶段：收集后台程序、全部活动插件和 Qt SQLite 驱动。
deploy_activities_files() {
    quick-sharun \
      /usr/lib/kactivitymanagerd \
      /usr/lib/libkactivitymanagerd_plugin.so \
      /usr/lib/qt6/plugins/kactivitymanagerd1 \
      /usr/lib/qt6/plugins/sqldrivers/libqsqlite.so
}

# 第二阶段：在 dbus-send、完整翻译和现有 Dolphin 入口均已部署后接入服务。
deploy_activities_integration() {
    local dolphin_real_dir activity_plugin

    # quick-sharun 对 /usr/lib/kactivitymanagerd 的部署位置可能是 AppDir/lib；
    # 为 D-Bus 服务和 Dolphin 包装程序提供稳定的 AppDir/bin 入口。
    if [ -x AppDir/lib/kactivitymanagerd ]; then
        ln -sfn ../lib/kactivitymanagerd AppDir/bin/kactivitymanagerd
    fi
    if [ ! -x AppDir/bin/kactivitymanagerd ]; then
        echo "错误：未找到已部署的 kactivitymanagerd。" >&2
        exit 1
    fi

    # AppImage 内不依赖宿主 systemd 用户单元，移除 SystemdService，
    # 同时保留标准 D-Bus 服务描述和日志分类。
    mkdir -p AppDir/share/dbus-1/services AppDir/share/qlogging-categories6
    cp -a -- /usr/share/dbus-1/services/org.kde.ActivityManager.service AppDir/share/dbus-1/services/
    sed -i \
      -e 's|^Exec=.*$|Exec=kactivitymanagerd|' \
      -e '/^SystemdService=/d' \
      AppDir/share/dbus-1/services/org.kde.ActivityManager.service
    cp -a -- /usr/share/qlogging-categories6/kactivitymanagerd.categories AppDir/share/qlogging-categories6/

    # Dolphin 启动前确保 Activities 服务可用。已有宿主服务时直接复用；
    # 同一挂载内最后一个 Dolphin 退出时，才结束由本次 AppImage 启动的后台。
    dolphin_real_dir="AppDir/libexec/kde-suite"
    if [ -x AppDir/bin/dolphin ] && [ ! -e "$dolphin_real_dir/dolphin" ]; then
        mkdir -p "$dolphin_real_dir"
        mv AppDir/bin/dolphin "$dolphin_real_dir/dolphin"
        cat > AppDir/bin/dolphin <<'EOF_DOLPHIN_WRAPPER'
#!/bin/sh

activity_state_root="${XDG_RUNTIME_DIR:-/tmp}/kde-suite-activities-${APPDIR##*/}"
activity_lock="$activity_state_root/lock"
activity_client="$activity_state_root/client.$$"
activity_registered=0

acquire_activity_lock() {
    mkdir -p "$activity_state_root" || return 1

    attempt=0
    while ! mkdir "$activity_lock" 2>/dev/null; do
        lock_pid=
        if [ -r "$activity_lock/pid" ]; then
            IFS= read -r lock_pid < "$activity_lock/pid" || lock_pid=
        fi
        if [ -n "$lock_pid" ] && ! kill -0 "$lock_pid" 2>/dev/null; then
            rm -rf "$activity_lock" 2>/dev/null || true
            continue
        fi

        attempt=$((attempt + 1))
        if [ "$attempt" -ge 100 ]; then
            return 1
        fi
        sleep 0.05
    done

    printf '%s\n' "$$" > "$activity_lock/pid"
}

release_activity_lock() {
    rm -rf "$activity_lock" 2>/dev/null || true
}

cleanup_stale_activity_clients() {
    for client_file in "$activity_state_root"/client.*; do
        [ -e "$client_file" ] || continue
        client_pid=${client_file##*.}
        if ! kill -0 "$client_pid" 2>/dev/null; then
            rm -f "$client_file" 2>/dev/null || true
        fi
    done
}

activity_service_running() {
    dbus_reply="$(
        "$APPDIR/bin/dbus-send" --session --print-reply=literal --reply-timeout=1000 \
          --dest=org.freedesktop.DBus /org/freedesktop/DBus \
          org.freedesktop.DBus.NameHasOwner string:org.kde.ActivityManager 2>/dev/null
    )" || return 1

    case "$dbus_reply" in
        *true*) return 0 ;;
    esac
    return 1
}

register_activity_client() {
    if ! acquire_activity_lock; then
        return 1
    fi

    cleanup_stale_activity_clients
    : > "$activity_client"
    activity_registered=1

    if ! activity_service_running; then
        "$APPDIR/bin/kactivitymanagerd" >/dev/null 2>&1 &
        activity_pid=$!
        printf '%s\n' "$activity_pid" > "$activity_state_root/daemon.pid"

        attempt=0
        while [ "$attempt" -lt 50 ] && ! activity_service_running; do
            kill -0 "$activity_pid" 2>/dev/null || break
            sleep 0.1
            attempt=$((attempt + 1))
        done
    fi

    release_activity_lock
}

unregister_activity_client() {
    [ "$activity_registered" = "1" ] || return 0

    if ! acquire_activity_lock; then
        return 0
    fi

    rm -f "$activity_client" 2>/dev/null || true
    cleanup_stale_activity_clients

    remaining_client=
    for client_file in "$activity_state_root"/client.*; do
        if [ -e "$client_file" ]; then
            remaining_client=1
            break
        fi
    done

    if [ -z "$remaining_client" ] && [ -r "$activity_state_root/daemon.pid" ]; then
        activity_pid=
        IFS= read -r activity_pid < "$activity_state_root/daemon.pid" || activity_pid=
        if [ -n "$activity_pid" ] && kill -0 "$activity_pid" 2>/dev/null; then
            kill "$activity_pid" 2>/dev/null || true
            wait "$activity_pid" 2>/dev/null || true
        fi
        rm -f "$activity_state_root/daemon.pid" 2>/dev/null || true
    fi

    release_activity_lock
    rmdir "$activity_state_root" 2>/dev/null || true
}

trap unregister_activity_client EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

register_activity_client || true

"$APPDIR/libexec/kde-suite/dolphin" "$@"
status=$?
exit "$status"
EOF_DOLPHIN_WRAPPER
        chmod +x AppDir/bin/dolphin "$dolphin_real_dir/dolphin"
    fi

    # 构建期完整性检查。
    test -x AppDir/bin/kactivitymanagerd
    test -f AppDir/lib/libkactivitymanagerd_plugin.so
    test -f AppDir/lib/qt6/plugins/sqldrivers/libqsqlite.so
    for activity_plugin in \
      org.kde.ActivityManager.ActivityRunner.so \
      org.kde.ActivityManager.ActivityTemplates.so \
      org.kde.ActivityManager.GlobalShortcuts.so \
      org.kde.ActivityManager.LibreOfficeEventSpy.so \
      org.kde.ActivityManager.RecentlyUsedEventSpy.so \
      org.kde.ActivityManager.ResourceScoring.so \
      org.kde.ActivityManager.RunApplication.so
    do
        test -f "AppDir/lib/qt6/plugins/kactivitymanagerd1/$activity_plugin"
    done
    test -f AppDir/share/dbus-1/services/org.kde.ActivityManager.service
    grep -q '^Exec=kactivitymanagerd$' AppDir/share/dbus-1/services/org.kde.ActivityManager.service
    ! grep -q '^SystemdService=' AppDir/share/dbus-1/services/org.kde.ActivityManager.service
    test -f AppDir/share/qlogging-categories6/kactivitymanagerd.categories
    test -f AppDir/share/locale/zh_CN/LC_MESSAGES/kactivities6.mo
    test -x AppDir/bin/dolphin
    test -x AppDir/libexec/kde-suite/dolphin
    grep -q 'org.freedesktop.DBus.NameHasOwner string:org.kde.ActivityManager' AppDir/bin/dolphin
    grep -q '"$APPDIR/bin/kactivitymanagerd"' AppDir/bin/dolphin
    grep -q 'activity_state_root=' AppDir/bin/dolphin
    grep -q 'daemon.pid' AppDir/bin/dolphin
    grep -q 'remaining_client=' AppDir/bin/dolphin
    grep -q '"$APPDIR/libexec/kde-suite/dolphin"' AppDir/bin/dolphin
}
