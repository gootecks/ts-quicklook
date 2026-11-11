#!/bin/sh
set -eu

lsregister=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
dest="$HOME/Applications/TSQuickLook.app"
appex="$dest/Contents/PlugIns/TSQuickLookPreview.appex"

if [ -d "$dest" ]; then
    pluginkit -r "$appex" 2>/dev/null || true
    "$lsregister" -u "$dest" 2>/dev/null || true
    rm -rf "$dest"
fi
qlmanage -r >/dev/null 2>&1 || true
qlmanage -r cache >/dev/null 2>&1 || true
killall QuickLookUIService 2>/dev/null || true
echo "Removed $dest"
