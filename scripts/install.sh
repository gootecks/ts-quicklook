#!/bin/sh
set -eu
cd "$(dirname "$0")/.."

lsregister=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
dest="$HOME/Applications/TSQuickLook.app"
appex="$dest/Contents/PlugIns/TSQuickLookPreview.appex"
id=local.tsquicklook.preview

sh scripts/build.sh

if [ -d "$dest" ]; then
    pluginkit -r "$appex" 2>/dev/null || true
    rm -rf "$dest"
fi
mkdir -p "$HOME/Applications"
cp -R build/TSQuickLook.app "$dest"
"$lsregister" -f -R "$dest"

registered=0
for _ in 1 2 3 4 5 6 7 8 9 10; do
    pluginkit -a "$appex"
    sleep 1
    if pluginkit -m -A -D -i "$id" | grep -q "$id"; then
        registered=1
        break
    fi
done
if [ "$registered" -ne 1 ]; then
    echo "Extension did not register. Reason: log show --last 1m --predicate 'process == \"pkd\"'" >&2
    exit 1
fi

qlmanage -r >/dev/null 2>&1 || true
qlmanage -r cache >/dev/null 2>&1 || true
killall QuickLookUIService 2>/dev/null || true
echo "Installed $dest"
