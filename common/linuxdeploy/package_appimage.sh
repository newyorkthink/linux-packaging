#!/usr/bin/env bash
set -Eeuo pipefail

APPIMAGETOOL="$1"
APPDIR="$2"
OUTFILE="$3"
RUNTIME_FILE="$4"

export ARCH=x86_64
export APPIMAGE_EXTRACT_AND_RUN=1
"$APPIMAGETOOL" -n "$APPDIR" "$OUTFILE" --runtime-file "$RUNTIME_FILE"
chmod +x "$OUTFILE"
sha256sum "$OUTFILE"
