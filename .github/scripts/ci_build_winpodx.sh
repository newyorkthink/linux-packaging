#!/usr/bin/env bash
set -Eeuo pipefail

sudo apt-get update
sudo apt-get install -y --no-install-recommends \
  ca-certificates \
  curl \
  libegl1 \
  libgl1 \
  libxcb-shape0 \
  libxkbcommon0

cd /tmp
curl -fL --retry 5 \
  https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage \
  -o appimagetool.AppImage
chmod +x appimagetool.AppImage
./appimagetool.AppImage --appimage-extract >/dev/null
sudo rm -rf /opt/appimagetool
sudo mv squashfs-root /opt/appimagetool
sudo tee /usr/local/bin/appimagetool >/dev/null <<'WRAPPER'
#!/bin/sh
exec /opt/appimagetool/AppRun "$@"
WRAPPER
sudo chmod +x /usr/local/bin/appimagetool

cd "$GITHUB_WORKSPACE"
chmod +x winpodx/build_winpodx_release.sh winpodx/fix_winpodx_qt_runtime.sh
./winpodx/build_winpodx_release.sh 2>&1 | tee build_winpodx_release.log

(
  cd winpodx/dist
  sha256sum -c winpodx.AppImage.sha256
)

docker run --rm \
  -v "$GITHUB_WORKSPACE/winpodx/dist:/input:ro" \
  kalilinux/kali-rolling bash -lc '
    set -Eeuo pipefail
    export DEBIAN_FRONTEND=noninteractive
    apt-get update >/dev/null

    if apt-cache show libglib2.0-0t64 >/dev/null 2>&1; then
      glib_package=libglib2.0-0t64
    else
      glib_package=libglib2.0-0
    fi

    # Deliberately do not install FreeRDP or the eight Qt/XCB helper
    # packages: both must come from the patched official AppImage.
    apt-get install -y --no-install-recommends \
      xvfb \
      xauth \
      libegl1 \
      libgl1 \
      "$glib_package" \
      libfontconfig1 \
      libfreetype6 \
      libdbus-1-3 \
      libx11-6 \
      libx11-xcb1 \
      libxcursor1 \
      libxext6 \
      libxfixes3 \
      libxi6 \
      libxinerama1 \
      libxkbfile1 \
      libxrandr2 \
      libxrender1 \
      libxcb1 \
      libxcb-randr0 \
      libxcb-render0 \
      libxcb-shape0 \
      libxcb-shm0 \
      libxcb-sync1 \
      libxcb-xfixes0 \
      libxkbcommon0 >/dev/null

    work_dir=/tmp/winpodx-check
    mkdir -p "$work_dir"
    cp /input/winpodx.AppImage "$work_dir/winpodx.AppImage"
    chmod +x "$work_dir/winpodx.AppImage"
    cd "$work_dir"
    ./winpodx.AppImage --appimage-extract >/dev/null

    APPDIR="$work_dir/squashfs-root"
    QT_ROOT="$(find "$APPDIR/opt/python/lib" \
      -path "*/site-packages/PySide6/Qt" -type d -print -quit)"
    BUNDLE_DIR="$APPDIR/opt/python/share/winpodx"
    [[ -n "$QT_ROOT" ]]

    [[ -x "$APPDIR/usr/bin/xfreerdp" ]]
    [[ -x "$APPDIR/usr/bin/sdl-freerdp" ]]
    [[ -x "$APPDIR/usr/bin/wlfreerdp" ]]
    for library in \
      libfreerdp-client3.so.3 \
      libfreerdp3.so.3 \
      libwinpr3.so.3; do
      [[ -f "$APPDIR/usr/lib/$library" ]]
    done

    private_libraries=(
      libxcb-cursor.so.0
      libxcb-icccm.so.4
      libxcb-image.so.0
      libxcb-keysyms.so.1
      libxcb-render-util.so.0
      libxcb-util.so.1
      libxcb-xkb.so.1
      libxkbcommon-x11.so.0
    )
    for library in "${private_libraries[@]}"; do
      [[ -f "$QT_ROOT/lib/$library" ]]
      [[ ! -e "$APPDIR/usr/lib/$library" ]]
    done

    export APPDIR
    export WINPODX_BUNDLE_DIR="$BUNDLE_DIR"
    export PYTHONPATH="$APPDIR/opt/python/lib/python3.11/site-packages"
    export LD_LIBRARY_PATH="$QT_ROOT/lib:$APPDIR/usr/lib:$APPDIR/opt/python/lib"
    export QT_PLUGIN_PATH="$QT_ROOT/plugins"
    export QT_QPA_PLATFORM_PLUGIN_PATH="$QT_ROOT/plugins/platforms"
    export QT_QPA_PLATFORM=xcb

    qt_dependencies="$(ldd "$QT_ROOT/plugins/platforms/libqxcb.so")"
    printf "%s\n" "$qt_dependencies"
    if grep -F "not found" <<<"$qt_dependencies"; then
      exit 1
    fi
    for library in "${private_libraries[@]}"; do
      printf "%s\n" "$qt_dependencies" | grep -F \
        "$library => $QT_ROOT/lib/$library"
    done

    freerdp_dependencies="$(ldd "$APPDIR/usr/bin/xfreerdp")"
    printf "%s\n" "$freerdp_dependencies"
    if grep -F "not found" <<<"$freerdp_dependencies"; then
      exit 1
    fi
    for library in \
      libfreerdp-client3.so.3 \
      libfreerdp3.so.3 \
      libwinpr3.so.3; do
      printf "%s\n" "$freerdp_dependencies" | grep -F \
        "$library => $APPDIR/usr/lib/$library"
    done

    "$APPDIR/usr/bin/xfreerdp" /buildconfig \
      > /tmp/freerdp-buildconfig.txt 2>&1
    cat /tmp/freerdp-buildconfig.txt
    grep -F "WITH_PULSE=ON" /tmp/freerdp-buildconfig.txt
    grep -F "WITH_ALSA=ON" /tmp/freerdp-buildconfig.txt

    grep -F "source=official-appimage" \
      /input/winpodx-release-version.txt
    grep -F "asset=winpodx-x86_64.AppImage" \
      /input/winpodx-release-version.txt
    grep -F "freerdp=bundled-upstream-official" \
      /input/winpodx-release-version.txt
    grep -F "patches=qt-xcb,audio-pulse-fallback,i3bar-icon" \
      /input/winpodx-release-version.txt
    grep -F "WINPODX_BUNDLE_DIR" "$APPDIR/AppRun"
    grep -F "QT_ROOT/lib" "$APPDIR/AppRun"
    "$APPDIR/AppRun" --version

    [[ -x "$APPDIR/usr/bin/winpodx" ]]
    head -n 1 "$APPDIR/usr/bin/winpodx" | grep -Fx "#!/bin/sh"
    grep -F "exec \"\$APPDIR/opt/python/bin/python3\" -m winpodx \"\$@\"" \
      "$APPDIR/usr/bin/winpodx"
    resolved_wrapper="$(PATH="$APPDIR/usr/bin:$APPDIR/opt/python/bin:$PATH" "$APPDIR/opt/python/bin/python3" -c "import shutil; print(shutil.which(\"winpodx\") or \"\")")"
    [[ "$resolved_wrapper" == "$APPDIR/usr/bin/winpodx" ]]
    "$APPDIR/usr/bin/winpodx" --version

    export XDG_DATA_HOME=/tmp/winpodx-xdg-data
    "$APPDIR/opt/python/bin/python3" -c "from winpodx.desktop.icons import bundled_data_path, install_winpodx_icon; icon = bundled_data_path(\"winpodx-icon.svg\"); assert icon is not None and icon.is_file() and not icon.is_symlink(); assert install_winpodx_icon()"
    [[ -f "$XDG_DATA_HOME/icons/hicolor/scalable/apps/winpodx.svg" ]]
    [[ -f "$APPDIR/usr/share/icons/hicolor/scalable/apps/winpodx.svg" ]]

    grep -F "PULSE_SERVER" \
      "$APPDIR/opt/python/lib/python3.11/site-packages/winpodx/core/rdp.py"
    grep -F "pulse/native" \
      "$APPDIR/opt/python/lib/python3.11/site-packages/winpodx/core/rdp.py"
    "$APPDIR/opt/python/bin/python3" -m py_compile \
      "$APPDIR/opt/python/lib/python3.11/site-packages/winpodx/core/rdp.py"

    output="$(xvfb-run -a "$APPDIR/opt/python/bin/python3" -c "from PySide6.QtWidgets import QApplication; app = QApplication([]); print(app.platformName())")"
    [[ "$output" == "xcb" ]]

    tray_log=/tmp/winpodx.AppImage.tray.log
    set +e
    xvfb-run -a timeout 5s "$APPDIR/usr/bin/winpodx" tray \
      >"$tray_log" 2>&1
    tray_status=$?
    set -e
    if [[ "$tray_status" -ne 124 ]]; then
      cat "$tray_log" >&2
      exit 1
    fi
    if grep -Eq \
      "cannot execute|required file not found|Could not load the Qt platform plugin|ImportError:|IOT instruction" \
      "$tray_log"; then
      cat "$tray_log" >&2
      exit 1
    fi

    log=/tmp/winpodx.AppImage.gui.log
    set +e
    APPIMAGE_EXTRACT_AND_RUN=1 QT_QPA_PLATFORM=xcb \
      xvfb-run -a timeout 15s ./winpodx.AppImage gui \
      >"$log" 2>&1
    status=$?
    set -e

    if [[ "$status" -ne 0 && "$status" -ne 124 ]]; then
      cat "$log" >&2
      exit "$status"
    fi

    if grep -Eq \
      "Segmentation fault|Bus error|Aborted|Bundled icon not found|Could not load the Qt platform plugin|cannot open shared object file|ImportError:|IOT instruction" \
      "$log"; then
      cat "$log" >&2
      exit 1
    fi
  '
