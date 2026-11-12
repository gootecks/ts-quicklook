#!/bin/sh
set -eu
cd "$(dirname "$0")/.."

dest="$HOME/Applications/TSQuickLook.app"
appex="$dest/Contents/PlugIns/TSQuickLookPreview.appex"

sh scripts/build.sh

if [ -d "$dest" ]; then
    pluginkit -r "$appex" 2>/dev/null || true
    rm -rf "$dest"
fi
mkdir -p "$HOME/Applications"
cp -R build/TSQuickLook.app "$dest"
"$dest/Contents/MacOS/TSQuickLook" --apply
echo "Installed $dest"
