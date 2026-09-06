#!/bin/bash

set -e

APP=chromium
VERSION=${VERSION:-latest}
ARCH=$(uname -m)

mkdir -p AppDir/usr/bin
mkdir -p AppDir/usr/share/applications
mkdir -p AppDir/usr/share/icons/hicolor/256x256/apps

# Download Chromium upstream package
# The exact upstream package source should be adjusted when release format is fixed.

if [ "$ARCH" = "x86_64" ]; then
    URL="https://commondatastorage.googleapis.com/chromium-browser-snapshots/Linux_x64/LAST_CHANGE/chrome-linux.zip"
else
    echo "Unsupported architecture: $ARCH"
    exit 1
fi

wget -O chromium.zip "$URL"
unzip -o chromium.zip

cp -r chrome-linux/* AppDir/usr/bin/

cat > AppDir/usr/share/applications/chromium.desktop <<'EOF'
[Desktop Entry]
Name=Chromium
Comment=Chromium Web Browser
Exec=chromium %U
Terminal=false
Type=Application
Categories=Network;WebBrowser;
StartupWMClass=Chromium
EOF

cat > AppDir/AppRun <<'EOF'
#!/bin/sh

HERE="$(dirname "$(readlink -f "$0")")"

export GTK_IM_MODULE=${GTK_IM_MODULE:-fcitx}
export QT_IM_MODULE=${QT_IM_MODULE:-fcitx}
export XMODIFIERS=${XMODIFIERS:-@im=fcitx}

exec "$HERE/usr/bin/chrome" \
    --enable-features=UseOzonePlatform \
    --ozone-platform=x11 \
    "$@"
EOF

chmod +x AppDir/AppRun

appimagetool AppDir Chromium.AppImage
